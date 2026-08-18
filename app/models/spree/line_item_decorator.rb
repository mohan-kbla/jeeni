module Spree
  module LineItemDecorator
    def self.prepended(base)
      base.class_eval do
        def copy_price
          if variant
            is_gift = (variant.product.slug == PromotionService::GIFT_SLUG || variant.product.name.downcase.include?('vegetable'))
            if is_gift && order&.public_metadata&.[]('auto_added_free_gift') == true
              self.price = 0.0
            else
              self.price = PricingService.calculate(variant, order)
            end
            self.currency = order.currency
          end
        end
      end
    end
  end
end

Spree::LineItem.prepend Spree::LineItemDecorator
