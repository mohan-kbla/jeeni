module Whatsapp
  class ProcessorService
    class << self
      def call(from_number, text_body)
        new(from_number, text_body).process
      end
    end

    def initialize(from_number, text_body)
      @from_number = from_number
      @raw_body = text_body.to_s
      @body = @raw_body.strip.downcase
    end

    def process
      @chat = WhatsappChat.find_or_create_by!(phone_number: @from_number)

      response_message = case @chat.state
                         when "selecting_product"
                           process_selecting_product
                         when "entering_quantity"
                           process_entering_quantity
                         when "entering_name"
                           process_entering_name
                         when "entering_city"
                           process_entering_city
                         when "entering_place"
                           process_entering_place
                         when "entering_pincode"
                           process_entering_pincode
                         when "confirming"
                           process_confirming
                         when "entering_detailed_address"
                           process_entering_detailed_address
                         when "confirming_detailed"
                           process_confirming_detailed
                         else # "idle" or fallback
                           process_idle
                         end

      # Send the reply back to the user
      Whatsapp::Client.send_message(@from_number, response_message)
      response_message
    rescue => e
      Rails.logger.error("Error in Whatsapp::ProcessorService: #{e.message}\n#{e.backtrace.join("\n")}")
      error_msg = "Sorry, something went wrong. Type 'help' to restart the conversation."
      Whatsapp::Client.send_message(@from_number, error_msg)
      error_msg
    end

    private

    def process_idle
      case @body
      when "help", "hello", "hi", "start"
        welcome_message
      when "list", "products"
        list_products
      when "cart"
        show_cart
      when "checkout"
        start_checkout
      when "cancel"
        cancel_cart
      else
        "I didn't quite catch that. Type:\n- *list* to see products\n- *cart* to see your cart\n- *checkout* to place order\n- *cancel* to start over"
      end
    end

    def welcome_message
      "Welcome to our WhatsApp Store! 🏪\n\n"\
      "Here is how you can shop with us:\n"\
      "• Type *list* to view available products\n"\
      "• Type *cart* to view your current shopping cart\n"\
      "• Type *checkout* to place your order\n"\
      "• Type *cancel* to clear everything and start over"
    end

    def list_products
      products = Spree::Product.all.limit(10)
      if products.empty?
        return "No products available at the moment."
      end

      response = "Available Products:\n\n"
      products.each do |product|
        response += "*[ID: #{product.id}]* #{product.name} - #{product.display_price || ("$%.2f" % product.price)}\n"
        response += "#{product.description.to_s.truncate(80)}\n\n"
      end
      response += "Reply with the *ID* of the product you want to add to your cart, or type *cancel*."

      @chat.update!(state: "selecting_product")
      response
    end

    def process_selecting_product
      if @body == "cancel"
        @chat.update!(state: "idle")
        return "Selection cancelled. Type *list* to view products or *cart* to view your cart."
      end

      product_id = @body.to_i
      product = Spree::Product.find_by(id: product_id)

      if product
        @chat.update_metadata("selected_product_id", product.id)
        @chat.update!(state: "entering_quantity")
        "You selected *#{product.name}*. How many would you like to add? (Enter a number)"
      else
        "Invalid Product ID. Please reply with a valid product ID from the list, or type *cancel*."
      end
    end

    def process_entering_quantity
      if @body == "cancel"
        @chat.update_metadata("selected_product_id", nil)
        @chat.update!(state: "idle")
        return "Cancelled. Type *list* to view products."
      end

      quantity = @body.to_i
      if quantity <= 0
        return "Please enter a valid positive number for quantity, or type *cancel*."
      end

      product_id = @chat.get_metadata("selected_product_id")
      product = Spree::Product.find_by(id: product_id)

      unless product
        @chat.update!(state: "idle")
        return "Something went wrong. The selected product is no longer available. Please type *list* to start over."
      end

      # Find or create Spree Order (Cart)
      order = @chat.cart_id.present? ? Spree::Order.find_by(id: @chat.cart_id) : nil
      if order.nil? || order.completed?
        order = Spree::Order.create!(store: Spree::Store.default)
        @chat.update!(cart_id: order.id)
      end

      variant = product.master
      result = Spree::Cart::AddItem.call(order: order, variant: variant, quantity: quantity)

      if result.success?
        @chat.update_metadata("selected_product_id", nil)
        @chat.update!(state: "idle")

        "Added #{quantity} x *#{product.name}* to your cart! 🛒\n\n"\
        "Type *list* to add more items, *cart* to see your cart, or *checkout* to place your order."
      else
        error_msg = result.error.respond_to?(:errors) ? result.error.errors.full_messages.join(', ') : result.error.to_s
        "Failed to add item: #{error_msg}. Type *list* to start over."
      end
    end

    def show_cart
      order = @chat.cart_id.present? ? Spree::Order.find_by(id: @chat.cart_id) : nil
      if order.nil? || order.line_items.empty?
        return "Your cart is empty. Type *list* to browse products."
      end

      response = "Your Cart: 🛒\n\n"
      order.line_items.includes(variant: :product).each do |item|
        response += "• #{item.quantity} x #{item.variant.product.name} (#{item.single_money.to_s} each) - #{item.display_amount.to_s}\n"
      end
      response += "\n*Total: #{order.display_total.to_s}*\n\n"\
                  "Type *checkout* to place your order, or *cancel* to clear your cart."
      response
    end

    def start_checkout
      order = @chat.cart_id.present? ? Spree::Order.find_by(id: @chat.cart_id) : nil
      if order.nil? || order.line_items.empty?
        return "Your cart is empty! Add products first by typing *list*."
      end

      @chat.update!(state: "entering_name")
      "Let's get your details to complete the order. 📝\n\nWhat is your full name?"
    end

    def process_entering_name
      if @body == "cancel"
        @chat.update!(state: "idle")
        return "Checkout cancelled. Type *cart* to view your cart."
      end

      @chat.update_metadata("name", @raw_body.strip)
      @chat.update!(state: "entering_city")
      "Got it, #{@raw_body.strip}!\n\nWhich city are you in?"
    end

    def process_entering_city
      if @body == "cancel"
        @chat.update!(state: "idle")
        return "Checkout cancelled. Type *cart* to view your cart."
      end

      @chat.update_metadata("city", @raw_body.strip)
      @chat.update!(state: "entering_place")
      "What is your local area/place?"
    end

    def process_entering_place
      if @body == "cancel"
        @chat.update!(state: "idle")
        return "Checkout cancelled. Type *cart* to view your cart."
      end

      @chat.update_metadata("place", @raw_body.strip)
      @chat.update!(state: "entering_pincode")
      "What is your pincode? (Reply *skip* if you don't have one)"
    end

    def process_entering_pincode
      if @body == "cancel"
        @chat.update!(state: "idle")
        return "Checkout cancelled. Type *cart* to view your cart."
      end

      pincode = @body == "skip" ? "" : @raw_body.strip
      @chat.update_metadata("pincode", pincode)
      @chat.update!(state: "confirming")

      Whatsapp::OrderAutoPlacementJob.set(wait: 15.minutes).perform_later(@chat.id, @chat.cart_id)

      generate_confirmation_message
    end

    def generate_confirmation_message
      order = Spree::Order.find_by(id: @chat.cart_id)
      name = @chat.get_metadata("name")
      city = @chat.get_metadata("city")
      place = @chat.get_metadata("place")
      pincode = @chat.get_metadata("pincode")

      address_parts = [place, city, pincode].reject(&:blank?)
      full_address = address_parts.join(", ")

      response = "Order Summary: 🧾\n"
      response += "-----------------------\n"
      order.line_items.includes(variant: :product).each do |item|
        response += "#{item.quantity} x #{item.variant.product.name} - #{item.display_amount.to_s}\n"
      end
      response += "-----------------------\n"
      response += "Total: #{order.display_total.to_s}\n\n"
      response += "Name: #{name}\n"
      response += "Phone: #{@chat.phone_number}\n"
      response += "Address: #{full_address}\n\n"
      response += "• Type *confirm* to place this order.\n"
      response += "• Type *address* if you want to add a detailed street address/landmark.\n"
      response += "• Type *cancel* to abort."
      response
    end

    def process_confirming
      if @body == "confirm"
        create_order_from_chat(detailed: false)
      elsif @body == "address"
        @chat.update!(state: "entering_detailed_address")
        "Please enter your detailed shipping address (street, building, landmark):"
      elsif @body == "cancel"
        @chat.update!(state: "idle")
        "Checkout cancelled. Your cart is preserved. Type *cart* to view it or *checkout* to try again."
      else
        "Please reply with *confirm*, *address*, or *cancel*."
      end
    end

    def process_entering_detailed_address
      if @body == "cancel"
        @chat.update!(state: "idle")
        return "Checkout cancelled. Type *cart* to view your cart."
      end

      @chat.update_metadata("detailed_address", @raw_body.strip)
      @chat.update!(state: "confirming_detailed")

      Whatsapp::OrderAutoPlacementJob.set(wait: 15.minutes).perform_later(@chat.id, @chat.cart_id)

      order = Spree::Order.find_by(id: @chat.cart_id)
      name = @chat.get_metadata("name")
      city = @chat.get_metadata("city")
      place = @chat.get_metadata("place")
      pincode = @chat.get_metadata("pincode")

      address_parts = [@raw_body.strip, place, city, pincode].reject(&:blank?)
      full_address = address_parts.join(", ")

      response = "Updated Order Summary: 🧾\n"
      response += "-----------------------\n"
      order.line_items.includes(variant: :product).each do |item|
        response += "#{item.quantity} x #{item.variant.product.name} - #{item.display_amount.to_s}\n"
      end
      response += "-----------------------\n"
      response += "Total: #{order.display_total.to_s}\n\n"
      response += "Name: #{name}\n"
      response += "Detailed Address: #{full_address}\n\n"
      response += "Please type *confirm* to place this order, or type *cancel*."
      response
    end

    def process_confirming_detailed
      if @body == "confirm"
        create_order_from_chat(detailed: true)
      elsif @body == "cancel"
        @chat.update!(state: "idle")
        "Checkout cancelled. Your cart is preserved. Type *cart* to view it or *checkout* to try again."
      else
        "Please type *confirm* to place the order, or *cancel* to abort."
      end
    end

    def create_order_from_chat(detailed:)
      order = Spree::Order.find_by(id: @chat.cart_id)
      return "Something went wrong. Order not found." if order.nil? || order.completed?

      name = @chat.get_metadata("name")
      city = @chat.get_metadata("city")
      place = @chat.get_metadata("place")
      pincode = @chat.get_metadata("pincode")
      detailed_address = @chat.get_metadata("detailed_address")

      address_parts = [place, city, pincode].reject(&:blank?)
      address_parts.unshift(detailed_address) if detailed && detailed_address.present?
      full_address = address_parts.join(", ")

      parts = name.strip.split(/\s+/, 2)
      firstname = parts[0]
      lastname = parts[1].presence || parts[0]

      india = Spree::Country.find_by(iso: "IN") || Spree::Country.default
      state_obj = PricingService.detect_state(pincode: pincode, city_name: city)
      state_obj ||= Spree::State.find_by(name: "Karnataka")

      phone_clean = @chat.phone_number.to_s.gsub(/\D/, '')
      phone_clean = phone_clean[-10..-1] if phone_clean.length > 10
      phone = phone_clean.presence || "9999999999"

      address_params = {
        firstname: firstname,
        lastname: lastname,
        phone: phone,
        address1: full_address,
        city: city.presence || "Bangalore",
        zipcode: zipcode_format(pincode),
        state: state_obj,
        country: india
      }

      order.create_bill_address!(address_params)
      order.create_ship_address!(address_params)
      order.update!(use_billing: true)
      order.reload

      clean_phone = @chat.phone_number.gsub(/\D/, '')
      clean_phone = "whatsapp" if clean_phone.blank?
      order.update!(email: "whatsapp_#{clean_phone}@jeenimilletmix.in", guest_order: true)

      order.next if order.state == 'cart'
      order.next if order.state == 'address'

      if order.state == 'delivery'
        order.shipments.each do |shipment|
          if shipment.selected_shipping_rate_id.nil? && shipment.shipping_rates.any?
            shipment.update(selected_shipping_rate_id: shipment.shipping_rates.first.id)
          end
        end
        order.next
      end

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

      order.next if order.state == 'confirm'

      if order.completed?
        order_num = order.number
        @chat.update!(cart_id: nil, state: "idle")
        @chat.clear_metadata!

        "🎉 Thank you, #{name}! Your order has been placed successfully.\n\n*Order ID:* ##{order_num}\nWe will contact you shortly to coordinate shipping."
      else
        "Failed to place order. Current checkout state: #{order.state}. Please try again or type *cancel*."
      end
    end

    def cancel_cart
      order = @chat.cart_id.present? ? Spree::Order.find_by(id: @chat.cart_id) : nil
      if order
        order.line_items.destroy_all
        order.destroy!
      end
      @chat.update!(cart_id: nil, state: "idle")
      @chat.clear_metadata!
      "Your cart has been cleared and chat session reset. Type *list* to browse products."
    end

    def zipcode_format(pin)
      pin.present? && pin.match?(/\A\d{6}\z/) ? pin : "560001"
    end
  end
end
