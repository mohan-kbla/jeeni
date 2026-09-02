# app/controllers/spree/user_sessions_controller_decorator.rb

if Gem.loaded_specs['spree_auth_devise']
  gem_path = Gem.loaded_specs['spree_auth_devise'].full_gem_path
  require File.join(gem_path, "lib/controllers/frontend/spree/user_sessions_controller")
end

module Spree::UserSessionsControllerDecorator
  def create
    authenticate_spree_user!

    if spree_user_signed_in?
      respond_to do |format|
        format.html {
          flash[:success] = Spree.t(:logged_in_successfully)
          redirect_to after_sign_in_redirect(spree_current_user)
        }
        format.js {
          render json: { user: spree_current_user,
                           ship_address: spree_current_user.ship_address,
                           bill_address: spree_current_user.bill_address }.to_json
        }
      end
    else
      # Initialize resource so the Devise new template form has an object to reference
      self.resource = resource_class.new
      clean_up_passwords(resource)
      
      respond_to do |format|
        format.html {
          flash.now[:error] = t('devise.failure.invalid')
          render :new, status: :unprocessable_entity
        }
        format.js {
          render json: { error: t('devise.failure.invalid') }, status: :unprocessable_entity
        }
      end
    end
  end

  private

  def after_sign_in_redirect(user)
    if user.has_spree_role?("admin")
      main_app.admin_custom_root_path
    elsif user.has_spree_role?("read_only_orders") || user.has_spree_role?("orders_manager")
      main_app.admin_custom_orders_path
    else
      spree.account_path
    end
  end
end


Spree::UserSessionsController.prepend Spree::UserSessionsControllerDecorator
