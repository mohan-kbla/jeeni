module Whatsapp
  class OrderAutoPlacementJob < ApplicationJob
    queue_as :default

    def perform(chat_id, cart_id)
      chat = WhatsappChat.find_by(id: chat_id)
      return if chat.nil? || chat.cart_id != cart_id
      return unless %w[confirming entering_detailed_address confirming_detailed].include?(chat.state)

      order = Spree::Order.find_by(id: cart_id)
      return if order.nil? || order.completed?

      # Ensure we have the minimum details (name, city, place)
      name = chat.get_metadata("name")
      city = chat.get_metadata("city")
      place = chat.get_metadata("place")
      return if name.blank? || city.blank? || place.blank?

      pincode = chat.get_metadata("pincode")
      detailed_address = chat.get_metadata("detailed_address")

      address_parts = [place, city, pincode].reject(&:blank?)
      address_parts.unshift(detailed_address) if detailed_address.present?
      full_address = address_parts.join(", ")

      # Split name
      parts = name.strip.split(/\s+/, 2)
      firstname = parts[0]
      lastname = parts[1].presence || parts[0]

      india = Spree::Country.find_by(iso: "IN") || Spree::Country.default
      state_obj = nil
      if city.present?
        state_obj = Spree::State.where(country: india).where("LOWER(name) = ? OR LOWER(abbr) = ?", city.downcase, city.downcase).first
      end
      state_obj ||= Spree::State.find_by(name: "Karnataka")

      phone_clean = chat.phone_number.to_s.gsub(/\D/, '')
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

      clean_phone = chat.phone_number.gsub(/\D/, '')
      clean_phone = "whatsapp" if clean_phone.blank?
      order.update!(email: "whatsapp_#{clean_phone}@jeenimilletmix.in", guest_order: true)

      # Transition order
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

      # Reset chat session
      chat.update!(cart_id: nil, state: "idle")
      chat.clear_metadata!

      message = "Hi #{name}, since we didn't hear back, we have automatically placed your order with the details provided:\n\n"\
                "• Address: #{full_address}\n"\
                "• Total: #{order.display_total}\n\n"\
                "Your Order ID is ##{order.number}. If you need to make changes, please reply to this message!"

      Whatsapp::Client.send_message(chat.phone_number, message)
    rescue => e
      Rails.logger.error("Error in Whatsapp::OrderAutoPlacementJob: #{e.message}\n#{e.backtrace.join("\n")}")
    end

    private

    def zipcode_format(pin)
      pin.present? && pin.match?(/\A\d{6}\z/) ? pin : "560001"
    end
  end
end
