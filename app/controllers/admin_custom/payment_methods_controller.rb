class AdminCustom::PaymentMethodsController < ApplicationController
  before_action :authenticate_spree_user!
  before_action :authorize_admin!
  layout "admin_custom"

  def index
    @payment_methods = Spree::PaymentMethod.all
  end

  def edit
    @payment_method = Spree::PaymentMethod.find(params[:id])
  end

  def update
    @payment_method = Spree::PaymentMethod.find(params[:id])
    
    # Find the parameter key dynamically (which might be payment_method_razorpay, payment_method_check, etc.)
    param_key = params.keys.find { |k| k.start_with?("payment_method") }
    method_params = params[param_key] || {}
    
    @payment_method.name = method_params[:name]
    @payment_method.description = method_params[:description]
    @payment_method.active = method_params[:active] == "1"

    if @payment_method.is_a?(Spree::PaymentMethod::Razorpay)
      @payment_method.preferred_key_id = method_params[:preferred_key_id]
      @payment_method.preferred_key_secret = method_params[:preferred_key_secret]
      @payment_method.preferred_webhook_secret = method_params[:preferred_webhook_secret]
    end

    if @payment_method.save
      redirect_to admin_custom_payment_methods_path, notice: "Payment method updated successfully."
    else
      flash.now[:alert] = "Failed to update payment method: #{@payment_method.errors.full_messages.join(', ')}"
      render :edit
    end
  end
end
