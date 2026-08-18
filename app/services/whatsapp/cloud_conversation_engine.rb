module Whatsapp
  class CloudConversationEngine
    class << self
      def call(wa_id, phone_number, customer_name, message_body, selected_button_id = nil)
        new(wa_id, phone_number, customer_name, message_body, selected_button_id).process
      end
    end

    def initialize(wa_id, phone_number, customer_name, message_body, selected_button_id)
      @wa_id = wa_id
      @phone_number = phone_number
      @customer_name = customer_name
      @raw_body = message_body.to_s
      @body = @raw_body.strip.downcase
      @selected_button_id = selected_button_id
    end

    def process
      @conversation = WhatsappConversation.find_or_create_by!(wa_id: @wa_id) do |conv|
        conv.phone_number = @phone_number
        conv.customer_name = @customer_name
        conv.state = "START"
      end

      # Update last message timestamp
      @conversation.update!(last_message_at: Time.current)

      # Handle restart / cancel keywords globally
      if @body == "cancel" || @selected_button_id == "cancel_order"
        handle_cancel
        return
      elsif %w[restart start hi hello].include?(@body)
        handle_restart
        return
      end

      case @conversation.state
      when "START"
        process_start
      when "ASK_PRODUCT"
        process_ask_product
      when "ASK_NAME"
        process_ask_name
      when "ASK_LOCATION"
        process_ask_location
      when "ASK_ADDRESS"
        process_ask_address
      when "ASK_ZIPCODE"
        process_ask_zipcode
      when "CONFIRM_ORDER"
        process_confirm_order
      else
        handle_restart
      end
    rescue => e
      Rails.logger.error("Error in Whatsapp::CloudConversationEngine for wa_id #{@wa_id}: #{e.message}\n#{e.backtrace.join("\n")}")
      send_error_msg
    end

    private

    def process_start
      transition_to("ASK_PRODUCT")
      send_greeting_and_products
    end

    def process_ask_product
      # Determine product from selected button ID or typed text
      product = nil
      btn_id = @selected_button_id.to_s.strip

      if btn_id == "product_jeeni_slim"
        product = Spree::Product.find_by(name: "Jeeni Slim Weight Loss & Energy Booster | ಜೀನಿ ಸ್ಲಿಮ್")
      elsif btn_id == "product_jeeni_sugar_amla"
        product = Spree::Product.find_by(name: "Jeeni Sugaramla 1KG | ಜೀನಿ ಶುಗರ್ ಆಮ್ಲ")
      elsif btn_id == "product_jeeni_millet_mix"
        product = Spree::Product.find_by(name: "JEENI MILLET TRADITIONAL MIX 900gm")
      else
        # Try parsing from text body
        if @body.include?("slim")
          product = Spree::Product.find_by(name: "Jeeni Slim Weight Loss & Energy Booster | ಜೀನಿ ಸ್ಲಿಮ್")
        elsif @body.include?("amla") || @body.include?("sugar")
          product = Spree::Product.find_by(name: "Jeeni Sugaramla 1KG | ಜೀನಿ ಶುಗರ್ ಆಮ್ಲ")
        elsif @body.include?("millet") || @body.include?("mix")
          product = Spree::Product.find_by(name: "JEENI MILLET TRADITIONAL MIX 900gm")
        end
      end

      if product
        @conversation.update!(
          product_id: product.id,
          product_name: product.name,
          quantity: 1
        )
        transition_to("ASK_NAME")
        Whatsapp::CloudApiClient.send_text(@phone_number, "ನಿಮ್ಮ ಹೆಸರು ಏನು?")
      else
        # If input doesn't match any product, present options again
        send_greeting_and_products
      end
    end

    def process_ask_name
      if @raw_body.blank?
        Whatsapp::CloudApiClient.send_text(@phone_number, "ದಯವಿಟ್ಟು ನಿಮ್ಮ ಹೆಸರನ್ನು ತಿಳಿಸಿ.")
        return
      end

      @conversation.update!(customer_name: @raw_body.strip)
      transition_to("ASK_LOCATION")
      Whatsapp::CloudApiClient.send_text(@phone_number, "ನಿಮ್ಮ ಊರು ಅಥವಾ ಹತ್ತಿರದ ಸ್ಥಳದ ಹೆಸರು ತಿಳಿಸಿ.")
    end

    def process_ask_location
      if @raw_body.blank?
        Whatsapp::CloudApiClient.send_text(@phone_number, "ದಯವಿಟ್ಟು ನಿಮ್ಮ ಊರು ಅಥವಾ ಸ್ಥಳದ ಹೆಸರನ್ನು ತಿಳಿಸಿ.")
        return
      end

      @conversation.update_metadata("location", @raw_body.strip)
      # Also store in city field for direct compatibility
      @conversation.update!(city: @raw_body.strip)

      transition_to("ASK_ADDRESS")
      Whatsapp::CloudApiClient.send_text(@phone_number, "ನಿಮ್ಮ ಸಂಪೂರ್ಣ ವಿಳಾಸ ತಿಳಿಸಿ.")
    end

    def process_ask_address
      if @raw_body.blank?
        Whatsapp::CloudApiClient.send_text(@phone_number, "ದಯವಿಟ್ಟು ನಿಮ್ಮ ಸಂಪೂರ್ಣ ವಿಳಾಸವನ್ನು ತಿಳಿಸಿ.")
        return
      end

      @conversation.update!(address: @raw_body.strip)
      transition_to("ASK_ZIPCODE")
      Whatsapp::CloudApiClient.send_text(@phone_number, "ನಿಮ್ಮ Pincode ತಿಳಿಸಿ.")
    end

    def process_ask_zipcode
      pincode = @body.to_s.gsub(/\D/, '')
      if pincode.length == 6
        @conversation.update!(zipcode: pincode)
        transition_to("CONFIRM_ORDER")
        send_order_confirmation
      else
        Whatsapp::CloudApiClient.send_text(@phone_number, "ದಯವಿಟ್ಟು ಸರಿಯಾದ 6 ಅಂಕಿಯ Pincode ತಿಳಿಸಿ.")
      end
    end

    def process_confirm_order
      btn_id = @selected_button_id.to_s.strip
      if btn_id == "confirm_order" || @body == "confirm order" || @body == "confirm"
        transition_to("CREATING_ORDER")
        order = create_spree_order
        if order
          transition_to("COMPLETED")
          @conversation.update!(spree_order_id: order.id)
          
          # Reset/Clear conversation context but keep completed state for records
          @conversation.clear_metadata!

          success_msg = "🎉 ಧನ್ಯವಾದಗಳು 🙏\nನಿಮ್ಮ ಆರ್ಡರ್ ಯಶಸ್ವಿಯಾಗಿ ರಚಿಸಲಾಗಿದೆ.\n\nಆರ್ಡರ್ ಐಡಿ: ##{order.number}\nನಾವು ಶೀಘ್ರದಲ್ಲೇ ನಿಮ್ಮನ್ನು ಸಂಪರ್ಕಿಸುತ್ತೇವೆ."
          Whatsapp::CloudApiClient.send_text(@phone_number, success_msg)
        else
          transition_to("CANCELLED")
          send_order_placement_failed_msg
        end
      elsif btn_id == "cancel_order" || @body == "cancel"
        handle_cancel
      else
        # Prompt them again to select confirm or cancel
        send_order_confirmation
      end
    end

    def handle_cancel
      transition_to("CANCELLED")
      @conversation.clear_metadata!
      @conversation.update!(
        customer_name: nil,
        product_id: nil,
        product_name: nil,
        quantity: 1,
        city: nil,
        address: nil,
        zipcode: nil,
        selected_button: nil,
        spree_order_id: nil
      )
      Whatsapp::CloudApiClient.send_text(@phone_number, "ನಿಮ್ಮ ಆರ್ಡರ್ ಅನ್ನು ರದ್ದುಗೊಳಿಸಲಾಗಿದೆ.")
    end

    def handle_restart
      transition_to("ASK_PRODUCT")
      @conversation.clear_metadata!
      @conversation.update!(
        customer_name: nil,
        product_id: nil,
        product_name: nil,
        quantity: 1,
        city: nil,
        address: nil,
        zipcode: nil,
        selected_button: nil,
        spree_order_id: nil
      )
      send_greeting_and_products
    end

    def transition_to(new_state)
      old_state = @conversation.state
      @conversation.update!(state: new_state)
      Rails.logger.info("WhatsApp Cloud Conversation [wa_id: #{@wa_id}]: transitioned from #{old_state} to #{new_state}")
    end

    def send_greeting_and_products
      greeting = "ನಮಸ್ಕಾರ 🙏\nJEENI ಗೆ ಸ್ವಾಗತ.\nನಿಮಗೆ ಯಾವ ಉತ್ಪನ್ನ ಬೇಕು?"
      buttons = [
        { id: "product_jeeni_slim", title: "JEENI SLIM" },
        { id: "product_jeeni_sugar_amla", title: "JEENI SUGAR AMLA" },
        { id: "product_jeeni_millet_mix", title: "JEENI MILLET MIX" }
      ]
      Whatsapp::CloudApiClient.send_buttons(@phone_number, greeting, buttons)
    end

    def send_order_confirmation
      product_name = @conversation.product_name || "Unknown"
      if product_name.include?("Slim")
        display_product = "JEENI SLIM"
      elsif product_name.include?("Sugaramla")
        display_product = "JEENI SUGAR AMLA"
      else
        display_product = "JEENI MILLET MIX"
      end

      confirm_text = "ನಿಮ್ಮ ಆರ್ಡರ್ ವಿವರಗಳು:\n\n" \
                     "ಉತ್ಪನ್ನ: #{display_product}\n" \
                     "ಹೆಸರು: #{@conversation.customer_name}\n" \
                     "ಸ್ಥಳ: #{@conversation.city}\n" \
                     "ವಿಳಾಸ: #{@conversation.address}\n" \
                     "Pincode: #{@conversation.zipcode}\n\n" \
                     "ಆರ್ಡರ್ confirm ಮಾಡಬೇಕೇ?"

      buttons = [
        { id: "confirm_order", title: "CONFIRM ORDER" },
        { id: "cancel_order", title: "CANCEL" }
      ]
      Whatsapp::CloudApiClient.send_buttons(@phone_number, confirm_text, buttons)
    end

    def send_error_msg
      error_msg = "ಕ್ಷಮಿಸಿ, ಏನೋ ತಪ್ಪಾಗಿದೆ. ಸಂಭಾಷಣೆಯನ್ನು ಮರುಪ್ರಾರಂಭಿಸಲು ದಯವಿಟ್ಟು 'restart' ಎಂದು ಕಳುಹಿಸಿ."
      Whatsapp::CloudApiClient.send_text(@phone_number, error_msg)
    end

    def send_order_placement_failed_msg
      failed_msg = "ಕ್ಷಮಿಸಿ 🙏\nನಿಮ್ಮ ಆರ್ಡರ್ ರಚಿಸುವಾಗ ತೊಂದರೆ ಉಂಟಾಗಿದೆ.\nದಯವಿಟ್ಟು ಸ್ವಲ್ಪ ಸಮಯದ ನಂತರ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ."
      Whatsapp::CloudApiClient.send_text(@phone_number, failed_msg)
    end

    def create_spree_order
      product = Spree::Product.find_by(id: @conversation.product_id)
      variant = product&.master
      return nil if variant.nil?

      # Create order with Spree Checkout defaults
      order = Spree::Order.create!(
        store: Spree::Store.default,
        booking_source: "WhatsApp",
        guest_order: true
      )

      # Store public metadata
      order.public_metadata ||= {}
      order.public_metadata['whatsapp_cloud_booking'] = true

      # Add items to order
      result = Spree::Cart::AddItem.call(order: order, variant: variant, quantity: @conversation.quantity || 1)
      unless result.success?
        Rails.logger.error("WhatsApp Cloud Order Placement - AddItem failed: #{result.error}")
        return nil
      end

      # Set guest email
      clean_phone = @phone_number.to_s.gsub(/\D/, '')
      clean_phone = clean_phone[-10..-1] if clean_phone.length > 10
      order.email = "whatsapp_cloud_#{clean_phone}@jeenimilletmix.in"
      order.save(validate: false)

      # Build shipping address
      name = @conversation.customer_name || ""
      parts = name.strip.split(/\s+/, 2)
      firstname = parts[0]
      lastname = parts[1].presence || parts[0]

      india = Spree::Country.find_by(iso: "IN") || Spree::Country.default
      state_obj = nil
      city = @conversation.city || ""
      if city.present?
        state_obj = Spree::State.where(country: india).where("LOWER(name) = ? OR LOWER(abbr) = ?", city.downcase, city.downcase).first
      end
      state_obj ||= Spree::State.find_by(name: "Karnataka")

      full_address = @conversation.address || ""

      address_params = {
        firstname: firstname,
        lastname: lastname,
        phone: clean_phone.presence || "9999999999",
        address1: full_address,
        city: city.presence || "Bangalore",
        zipcode: @conversation.zipcode,
        state: state_obj,
        country: india
      }

      order.create_bill_address!(address_params)
      order.create_ship_address!(address_params)
      order.update!(use_billing: true)
      order.reload

      # Transition order checkout steps
      begin
        # State: cart -> address
        order.next if order.state == 'cart'

        # State: address -> delivery
        order.next if order.state == 'address'

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
          raise "COD Payment Method not found" if cod_pm.nil?

          order.payments.destroy_all
          order.payments.create!(
            payment_method: cod_pm,
            amount: order.total,
            state: 'checkout'
          )
          order.next
        end

        # State: confirm -> complete
        order.next if order.state == 'confirm'

        if order.completed? || order.state == 'complete'
          # Send confirmation emails
          OrderMailer.confirm_email(order).deliver_later rescue nil
          OrderMailer.admin_alert_email(order).deliver_later rescue nil

          # Track conversion events
          visitor_id = order.public_metadata&.[]('visitor_id') || order.last_ip_address || "whatsapp_cloud_#{clean_phone}"
          FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: order.id) rescue nil
          FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: order.id) rescue nil

          order
        else
          Rails.logger.error("WhatsApp Cloud Order Placement - failed to complete order. State: #{order.state}")
          nil
        end
      rescue => e
        Rails.logger.error("WhatsApp Cloud Order Placement Exception: #{e.message}\n#{e.backtrace.join("\n")}")
        nil
      end
    end
  end
end
