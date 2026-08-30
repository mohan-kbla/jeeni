class CheckoutController < ApplicationController
  before_action :ensure_order
  skip_before_action :ensure_order, only: [:wati_webhook]
  before_action :set_guest_order_attributes, only: [:show, :update]
  skip_before_action :verify_authenticity_token, only: [:razorpay_callback, :wati_webhook]

  def show
    # Track funnel events for checkout states
    visitor_id = cookies[:visitor_id]
    if visitor_id.present? && @order.present?
      case @order.state
      when "address"
        FunnelEvent.track(visitor_id: visitor_id, event_name: 'initiate_checkout', order_id: @order.id, path: request.path)
      when "payment"
        FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_started', order_id: @order.id, path: request.path)
      end
    end

    # Apply promotions to ensure gift state and prices are correct on render
    PromotionService.apply_promotions!(@order) if @order.present?

    # Renders the current state of the checkout
    case @order.state
    when "cart"
      # Transition to address state
      @order.next
      redirect_to checkout_state_path(state: "address")
    when "address"
      # Setup default addresses if blank
      @order.build_bill_address if @order.bill_address.nil?
      @order.build_ship_address if @order.ship_address.nil?

      # Prefill zip/state from session if present
      if session[:visitor_pincode].present?
        @order.bill_address.zipcode ||= session[:visitor_pincode]
        @order.ship_address.zipcode ||= session[:visitor_pincode]
      end
      if session[:visitor_state] == 'Karnataka'
        ka_state = Spree::State.find_by(abbr: 'KA') || Spree::State.where("LOWER(name) = 'karnataka'").first
        if ka_state
          @order.bill_address.state ||= ka_state
          @order.ship_address.state ||= ka_state
        end
      end

      @countries = Spree::Country.order(:name)
      @states = Spree::State.order(:name)
      render "address"
    when "delivery"
      if @order.shipments.empty?
        flash[:alert] = "Unable to calculate shipping rates."
        redirect_to cart_path
      else
        # Auto-select the first shipping rate for all shipments and transition directly
        @order.shipments.each do |shipment|
          if shipment.selected_shipping_rate_id.nil? && shipment.shipping_rates.any?
            shipment.update(selected_shipping_rate_id: shipment.shipping_rates.first.id)
          end
        end
        if @order.next
          redirect_to checkout_state_path(state: @order.state) and return
        else
          render "delivery"
        end
      end
    when "payment"
      @payment_methods = @order.available_payment_methods
      render "payment"
    when "confirm"
      payment = @order.payments.last
      if payment && payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay)
        if payment.state != 'completed'
          flash[:alert] = "Please complete the Razorpay payment to proceed."
          redirect_to checkout_state_path(state: "payment") and return
        end
      end
      render "confirm"
    when "complete"
      redirect_to order_details_path(id: @order.number)
    else
      redirect_to root_path
    end
  end

  def update
    was_address = (@order.state == "address")
    if params[:order] && params[:order][:bill_address_attributes] && params[:order][:bill_address_attributes][:full_name].present?
      full_name = params[:order][:bill_address_attributes].delete(:full_name)
      parts = full_name.strip.split(/\s+/, 2)
      params[:order][:bill_address_attributes][:firstname] = parts[0]
      params[:order][:bill_address_attributes][:lastname] = parts[1].presence || parts[0]
    end

    # Update order parameters and advance state
    if @order.update(order_params)
      @order.reload

      # Apply promotion rules based on selected payment method
      if @order.state == "payment" && params[:order] && params[:order][:payments_attributes]
        begin
          pm_id = params[:order][:payments_attributes].first&.[](:payment_method_id)
          pm = Spree::PaymentMethod.find_by(id: pm_id)
          selected_type = pm&.name.to_s
          PromotionService.apply_promotions!(@order, selected_type)
        rescue => e
          Rails.logger.error("PromotionService error in CheckoutController: #{e.message}")
        end
      end

      # If they are on the payment step and selected Razorpay, create a Razorpay order but don't transition state yet
      if @order.state == "payment"
        payment = @order.payments.last
        if payment && payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay) && payment.state != 'completed'
          payment_method = payment.payment_method
          @key_id = ENV['RAZORPAY_KEY_ID'].presence || payment_method.preferred_key_id
          @key_secret = ENV['RAZORPAY_KEY_SECRET'].presence || payment_method.preferred_key_secret
          
          if @key_id.blank? || @key_secret.blank?
            flash.now[:alert] = "Razorpay API keys are not configured. Please configure them in the Spree Admin panel or env variables."
            @payment_methods = @order.available_payment_methods
            render "payment" and return
          else
            begin
              # If keys are dummy/placeholders, mock order creation for sandboxed testing
              if @key_id.to_s.include?("dummy") || @key_id.to_s.include?("test_key_id")
                @razorpay_order_id = "order_dummy_#{SecureRandom.hex(8)}"
              else
                require 'razorpay'
                Razorpay.setup(@key_id, @key_secret)
                razorpay_order = Razorpay::Order.create(
                  amount: (@order.total * 100).to_i,
                  currency: 'INR',
                  receipt: @order.number
                )
                @razorpay_order_id = razorpay_order.id
              end
              
              # Store the Razorpay order ID in the payment's public metadata
              payment.update!(
                public_metadata: (payment.public_metadata || {}).merge(razorpay_order_id: @razorpay_order_id)
              )
              
              @payment_methods = @order.available_payment_methods
              render "payment" and return
            rescue => e
              flash.now[:alert] = "Error creating Razorpay Order: #{e.message}"
              @payment_methods = @order.available_payment_methods
              render "payment" and return
            end
          end
        end
      end

      # Prevent Razorpay orders from being completed via normal update form if unpaid
      if @order.state == "confirm"
        payment = @order.payments.last
        if payment && payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay) && payment.state != 'completed'
          flash[:alert] = "Please complete the Razorpay payment to place your order."
          redirect_to checkout_state_path(state: "confirm") and return
        end
      end

      # Attempt to transition to the next state
      if @order.next
        @order.reload
        # Track address_submitted if we just transitioned out of address state
        if was_address && @order.state != "address"
          visitor_id = cookies[:visitor_id] || @order.public_metadata&.[]('visitor_id')
          if visitor_id.present?
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'address_submitted', order_id: @order.id, path: request.path)
          end
        end

        # Skip confirmation step for COD / non-Razorpay payments
        if @order.state == "confirm"
          payment = @order.payments.last
          if payment && !payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay)
            @order.next # Transition confirm -> complete
          end
        end

        if @order.state == "complete"
          # Send order confirmation emails and clear session order
          OrderMailer.confirm_email(@order).deliver_later rescue nil
          OrderMailer.admin_alert_email(@order).deliver_later rescue nil
          session[:order_id] = nil
          
          # Track payment_success and order_completed for COD orders in database!
          visitor_id = cookies[:visitor_id] || @order.public_metadata&.[]('visitor_id') || @order.last_ip_address
          if visitor_id.present?
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: @order.id, path: request.path)
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: @order.id, path: request.path)
          end
          
          flash[:notice] = "Order placed successfully!"
          redirect_to order_details_path(id: @order.number)
        else
          redirect_to checkout_state_path(state: @order.state)
        end
      else
        log_msg = "Could not transition order state from #{@order.state}: #{@order.errors.full_messages.join(', ')}"
        Rails.logger.error(log_msg)
        flash[:alert] = log_msg
        redirect_to checkout_state_path(state: @order.state)
      end
    else
      flash[:alert] = "Error updating order: #{@order.errors.full_messages.join(', ')}"
      redirect_to checkout_state_path(state: @order.state)
    end
  end

  def razorpay_callback
    payment = @order.payments.last
    if payment && payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay)
      payment_method = payment.payment_method
      
      key_id = ENV['RAZORPAY_KEY_ID'].presence || payment_method.preferred_key_id
      key_secret = ENV['RAZORPAY_KEY_SECRET'].presence || payment_method.preferred_key_secret
      
      begin
        # If the order ID is mock/dummy, bypass verification and succeed immediately!
        unless params[:razorpay_order_id].to_s.start_with?("order_dummy_")
          require 'razorpay'
          payment_details = {
            razorpay_order_id: params[:razorpay_order_id],
            razorpay_payment_id: params[:razorpay_payment_id],
            razorpay_signature: params[:razorpay_signature]
          }
          Razorpay.setup(key_id, key_secret)
          Razorpay::Utility.verify_payment_signature(payment_details)
        end
        
        # Lock the order to prevent race conditions with webhook transitions
        @order.with_lock do
          # Idempotency check: if order is already completed
          if @order.state == 'complete' || @order.completed?
            session[:order_id] = nil
            session[:meta_pixel_purchase_order_id] = @order.id
            
            # Track payment_success and order_completed in database!
            visitor_id = cookies[:visitor_id] || @order.public_metadata&.[]('visitor_id') || @order.last_ip_address
            if visitor_id.present?
              FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: @order.id, path: request.path)
              FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: @order.id, path: request.path)
            end
            
            return render json: { success: true, redirect_url: order_details_path(id: @order.number) }
          end

          # Mark payment as completed and record details
          payment.update!(
            response_code: params[:razorpay_payment_id] || "pay_dummy_#{SecureRandom.hex(8)}",
            amount: @order.total,
            state: 'completed'
          )
          
          # Advance order to complete
          while @order.state != 'complete' && @order.next
            # Transition through confirm -> complete
          end

          if @order.state == 'complete' || @order.completed?
            # Clear cart / session
            OrderMailer.confirm_email(@order).deliver_later rescue nil
            OrderMailer.admin_alert_email(@order).deliver_later rescue nil
            session[:order_id] = nil
            session[:meta_pixel_purchase_order_id] = @order.id
            
            # Track payment_success and order_completed in database!
            visitor_id = cookies[:visitor_id] || @order.public_metadata&.[]('visitor_id') || @order.last_ip_address
            if visitor_id.present?
              FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: @order.id, path: request.path)
              FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: @order.id, path: request.path)
            end
            
            render json: { success: true, redirect_url: order_details_path(id: @order.number) }
          else
            render json: { success: false, error: "Failed to transition order state: #{@order.errors.full_messages.join(', ')}" }
          end
        end
      rescue => e
        render json: { success: false, error: "Payment verification failed: #{e.message}" }
      end
    else
      render json: { success: false, error: "Invalid payment method" }
    end
  end

  def wati_webhook
    begin
      # 1. Check if we are loading an existing order via order_number (GET request from user clicking the link)
      if params[:order_number].present?
        order = Spree::Order.find_by(number: params[:order_number])
        if order
          session[:order_id] = order.id
          redirect_url = order.state == 'payment' ? checkout_state_path(state: 'payment') : checkout_path
          return redirect_to redirect_url
        end
      end

      # 2. Extract parameters for pre-filling address and choosing product variant
      full_name = params[:full_name].presence || params[:name].presence || params[:senderName].presence || ""
      phone_raw = params[:phone].presence || params[:waId].presence || params[:WaId].presence || params[:wa_id].presence || ""
      
      # Fallback: Extract a 10-digit number from address/text/city if phone_raw is empty or looks like a placeholder (e.g. starts with @)
      if phone_raw.blank? || phone_raw.to_s.start_with?("@") || phone_raw.to_s.gsub(/\D/, '').length < 10
        combined_text = "#{params[:address]} #{params[:address1]} #{params[:text]} #{params[:city]}"
        found_phone = combined_text.scan(/\b\d{10}\b/).first || combined_text.match(/\d{10}/)&.to_s
        if found_phone.present?
          phone_raw = found_phone
          Rails.logger.info("Extracted phone number from fields: #{phone_raw}")
        end
      end

      phone_clean = phone_raw.to_s.gsub(/\D/, '')
      if phone_clean.length > 10
        phone_clean = phone_clean[-10..-1]
      end
      phone = phone_clean.presence || "9999999999"
      address1 = params[:address1].presence || params[:address].presence || params[:street].presence || ""
      city = params[:city].presence || ""
      zipcode_raw = params[:zipcode].presence || params[:zip].presence || ""
      zipcode_clean = zipcode_raw.to_s.strip.gsub(/\D/, '')
      zipcode = zipcode_clean.match?(/\A\d{6}\z/) ? zipcode_clean : ""
      state = params[:state].presence || ""
      quantity = params[:quantity].to_i
      quantity = 1 if quantity <= 0

      # Extract explicit selection text from button reply parameter if present
      explicit_selection = params[:product].presence || 
                           params.dig(:interactiveButtonReply, :title).presence || 
                           params.dig(:buttonReply, :title).presence

      # Extract selection text from any possible parameter representing product selection
      selection_text = explicit_selection || params[:text].presence || ""

      # Try parsing a valid WATI product
      parsed_product = find_product_from_wati(selection_text)
      if parsed_product && phone_clean.present?
        Rails.cache.write("wati_selected_product_#{phone_clean}", parsed_product.id, expires_in: 2.hours)
        Rails.logger.info("Saved Wati product selection for phone #{phone_clean}: #{parsed_product.name}")
      elsif explicit_selection.present? && parsed_product.nil?
        error_msg = "Unknown WATI product selection: \"#{explicit_selection}\""
        Rails.logger.error(error_msg)
        if request.post?
          return render json: { 
            success: false, 
            error: error_msg,
            selected_product: explicit_selection
          }
        end
      end

      # Extract product parameter and log it
      product_param = params[:product].presence || ""
      Rails.logger.info("Wati Webhook received product parameter: '#{product_param}'")

      # If no product is received, log the full request body for debugging
      if product_param.blank?
        begin
          raw_body = request.body.read
          request.body.rewind
          Rails.logger.info("Wati Webhook empty product parameter. Raw request body: #{raw_body}")
        rescue => e
          Rails.logger.error("Wati Webhook body log error: #{e.message}")
        end
      end

      # If this is a POST webhook from Wati, and it doesn't have the required checkout params (name/phone/address),
      # we can cache the product selection (if present) and return success immediately without creating a cart order.
      if request.post? && (full_name.blank? || phone_raw.blank? || address1.blank?)
        return render json: { 
          success: true, 
          message: "Ignored/Cached info (Full checkout requires Name, Phone, and Address)",
          selected_product: parsed_product&.name || "none"
        }
      end

      # Determine variant to purchase based on Wati @product variable or cache lookup
      variant = nil
      product_obj = parsed_product
      
      # If no product is parsed from the current request, lookup the cached selection for this phone number
      if product_obj.nil? && phone_clean.present?
        cached_product_id = Rails.cache.read("wati_selected_product_#{phone_clean}")
        if cached_product_id
          product_obj = Spree::Product.find_by(id: cached_product_id)
          Rails.logger.info("Retrieved Wati product selection from cache for phone #{phone_clean}: #{product_obj&.name}")
        end
      end

      if product_obj
        variant = product_obj.master
      else
        # Fallback to other parameters if product_param is blank
        if params[:variant_id].present?
          variant = Spree::Variant.find_by(id: params[:variant_id])
        elsif params[:sku].present?
          variant = Spree::Variant.find_by(sku: params[:sku])
        elsif params[:product_id].present?
          variant = Spree::Product.find_by(id: params[:product_id])&.master
        elsif params[:slug].present?
          variant = Spree::Product.find_by(slug: params[:slug])&.master
        end

        # Fallback to flagship product (JEENI MILLET TRADITIONAL MIX 900gm, sku: JMT) if not found/provided
        if variant.nil?
          variant = Spree::Variant.find_by(sku: "JMT") || Spree::Variant.find_by(id: 28) || Spree::Variant.first
        end
      end

      if variant.nil?
        if request.post?
          return render json: { 
            success: false, 
            error: "No product variant available.",
            selected_product: product_param.presence || "none"
          }
        else
          flash[:alert] = "Product variant not found."
          return redirect_to root_path
        end
      end

      # Create / get current order
      order = current_order(create_order_if_necessary: true)
      
      # Associate order to user session
      session[:order_id] = order.id

      # Mark order as WATI webhook booking
      order.booking_source = "WhatsApp"
      order.public_metadata ||= {}
      order.public_metadata['wati_webhook_booking'] = true
      order.save(validate: false) if order.changed?

      # Empty existing cart first so they only purchase this product
      order.line_items.destroy_all
      order.reload

      # Add the selected item
      result = Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)
      unless result.success?
        error_msg = result.error.respond_to?(:errors) ? result.error.errors.full_messages.join(', ') : result.error.to_s
        if request.post?
          return render json: { success: false, error: "Failed to add item to cart: #{error_msg}" }
        else
          flash[:alert] = "Failed to add item: #{error_msg}"
          return redirect_to cart_path
        end
      end

      order.reload
      if spree_current_user
        order.guest_order = false if order.guest_order
        order.email = spree_current_user.email if order.email.blank? || order.email.start_with?("guest_")
      else
        order.guest_order = true
        order.email = "guest_#{order.number}@jeenimilletmix.in" if order.email.blank?
      end
      order.save(validate: false) if order.changed?

      # Apply promotions
      PromotionService.apply_promotions!(order)

      # Process address and auto-complete checkout ONLY if we have booking details
      if full_name.present? && phone_raw.present? && address1.present?
        parts = full_name.strip.split(/\s+/, 2)
        firstname = parts[0]
        lastname = parts[1].presence || parts[0]

        india = Spree::Country.find_by(iso: "IN") || Spree::Country.default

        state_obj = PricingService.detect_state(pincode: zipcode, state_name: state, city_name: city)
        state_obj ||= Spree::State.find_by(name: "Karnataka")

        address_params = {
          firstname: firstname,
          lastname: lastname,
          phone: phone,
          address1: address1,
          city: city.presence || "Bangalore",
          zipcode: zipcode,
          state: state_obj,
          country: india
        }

        if order.bill_address
          order.bill_address.update!(address_params)
        else
          order.create_bill_address!(address_params)
        end

        if order.ship_address
          order.ship_address.update!(address_params)
        else
          order.create_ship_address!(address_params)
        end

        order.update!(use_billing: true)
        order.reload

        # Advance checkout states and place the order with Cash on Delivery (COD)
        begin
          # State: cart -> address
          if order.state == 'cart'
            order.next
          end

          # State: address -> delivery
          if order.state == 'address'
            order.next
          end

          # State: delivery -> payment
          if order.state == 'delivery'
            order.shipments.each do |shipment|
              if shipment.selected_shipping_rate_id.nil? && shipment.shipping_rates.any?
                shipment.update(selected_shipping_rate_id: shipment.shipping_rates.first.id)
              end
            end
            order.next
          end

          # State: payment -> confirm
          if order.state == 'payment'
            cod_pm = Spree::PaymentMethod::Check.active.first || Spree::PaymentMethod::Check.first
            if cod_pm.nil?
              raise "Cash on Delivery payment method not configured."
            end

            # Create Spree payment
            order.payments.destroy_all # Clear any old payments
            payment = order.payments.create!(
              payment_method: cod_pm,
              amount: order.total,
              state: 'checkout'
            )
            order.next
          end

          # State: confirm -> complete
          if order.state == 'confirm'
            order.next
          end

          if order.state == 'complete' || order.completed?
            # Send confirmation emails
            OrderMailer.confirm_email(order).deliver_later rescue nil
            OrderMailer.admin_alert_email(order).deliver_later rescue nil

            # Track conversion events
            visitor_id = cookies[:visitor_id] || order.public_metadata&.[]('visitor_id') || order.last_ip_address
            if visitor_id.present?
              FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: order.id)
              FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: order.id)
            end
          end
        rescue => e
          Rails.logger.error("Wati Webhook state transition error: #{e.message}")
        end

        order.reload
      end

      # Build redirect/target URL
      target_url = if order.completed? || order.state == 'complete'
        order_details_path(id: order.number)
      elsif order.state == 'payment'
        checkout_state_path(state: 'payment')
      else
        checkout_path
      end

      if request.post?
        claim_url = api_wati_webhook_url(order_number: order.number)
        render json: { 
          success: true, 
          redirect_url: claim_url, 
          order_number: order.number,
          selected_product: product_param.presence || "none",
          product_name: variant&.name || "None"
        }
      else
        redirect_to target_url
      end
    rescue => e
      Rails.logger.error("Wati Webhook general execution error: #{e.message}\n#{e.backtrace.join("\n")}")
      if request.post?
        render json: { 
          success: false, 
          error: e.message,
          selected_product: product_param.presence || "none"
        }
      else
        flash[:alert] = "Something went wrong processing your request: #{e.message}"
        redirect_to root_path
      end
    end
  end

  private

  def ensure_order
    if action_name == 'razorpay_callback'
      # Try to find the order via the Razorpay order ID or session or last order
      @order = current_order
      if @order.nil? && params[:razorpay_order_id].present?
        # Find the payment with this razorpay_order_id
        payment = Spree::Payment.where.not(public_metadata: nil).detect do |p|
          p.public_metadata['razorpay_order_id'] == params[:razorpay_order_id]
        end
        @order = payment&.order
      end
    else
      @order = current_order
    end

    if @order.nil? || (@order.line_items.empty? && !@order.completed?)
      flash[:alert] = "Your cart is empty."
      redirect_to cart_path
    end
  end

  def order_params
    # Permitted params depend on the checkout state
    case @order.state
    when "address"
      params.require(:order).permit(
        :use_billing,
        bill_address_attributes: [:id, :firstname, :lastname, :address1, :address2, :city, :zipcode, :phone, :country_id, :state_id],
        ship_address_attributes: [:id, :firstname, :lastname, :address1, :address2, :city, :zipcode, :phone, :country_id, :state_id]
      )
    when "delivery"
      params.require(:order).permit(
        shipments_attributes: [:id, :selected_shipping_rate_id]
      )
    when "payment"
      params.require(:order).permit(
        payments_attributes: [:payment_method_id]
      )
    else
      {}
    end
  end



  def set_guest_order_attributes
    if @order
      if spree_current_user
        @order.guest_order = false if @order.guest_order
        @order.email = spree_current_user.email if @order.email.blank? || @order.email.start_with?("guest_")
      else
        @order.guest_order = true
        @order.email = "guest_#{@order.number}@jeenimilletmix.in" if @order.email.blank?
      end
      @order.save(validate: false) if @order.changed?
    end
  end

  private

  # Normalizes WATI product button selection text and finds the corresponding Spree product.
  # Ignores case, leading/trailing whitespace, and emojis/special characters.
  def find_product_from_wati(selection)
    value = selection.to_s.downcase.strip
    
    if value.include?("slim")
      Spree::Product.find_by(name: "Jeeni Slim Weight Loss & Energy Booster | ಜೀನಿ ಸ್ಲಿಮ್")
    elsif value.include?("amla") || value.include?("sugar")
      Spree::Product.find_by(name: "Jeeni Sugaramla 1KG | ಜೀನಿ ಶುಗರ್ ಆಮ್ಲ")
    elsif value.include?("traditional") || value.include?("millet") || value.include?("jmt")
      Spree::Product.find_by(name: "JEENI MILLET TRADITIONAL MIX 900gm")
    else
      nil
    end
  end
end
