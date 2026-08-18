module Spree
  module Api
    module V2
      module Storefront
        module ProductSerializerDecorator
          def self.prepended(base)
            base.attributes :default_price, :karnataka_price, :current_price, :is_karnataka_price
            
            base.attribute :default_price do |product|
              product.price
            end

            base.attribute :karnataka_price do |product|
              product.karnataka_price
            end

            base.attribute :current_price do |product, params|
              address = params[:address] || params[:order]&.ship_address || params[:order]&.bill_address
              PricingService.calculate(product.master, address)
            end

            base.attribute :is_karnataka_price do |product, params|
              address = params[:address] || params[:order]&.ship_address || params[:order]&.bill_address
              PricingService.is_karnataka?(address) && product.karnataka_price.present?
            end
          end
        end
      end
    end
  end
end

# Check if serializer is loaded/defined before prepending, to avoid load errors
if defined?(Spree::Api::V2::Storefront::ProductSerializer)
  Spree::Api::V2::Storefront::ProductSerializer.prepend(Spree::Api::V2::Storefront::ProductSerializerDecorator)
else
  # Fallback: if not loaded yet, wait for active_support to load it
  ActiveSupport.on_load(:action_controller) do
    if defined?(Spree::Api::V2::Storefront::ProductSerializer)
      Spree::Api::V2::Storefront::ProductSerializer.prepend(Spree::Api::V2::Storefront::ProductSerializerDecorator)
    end
  end
end
