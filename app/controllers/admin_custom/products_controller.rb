class AdminCustom::ProductsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_product, only: [:show, :edit, :update, :destroy]
  layout "admin_custom"

  def index
    # Load all products, paginated
    @products = Spree::Product.includes(:category, master: [:images, :default_price]).order(created_at: :desc).page(params[:page]).per(15)
  end

  def show
    @variants = @product.variants.includes(:option_values, :default_price)
  end

  def new
    @product = Spree::Product.new
  end

  def create
    @product = Spree::Product.new(product_params)
    @product.sku = "SKU-#{SecureRandom.hex(4).upcase}" if @product.sku.blank?
    
    # Spree requires a shipping category for all products
    shipping_category = Spree::ShippingCategory.first_or_create!(name: "Default")
    @product.shipping_category = shipping_category
    @product.price = params[:product][:price].to_f if params[:product][:price].present?
    if params[:product].key?(:karnataka_price)
      @product.karnataka_price = params[:product][:karnataka_price].present? ? params[:product][:karnataka_price].to_f : nil
    end
    @product.status = (@product.active ? 'active' : 'draft')
    
    # Associate with default store
    store = defined?(current_store) && current_store ? current_store : Spree::Store.default
    @product.store_ids = [store.id] if store
    
    if @product.save
      flash[:notice] = "Product created successfully."
      redirect_to admin_custom_product_path(@product)
    else
      flash.now[:alert] = "Error creating product: #{@product.errors.full_messages.join(', ')}"
      render :new
    end
  end

  def edit
  end

  def update
    # Update price explicitly if provided
    if params[:product][:price].present?
      @product.price = params[:product][:price].to_f
    end
    if params[:product].key?(:karnataka_price)
      @product.karnataka_price = params[:product][:karnataka_price].present? ? params[:product][:karnataka_price].to_f : nil
    end
    
    if @product.update(product_params)
      @product.update_columns(status: (@product.active ? 'active' : 'draft'))
      flash[:notice] = "Product updated successfully."
      redirect_to admin_custom_product_path(@product)
    else
      flash.now[:alert] = "Error updating product: #{@product.errors.full_messages.join(', ')}"
      render :edit
    end
  end

  def destroy
    @product.destroy
    flash[:notice] = "Product deleted successfully."
    redirect_to admin_custom_products_path
  end

  def toggle_visibility
    @product = Spree::Product.friendly.find(params[:id])
    @product.active = !@product.active
    @product.status = (@product.active ? 'active' : 'draft')
    @product.save!
    @product.update_columns(status: @product.status)
    
    flash[:notice] = "Product visibility updated successfully."
    redirect_to admin_custom_products_path
  end

  private

  def set_product
    @product = Spree::Product.friendly.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name, :description, :sku, :available_on, 
      :state, :district, :featured, :active, :category_id,
      product_gallery_attributes: [
        :id, :featured_image_id, :featured_video_id, :youtube_link,
        new_images: [],
        new_videos: [],
        gallery_images_attributes: [:id, :file, :position, :is_featured, :_destroy],
        gallery_videos_attributes: [:id, :file, :position, :external_url, :is_featured, :_destroy]
      ]
    )
  end
end
