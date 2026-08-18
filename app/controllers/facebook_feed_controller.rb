class FacebookFeedController < ApplicationController
  # This endpoint must be public and accessible without authentication
  skip_before_action :authenticate_spree_user!, raise: false rescue nil
  
  layout false

  def index
    # Cache response in the browser/CDN for 10 minutes
    expires_in 10.minutes, public: true

    # Create a dynamic cache key that changes when products are modified, created, or deleted
    cache_key = "facebook_feed_xml/v3/#{Spree::Product.active_products.count}-#{Spree::Product.active_products.maximum(:updated_at).to_i}"

    xml_data = Rails.cache.fetch(cache_key) do
      # Fetch active products including their master variant images and prices to avoid N+1 queries
      products = Spree::Product.active_products.includes(
        master: [:images, :default_price], 
        taxons: :taxonomy
      )
      generate_xml_feed(products)
    end

    render xml: xml_data, content_type: 'application/xml'
  end

  private

  def generate_xml_feed(products)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
    
    xml.rss version: "2.0", "xmlns:g" => "http://base.google.com/ns/1.0" do
      xml.channel do
        xml.title "Jeeni Millet Mix Catalog"
        xml.link "https://jeenimilletmix.in"
        xml.description "Product Catalog for Jeeni Millet Mix Dynamic Ads"
        
        products.each do |product|
          xml.item do
            # 1. ID
            xml.tag! "g:id", (product.master.sku.presence || product.id.to_s)
            
            # 2. Title
            xml.tag! "g:title", product.name
            
            # 3. Description (Sanitized and stripped of HTML)
            xml.tag! "g:description", helpers.strip_tags(product.description).to_s.strip
            
            # 4. Link
            xml.tag! "g:link", Rails.application.routes.url_helpers.product_detail_url(product, host: 'jeenimilletmix.in', protocol: 'https')
            
            # 5. Image Link
            xml.tag! "g:image_link", absolute_image_url(product)
            
            # 6. Brand
            xml.tag! "g:brand", "JEENI"
            
            # 7. Condition
            xml.tag! "g:condition", "new"
            
            # 8. Availability
            xml.tag! "g:availability", (product.master.can_supply? ? "in stock" : "out of stock")
            
            # 9. Price & Sale Price
            amount = product.price.to_f
            compare_amount = product.master.default_price&.compare_at_amount&.to_f
            currency = product.currency || 'INR'
            
            if compare_amount && compare_amount > amount
              xml.tag! "g:price", sprintf("%.2f %s", compare_amount, currency)
              xml.tag! "g:sale_price", sprintf("%.2f %s", amount, currency)
            else
              xml.tag! "g:price", sprintf("%.2f %s", amount, currency)
            end
            
            # 10. Google Product Category
            category = google_product_category(product)
            xml.tag! "g:google_product_category", category if category.present?
          end
        end
      end
    end
    xml.target!
  end

  def absolute_image_url(product)
    url = helpers.product_image_url(product)
    if url.to_s.start_with?('http')
      url
    else
      domain = "https://jeenimilletmix.in"
      url = "/#{url}" unless url.to_s.start_with?('/')
      "#{domain}#{url}"
    end
  end

  def google_product_category(product)
    name = product.name.to_s.downcase
    taxons = product.taxons.map(&:name).map(&:downcase)
    
    if name.include?("dress") || name.include?("wear") || taxons.any? { |t| t.include?("wear") || t.include?("clothing") }
      "Apparel & Accessories > Clothing"
    elsif name.include?("watch") || taxons.any? { |t| t.include?("smartphones") || t.include?("electronics") }
      "Electronics > Communications > Telephony > Mobile Phones"
    elsif name.include?("headphone") || name.include?("audio")
      "Electronics > Audio > Audio Components > Headphones"
    elsif name.include?("millet") || name.include?("health mix") || name.include?("coffee") || name.include?("cofpee") || name.include?("sugaramla") || taxons.any? { |t| t.include?("millet") || t.include?("food") }
      "Food, Beverages & Tobacco > Food Items > Grains & Cereals"
    else
      "Food, Beverages & Tobacco > Food Items > Grains & Cereals"
    end
  end
end
