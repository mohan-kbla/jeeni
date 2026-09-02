module Spree
  module UserDecorator
    def self.prepended(base)
      base.validates :first_name, presence: true
      base.validates :last_name, presence: true
    end
    def read_only_orders?
      has_spree_role?("read_only_orders") && !has_spree_role?("admin")
    end
    def orders_manager?
      has_spree_role?("orders_manager") && !has_spree_role?("admin")
    end
  end
end

Spree::User.prepend Spree::UserDecorator

