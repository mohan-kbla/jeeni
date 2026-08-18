# app/controllers/spree/user_registrations_controller_decorator.rb

if Gem.loaded_specs['spree_auth_devise']
  gem_path = Gem.loaded_specs['spree_auth_devise'].full_gem_path
  require File.join(gem_path, "lib/controllers/frontend/spree/user_registrations_controller")
end

module Spree::UserRegistrationsControllerDecorator
  def redirect_to_checkout_or_account_path(resource)
    if current_order && current_order.line_items.any?
      redirect_to main_app.checkout_path
    else
      redirect_to main_app.account_path
    end
  end
end

Spree::UserRegistrationsController.prepend Spree::UserRegistrationsControllerDecorator
