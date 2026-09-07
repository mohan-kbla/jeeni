module ApplicationHelper
  # Helper to set page title dynamically
  def title(page_title)
    content_for(:title) { page_title }
  end

  # Helper to retrieve configured or fallback Meta Pixel ID
  def meta_pixel_id
    CroSetting.get('meta_pixel_id').presence || ENV['META_PIXEL_ID'].presence || '1355071780050188'
  end

  # Helper to retrieve configured Google Analytics ID
  def google_analytics_id
    CroSetting.get('google_analytics_id').presence || ENV['GOOGLE_ANALYTICS_ID'].presence || ''
  end

  # Helper to retrieve configured Google Tag Manager Container ID (defaults to GTM-N28R82Z)
  def gtm_container_id
    CroSetting.get('gtm_container_id').presence || ENV['GTM_CONTAINER_ID'].presence || 'GTM-N28R82Z'
  end

  # Helper to retrieve configured Google Tag ID (defaults to GT-55KXGQZ)
  def google_tag_id
    CroSetting.get('google_tag_id').presence || ENV['GOOGLE_TAG_ID'].presence || CroSetting.get('google_analytics_id').presence || ENV['GOOGLE_ANALYTICS_ID'].presence || 'GT-55KXGQZ'
  end

  # Helper to retrieve configured Google Ads Conversion ID (optional, e.g. AW-XXXXXXXXX)
  def google_ads_conversion_id
    CroSetting.get('google_ads_conversion_id').presence || ENV['GOOGLE_ADS_CONVERSION_ID'].presence || 'AW-17269273792'
  end

  # Helper to retrieve configured Google Ads Conversion Label (optional, e.g. AbC-D_efGhIjKLmN)
  def google_ads_conversion_label
    CroSetting.get('google_ads_conversion_label').presence || ENV['GOOGLE_ADS_CONVERSION_LABEL'].presence || '6PGNCJfsvOwcEMDpK0pA'
  end

  # Helper to compute Google Ads conversion target for send_to (e.g. AW-XXXXXXXXX/AbC-D_efGhIjKLmN)
  def google_ads_send_to_target
    conv_id = google_ads_conversion_id
    conv_label = google_ads_conversion_label
    if conv_id.present? && conv_label.present?
      "#{conv_id}/#{conv_label}"
    elsif conv_id.present?
      conv_id
    else
      nil
    end
  end

  # Helper to set page meta description dynamically
  def meta_description(description)
    content_for(:meta_description) { description }
  end

  # Helper to render status badges in views
  def status_badge(status, type = :default)
    badge_class = case status.to_s.downcase
                  when 'complete', 'paid', 'approved', 'active', 'yes', 'shipped'
                    'badge-success'
                  when 'pending', 'ready', 'balance_due', 'draft', 'warning'
                    'badge-warning'
                  when 'void', 'failed', 'rejected', 'inactive', 'no', 'canceled'
                    'badge-danger'
                  else
                    'badge-info'
                  end
    content_tag(:span, status.to_s.titleize, class: "badge #{badge_class}")
  end

  # Helper to resolve Jeeni product images based on SKU
  def product_image_url(product)
    # 1. Try to fetch from the custom product gallery if available
    if product.respond_to?(:product_gallery) && product.product_gallery.present?
      gallery = product.product_gallery
      featured_image = gallery.gallery_images.find_by(is_featured: true)
      featured_image ||= gallery.gallery_images.order(position: :asc).first
      
      if featured_image && featured_image.file.attached?
        begin
          return Rails.application.routes.url_helpers.rails_blob_path(featured_image.file, only_path: true)
        rescue => e
          # fallback to SKU mapping on error
        end
      end
    end

    # 2. Try to fetch from standard Spree images or master variant images
    spree_images = []
    if product.respond_to?(:images) && product.images.any?
      spree_images = product.images
    elsif product.respond_to?(:master) && product.master.respond_to?(:images) && product.master.images.any?
      spree_images = product.master.images
    end

    if spree_images.any?
      first_spree_image = spree_images.first
      if first_spree_image.respond_to?(:attachment) && first_spree_image.attachment.attached?
        begin
          return Rails.application.routes.url_helpers.rails_blob_path(first_spree_image.attachment, only_path: true)
        rescue => e
          # fallback to SKU mapping on error
        end
      end
    end

    sku = product.respond_to?(:sku) ? product.sku : (product.respond_to?(:master) ? product.master&.sku : nil)
    sku ||= product.respond_to?(:slug) ? product.slug.upcase : ""

    mappings = {
      "JN-MIL-HLTH" => "/product_health_mix.png",
      "JN-MIL-TRAD" => "/product_health_mix.png",
      "JN-MIL-WMN" => "/product_womens_strong.png",
      "JN-MIL-SPROT" => "/product_sprouted_mix.png",
      "JN-SLIM" => "/product_slim_mix.png",
      "JN-SUGAR" => "/product_health_mix.png",
      "JN-COOK-RAGI" => "/jeeni_placeholder.png",
      "JN-OIL-GND" => "/jeeni_placeholder.png",
      "JN-KID-TRAD" => "/product_health_mix.png"
    }

    # Fallback to Jivabhumi images or placeholder
    mappings[sku] || "/jeeni_placeholder.png"
  end

  # Check if a product is one of the two priority highlight items
  def priority_product?(product)
    slug = product.slug.to_s.strip
    slug == "jeeni-slim-new" || slug == "jeeni-sugaramla-1kg-sugaramla-1kg"
  end

  # Render video player or image carousel if priority product has images/video, otherwise fallback to product image
  def render_product_media(product)
    name_down = product.name.to_s.downcase.strip
    if name_down == "jeeni millet health mix 1kg"
      images = []
      if product.respond_to?(:product_gallery) && product.product_gallery.present?
        images = product.product_gallery.gallery_images.select { |gi| gi.file.attached? }
      end
      if images.empty?
        if product.respond_to?(:images) && product.images.any?
          images = product.images
        elsif product.respond_to?(:master) && product.master.respond_to?(:images) && product.master.images.any?
          images = product.master.images
        end
      end
      
      if images.any?
        carousel_html = ""
        carousel_html << "<div class='card-carousel' id='carousel-#{product.id}' data-current-index='0' style='position: relative; width: 100%; height: 100%; overflow: hidden;'>"
        carousel_html << "<div class='carousel-track' style='display: flex; width: 100%; height: 100%; transition: transform 0.5s cubic-bezier(0.4, 0, 0.2, 1);'>"
        
        images.each do |img|
          img_url = if img.respond_to?(:file) && img.file.attached?
                      Rails.application.routes.url_helpers.rails_blob_path(img.file, only_path: true)
                    else
                      Rails.application.routes.url_helpers.rails_blob_path(img, only_path: true)
                    end
          carousel_html << "
            <div class='carousel-slide' style='flex: 0 0 100%; width: 100%; height: 100%;'>
              <img src='#{img_url}' class='card-img' style='width: 100%; height: 100%; object-fit: cover;' alt='#{product.name}' loading='lazy'>
            </div>
          "
        end
        
        carousel_html << "</div>" # end track
        
        # Navigation buttons if more than one image
        if images.size > 1
          carousel_html << "<button class='carousel-btn prev-btn' onclick='moveCarousel(\"#{product.id}\", -1, event)' style='position: absolute; top: 50%; left: 8px; transform: translateY(-50%); background: rgba(255,255,255,0.7); border: none; border-radius: 50%; width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; font-size: 1rem; cursor: pointer; z-index: 10; font-weight: bold; color: #333; box-shadow: 0 2px 5px rgba(0,0,0,0.15);'>‹</button>"
          carousel_html << "<button class='carousel-btn next-btn' onclick='moveCarousel(\"#{product.id}\", 1, event)' style='position: absolute; top: 50%; right: 8px; transform: translateY(-50%); background: rgba(255,255,255,0.7); border: none; border-radius: 50%; width: 28px; height: 28px; display: flex; align-items: center; justify-content: center; font-size: 1rem; cursor: pointer; z-index: 10; font-weight: bold; color: #333; box-shadow: 0 2px 5px rgba(0,0,0,0.15);'>›</button>"
          
          # Dots
          carousel_html << "<div class='carousel-dots' style='position: absolute; bottom: 8px; left: 50%; transform: translateX(-50%); display: flex; gap: 6px; z-index: 10;'>"
          images.each_with_index do |_, i|
            dot_style = i == 0 ? "background: #fbbf24; width: 12px; border-radius: 4px;" : "background: rgba(255,255,255,0.5); width: 8px; border-radius: 50%;"
            carousel_html << "<span class='carousel-dot-indicator' data-index='#{i}' style='height: 8px; cursor: pointer; border: 1px solid rgba(0,0,0,0.1); transition: all 0.3s ease; #{dot_style}'></span>"
          end
          carousel_html << "</div>" # end dots
        end
        
        # Embedded Javascript
        carousel_html << "
          <script>
            if (typeof window.moveCarousel === 'undefined') {
              window.moveCarousel = function(productId, direction, event) {
                if (event) event.stopPropagation();
                const carousel = document.getElementById('carousel-' + productId);
                if (!carousel) return;
                const track = carousel.querySelector('.carousel-track');
                const slides = carousel.querySelectorAll('.carousel-slide');
                const dots = carousel.querySelectorAll('.carousel-dot-indicator');
                if (!track || slides.length === 0) return;
                
                let currentIndex = parseInt(carousel.getAttribute('data-current-index') || '0');
                currentIndex = (currentIndex + direction + slides.length) % slides.length;
                
                carousel.setAttribute('data-current-index', currentIndex);
                track.style.transform = 'translateX(-' + (currentIndex * 100) + '%)';
                
                dots.forEach((dot, index) => {
                  if (index === currentIndex) {
                    dot.style.background = '#fbbf24';
                    dot.style.width = '12px';
                    dot.style.borderRadius = '4px';
                  } else {
                    dot.style.background = 'rgba(255,255,255,0.5)';
                    dot.style.width = '8px';
                    dot.style.borderRadius = '50%';
                  }
                });
              };
            }
          </script>
        "
        carousel_html << "</div>" # end carousel
        return carousel_html.html_safe
      end
    end

    if priority_product?(product)
      if product.respond_to?(:product_gallery) && product.product_gallery.present?
        gallery = product.product_gallery
        featured_video = gallery.gallery_videos.find_by(is_featured: true)
        featured_video ||= gallery.gallery_videos.order(position: :asc).first
        
        if featured_video
          if featured_video.file.attached?
            video_url = Rails.application.routes.url_helpers.rails_blob_path(featured_video.file, only_path: true)
            return "
              <div class='product-video-wrapper' style='position: relative; width: 100%; height: 100%; overflow: hidden;'>
                <video src='#{video_url}' autoplay muted loop playsinline class='card-img' style='width: 100%; height: 100%; object-fit: cover;' onclick='this.paused ? this.play() : this.pause();'></video>
              </div>
            ".html_safe
          elsif featured_video.youtube_embed_url.present?
            embed_url = featured_video.youtube_embed_url
            if embed_url.include?('youtube.com/embed/')
              separator = embed_url.include?('?') ? '&' : '?'
              playlist_param = embed_url.split('/embed/')[1]
              embed_url = "#{embed_url}#{separator}autoplay=1&mute=1&loop=1&controls=0&playlist=#{playlist_param}"
            end
            return "<iframe src='#{embed_url}' class='card-img' style='width: 100%; height: 100%; border: none; object-fit: cover;' allow='autoplay; encrypted-media' allowfullscreen></iframe>".html_safe
          end
        end
      end
    end
    
    image_url = product_image_url(product)
    "<img src='#{image_url}' class='card-img' style='width: 100%; height: 100%; object-fit: cover;' alt='#{product.name}' loading='lazy'>".html_safe
  end
end
