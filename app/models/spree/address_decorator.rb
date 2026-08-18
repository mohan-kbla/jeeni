module Spree
  module AddressDecorator
    def self.prepended(base)
      base.validates :phone, presence: true

      base.validates :phone, format: { with: /\A\d{10}\z/, message: "must be exactly 10 digits" }, if: :require_india_phone_validation?
      base.validates :zipcode, format: { with: /\A\d{6}\z/, message: "must be exactly 6 digits" }, allow_blank: true, if: :require_india_zipcode_validation?
    end

    def require_zipcode?
      false
    end

    private

    def require_india_phone_validation?
      country&.iso == 'IN'
    end

    def require_india_zipcode_validation?
      country&.iso == 'IN'
    end
  end
end

Spree::Address.prepend(Spree::AddressDecorator)
