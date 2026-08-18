class AdminCustom::FaqsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_faq, only: [:edit, :update, :destroy]
  layout "admin_custom"

  def index
    @faqs = Faq.all.order(product_id: :asc, position: :asc, created_at: :desc)
  end

  def new
    @faq = Faq.new
    @products = Spree::Product.active_products.order(:name)
  end

  def create
    @faq = Faq.new(faq_params)
    if @faq.save
      redirect_to admin_custom_faqs_path, notice: "FAQ created successfully."
    else
      @products = Spree::Product.active_products.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = Spree::Product.active_products.order(:name)
  end

  def update
    if @faq.update(faq_params)
      redirect_to admin_custom_faqs_path, notice: "FAQ updated successfully."
    else
      @products = Spree::Product.active_products.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @faq.destroy
    redirect_to admin_custom_faqs_path, notice: "FAQ deleted."
  end

  private

  def set_faq
    @faq = Faq.find(params[:id])
  end

  def faq_params
    params.require(:faq).permit(:question, :answer, :product_id, :position, :active)
  end
end
