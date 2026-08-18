module Spree
  module VariantDecorator
    def self.prepended(base)
      base.class_eval do
        def karnataka_price
          default_price&.karnataka_price
        end

        def karnataka_price=(value)
          (default_price || build_default_price).karnataka_price = value
        end
      end
    end
  end
end

Spree::Variant.prepend Spree::VariantDecorator
