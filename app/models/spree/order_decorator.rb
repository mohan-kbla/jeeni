module Spree
  module OrderDecorator
    def self.prepended(base)
      base.class_eval do
        # Redefine checkout flow states without delivery state
        checkout_flow do
          go_to_state :address
          go_to_state :payment, if: ->(order) { order.payment_required? }
          go_to_state :confirm, if: ->(order) { order.confirmation_required? }
          go_to_state :complete
        end
      end

      base.state_machine do
        state :dispatched

        # Guard: Prevent transitioning to complete if Razorpay payment is not completed/captured
        before_transition to: :complete do |order, transition|
          # Reload payments to get the absolute latest payment records
          payment = order.payments.reload.last rescue order.payments.last
          if payment && payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay) && payment.state != 'completed'
            order.errors.add(:base, "Razorpay payment must be completed before placing your order.")
            throw :halt # Halts the transition in state_machines
          end
        end

        # Automatically create proposed shipments and select default shipping rate when transitioning out of address state
        before_transition from: :address, to: :payment do |order, transition|
          puts "DEBUG: before_transition from address to payment running!"
          begin
            # 1. Create proposed shipments (Spree's standard way)
            if order.shipments.empty?
              order.create_proposed_shipments
            end
            
            # 2. Select cheapest/default shipping rate for each shipment
            order.shipments.each do |shipment|
              if shipment.shipping_rates.any?
                cheapest_rate = shipment.shipping_rates.min_by(&:cost)
                shipment.selected_shipping_rate_id = cheapest_rate.id
                shipment.update_columns(selected_shipping_rate_id: cheapest_rate.id) rescue nil
              end
            end
            
            # 3. Update order totals
            order.updater.update_shipment_total
            order.updater.update
          rescue => e
            Rails.logger.error "Error in auto-shipping transition: #{e.message}\n#{e.backtrace.join("\n")}"
          end
        end
      end
    end

    def confirmation_required?
      # Reload payments to ensure Spree checks the newly selected payment method
      last_payment = payments.reload.last rescue payments.last
      if last_payment && last_payment.payment_method.is_a?(Spree::PaymentMethod::Razorpay)
        true
      else
        super
      end
    end

    def available_payment_methods
      super
    end
  end
end

module Spree
  module OrderUpdaterDecorator
    def update
      update_line_item_prices
      super
    end

    def update_shipment_total
      unless order.completed?
        order.shipments.each_with_index do |shipment, index|
          new_cost = calculate_shipment_cost(shipment, index == 0)
          if shipment.cost != new_cost
            shipment.update_columns(cost: new_cost)
          end
        end
      end
      super
    end

    private

    def update_line_item_prices
      return if order.completed?

      order.line_items.each do |line_item|
        target_price = PricingService.calculate(line_item.variant, order)
        if line_item.price != target_price
          line_item.update_columns(price: target_price)
        end
      end
    end

    private

    def calculate_shipment_cost(shipment, is_first_shipment)
      default_cost = 0.0
      rate = shipment.shipping_rates.find_by(selected: true) || shipment.shipping_rates.first
      if rate
        default_cost = rate.cost || 0.0
      else
        shipping_method = shipment.shipping_method || order.shipping_methods.first
        default_cost = shipping_method&.calculator&.compute(shipment) || 0.0
      end

      ship_addr = (order.ship_address.reload rescue order.ship_address)
      return default_cost if ship_addr.nil?

      state_name = (ship_addr.state&.name || ship_addr.state_name).to_s.downcase.strip
      is_karnataka = (state_name == 'karnataka')

      if !is_karnataka
        has_free_shipping_products = order.line_items.any? do |li|
          slug = li.product.slug.to_s.downcase
          slug.include?('slim') || slug.include?('sugaramla')
        end
        if has_free_shipping_products
          0.0
        else
          is_first_shipment ? 80.0 : 0.0
        end
      else
        default_cost
      end
    end
  end
end

Spree::Order.prepend Spree::OrderDecorator
Spree::OrderUpdater.prepend Spree::OrderUpdaterDecorator

module Spree
  module ShipmentDecorator
    def update_amounts
      if order.completed?
        update_columns(
          adjustment_total: adjustments.additional.map(&:update!).compact.sum,
          updated_at: Time.current
        )
      else
        super
      end
    end
  end
end

Spree::Shipment.prepend Spree::ShipmentDecorator
