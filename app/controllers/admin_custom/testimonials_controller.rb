class AdminCustom::TestimonialsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_testimonial, only: [:edit, :update, :destroy]
  layout "admin_custom"

  def index
    @testimonials = Testimonial.all.order(created_at: :desc)
  end

  def new
    @testimonial = Testimonial.new
    @products = Spree::Product.active_products.order(:name)
  end

  def create
    @testimonial = Testimonial.new(testimonial_params)
    if @testimonial.save
      redirect_to admin_custom_testimonials_path, notice: "Testimonial created successfully."
    else
      @products = Spree::Product.active_products.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @products = Spree::Product.active_products.order(:name)
  end

  def update
    if @testimonial.update(testimonial_params)
      redirect_to admin_custom_testimonials_path, notice: "Testimonial updated successfully."
    else
      @products = Spree::Product.active_products.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @testimonial.destroy
    redirect_to admin_custom_testimonials_path, notice: "Testimonial deleted."
  end

  private

  def set_testimonial
    @testimonial = Testimonial.find(params[:id])
  end

  def testimonial_params
    params.require(:testimonial).permit(:author_name, :rating, :content, :video_url, :is_success_story, :active, :product_id, :image)
  end
end
