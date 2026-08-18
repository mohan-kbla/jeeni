class PromotionService
  ELIGIBLE_SLUGS = ['jeeni-slim-new', 'jeeni-sugaramla-1kg-sugaramla-1kg', 'sugaramla'].freeze
  GIFT_SLUG = 'vegetable-cofpee'.freeze

  class << self
    def unlocked_free_gift_promo?(order)
      return false unless order.present? && order.line_items.any?

      # Do not allow free gift for WATI webhook bookings
      return false if order.public_metadata&.[]('wati_webhook_booking') == true
      return false if order.public_metadata&.[]('whatsapp_cloud_booking') == true

      # Check if order has an eligible product
      order.line_items.any? do |li|
        slug = li.variant&.product&.slug.to_s.downcase
        name = li.variant&.product&.name.to_s.downcase
        ELIGIBLE_SLUGS.any? { |s| slug.include?(s) || name.include?(s) }
      end
    end

    def eligible_for_free_gift?(order, payment_method_type = nil)
      return false unless unlocked_free_gift_promo?(order)

      # Check payment method: online payment (Razorpay / Credit Card / Netbanking / UPI)
      if payment_method_type.present?
        return is_online_payment?(payment_method_type)
      end

      # Fallback to order's selected payment method
      if order.payments.any?
        payment_name = order.payments.last.payment_method&.name.to_s.downcase
        return !payment_name.include?('check') && !payment_name.include?('cash') && !payment_name.include?('cod')
      end

      # Fallback to false if no payment has been created/selected yet (e.g. cart/early checkout)
      false
    end

    def apply_promotions!(order, payment_method_type = nil)
      return unless order.present?

      if eligible_for_free_gift?(order, payment_method_type)
        add_free_gift!(order)
      else
        remove_free_gift!(order)
      end
    end

    def add_free_gift!(order)
      gift_product = Spree::Product.find_by(slug: GIFT_SLUG) || Spree::Product.where("LOWER(name) LIKE ?", "%vegetable%").first
      return unless gift_product.present? && gift_product.master.present?

      # Set auto-added metadata flag
      order.public_metadata ||= {}
      order.public_metadata['auto_added_free_gift'] = true
      order.save(validate: false) if order.changed?

      gift_variant = gift_product.master
      existing_gift = order.line_items.find { |li| li.variant_id == gift_variant.id }

      if existing_gift
        if existing_gift.price != 0
          existing_gift.update(price: 0.0, cost_price: 0.0)
          order.update_totals
          order.save
        end
      else
        line_item = order.line_items.new(
          variant: gift_variant,
          quantity: 1,
          price: 0.0,
          cost_price: 0.0
        )
        if line_item.save
          order.update_totals
          order.save
        end
      end
    end

    def remove_free_gift!(order)
      gift_product = Spree::Product.find_by(slug: GIFT_SLUG) || Spree::Product.where("LOWER(name) LIKE ?", "%vegetable%").first
      return unless gift_product.present? && gift_product.master.present?

      # If the gift was auto-added, destroy the line item completely
      if order.public_metadata&.[]('auto_added_free_gift') == true
        gift_line_items = order.line_items.select { |li| li.variant_id == gift_product.master.id }
        gift_line_items.each do |li|
          li.destroy
        end
        order.public_metadata.delete('auto_added_free_gift')
        order.save(validate: false) if order.changed?
      else
        # Otherwise, if it was manually added, make sure its price is updated to regular price
        gift_line_items = order.line_items.select { |li| li.variant_id == gift_product.master.id }
        gift_line_items.each do |li|
          if li.price == 0.0
            li.update(price: PricingService.calculate(li.variant, order))
          end
        end
      end

      order.update_totals
      order.save
    end

    def is_online_payment?(payment_method_type)
      str = payment_method_type.to_s.downcase
      !str.include?('cod') && !str.include?('cash') && !str.include?('check')
    end
  end
end
