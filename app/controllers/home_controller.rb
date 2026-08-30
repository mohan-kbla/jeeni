class HomeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:set_location]

  def set_location
    pincode = params[:pincode].to_s.gsub(/\D/, '').strip
    if pincode.length == 6
      session[:visitor_pincode] = pincode
      if pincode.match?(/\A5[6-9]\d{4}\z/)
        session[:visitor_state] = 'Karnataka'
        render json: { success: true, is_karnataka: true, message: "Karnataka Special Price unlocked!" }
      else
        state_obj = PricingService.state_by_pincode(pincode)
        session[:visitor_state] = state_obj ? state_obj.name : 'Other States'
        render json: { success: true, is_karnataka: false, message: "Default price applies." }
      end
    elsif params[:state].present?
      state_name = params[:state].to_s.strip.titleize
      session[:visitor_state] = state_name
      session[:visitor_pincode] = nil
      is_ka = state_name.downcase == 'karnataka'
      render json: { success: true, is_karnataka: is_ka, message: is_ka ? "Karnataka Special Price unlocked!" : "#{state_name} active." }
    else
      session[:visitor_state] = 'Other States'
      session[:visitor_pincode] = nil
      render json: { success: true, is_karnataka: false, message: "Location reset." }
    end
  end

  def index
    # Load active, featured products with images
    priority_order = Arel.sql("CASE WHEN spree_products.slug = 'jeeni-slim-new' THEN 0 WHEN spree_products.slug = 'jeeni-sugaramla-1kg-sugaramla-1kg' THEN 1 ELSE 2 END")
    
    # Load primary conversion products (Jeeni Slim & Jeeni Sugaramla 1KG)
    @primary_products = Spree::Product.active_products.where("LOWER(slug) LIKE '%slim%' OR LOWER(slug) LIKE '%sugaramla%' OR LOWER(name) LIKE '%slim%' OR LOWER(name) LIKE '%sugaramla%'").includes(master: [:images, :default_price]).order(priority_order).limit(2)
    primary_ids = @primary_products.map(&:id)
    
    # Load Vegetable Coffee gift product dynamically from DB
    @gift_product = Spree::Product.find_by(slug: 'vegetable-cofpee') || Spree::Product.where("LOWER(name) LIKE ?", "%vegetable%").first
 
    # Load Hero Banner showcase products
    @banner_products = Spree::Product.active_products.includes(master: [:images, :default_price]).limit(5)
    @slim_product = Spree::Product.active_products.find_by(slug: 'jeeni-slim-new') || Spree::Product.active_products.where("LOWER(slug) LIKE '%slim%' OR LOWER(name) LIKE '%slim%'").first
    @sugaramla_product = Spree::Product.active_products.find_by(slug: 'jeeni-sugaramla-1kg-sugaramla-1kg') || Spree::Product.active_products.where("LOWER(slug) LIKE '%sugaramla%' OR LOWER(name) LIKE '%sugaramla%'").first
    
    # Load all remaining products for "Explore More Healthy Products"
    @other_products = Spree::Product.active_products.where.not(id: primary_ids).includes(master: [:images, :default_price]).limit(8)

    @featured_products = Spree::Product.featured.active_products.includes(master: [:images, :default_price]).order(priority_order).limit(3)
    @latest_products = Spree::Product.active_products.includes(master: [:images, :default_price]).order(priority_order).limit(8)
    
    # Load recent published blog posts
    @recent_posts = Blog.published.recent.limit(3)
    
    # Load root taxons (categories)
    @categories = Spree::Taxonomy.all.includes(:root)

    # Load active testimonials / reviews
    @testimonials = Testimonial.active.includes(:product).limit(6)

    # Load global FAQs
    @faqs = Faq.active.where(product_id: nil).ordered.limit(5)
  end
end
