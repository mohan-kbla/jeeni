module Spree
  module PriceDecorator
    def self.prepended(base)
      base.validates :karnataka_price, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
      base.validate :karnataka_price_cannot_be_greater_than_amount

      base.class_eval do
        private

        def karnataka_price_cannot_be_greater_than_amount
          if karnataka_price.present? && amount.present? && karnataka_price > amount
            errors.add(:karnataka_price, "cannot be greater than Default Price")
          end
        end
      end
    end
  end
end

Spree::Price.prepend Spree::PriceDecorator
