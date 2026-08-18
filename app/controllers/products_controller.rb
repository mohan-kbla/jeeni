class ProductsController < ApplicationController
  def index
    # Initialize the base query for active products
    priority_order = Arel.sql("CASE WHEN spree_products.slug = 'jeeni-slim-new' THEN 0 WHEN spree_products.slug = 'jeeni-sugaramla-1kg-sugaramla-1kg' THEN 1 ELSE 2 END")
    @products = Spree::Product.active_products.includes(master: [:images, :default_price]).order(priority_order)
    
    # 1. Search Query
    if params[:query].present?
      @products = @products.joins(:translations)
                           .where(spree_product_translations: { locale: I18n.locale.to_s })
                           .where("spree_product_translations.name LIKE :q OR spree_product_translations.description LIKE :q", q: "%#{params[:query]}%")
    end
    
    # 2. Category (Taxon) Filter
    if params[:category].present?
      @products = @products.joins(:taxons).where(spree_taxons: { id: params[:category] })
    end
    
    # 3. Location Filters (State & District)
    if params[:state].present?
      @products = @products.where(state: params[:state])
    end
    if params[:district].present?
      @products = @products.where(district: params[:district])
    end
    
    # 4. Price Filters (using joins on master variant price)
    @products = @products.joins(master: :default_price)
    if params[:price_min].present?
      @products = @products.where("spree_prices.amount >= ?", params[:price_min].to_f)
    end
    if params[:price_max].present?
      @products = @products.where("spree_prices.amount <= ?", params[:price_max].to_f)
    end
    
    # 5. Availability (In-Stock) Filter
    if params[:available].present? && params[:available] == "1"
      @products = @products.joins(variants_including_master: :stock_items)
                           .where("spree_stock_items.count_on_hand > 0 OR spree_stock_items.backorderable = ?", true)
                           .distinct
    end
    
    # 6. Featured Filter
    if params[:featured].present? && params[:featured] == "1"
      @products = @products.where(featured: true)
    end
    
    # Paginate results
    @products = @products.page(params[:page]).per(12)
    
    # Load filter options (for dropdowns)
    @categories = Spree::Taxonomy.all.includes(:root)
    @states = Spree::Product.where.not(state: nil).pluck(:state).uniq
    @districts = Spree::Product.where.not(district: nil).pluck(:district).uniq
  end

  def show
    # Load product by friendly ID (slug)
    @product = Spree::Product.friendly.find(params[:id])
    
    unless @product.active?
      flash[:alert] = "This product is currently unavailable."
      redirect_to products_path and return
    end
    
    @variants = @product.variants.includes(:option_values, :default_price, :images)
    @images = @product.images
    
    # Fallback to master images if no product images
    @images = @product.master.images if @images.empty?

    # CRO Flag for Priority Offer Products (Jeeni Slim & Jeeni Sugaramla 1kg)
    @is_jeeni_slim = (@product.slug == 'jeeni-slim-new' || @product.slug == 'jeeni-sugaramla-1kg-sugaramla-1kg' || @product.name.to_s.downcase.include?('jeeni slim') || @product.name.to_s.downcase.include?('sugaramla'))

    # Record view_product funnel event
    visitor_id = cookies[:visitor_id]
    if visitor_id.present?
      FunnelEvent.track(
        visitor_id: visitor_id,
        event_name: 'view_product',
        product_id: @product.id,
        user_agent: request.user_agent,
        path: request.path
      )
    end
  end
end

