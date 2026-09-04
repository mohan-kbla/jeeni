class VisitorAttribution < ApplicationRecord
  validates :visitor_id, presence: true, uniqueness: true

  # Constants for Attribution Source Names
  GOOGLE_ADS = "Google Ads".freeze
  ORGANIC_GOOGLE_SEARCH = "Organic Google Search".freeze
  WHATSAPP = "WhatsApp".freeze
  FACEBOOK_ADS = "Facebook Ads".freeze
  INSTAGRAM_ADS = "Instagram Ads".freeze
  YOUTUBE = "YouTube".freeze
  EMAIL = "Email".freeze
  DIRECT = "Direct".freeze
  REFERRAL_WEBSITE = "Referral Website".freeze
  OTHER = "Other".freeze

  # Classify traffic source based on UTMs, gclid, and Referrer
  def self.classify(utm_source, utm_medium, utm_campaign, referrer, landing_page_url = nil)
    source = utm_source.to_s.downcase.strip
    medium = utm_medium.to_s.downcase.strip
    campaign = utm_campaign.to_s.downcase.strip
    ref = referrer.to_s.downcase.strip
    url = landing_page_url.to_s.downcase.strip

    # Check for Google Ads auto-tagging parameter (gclid) in URL or referrer
    is_gclid = url.include?("gclid=") || ref.include?("gclid=")

    # Check for Facebook Click Identifier (fbclid) in the landing page URL
    is_fb_click = url.include?("fbclid=")

    # 1. Google Ads (Priority #1: Paid Google traffic)
    if is_gclid
      return GOOGLE_ADS
    elsif source.match?(/(google_ads|gads|google-ads)/)
      return GOOGLE_ADS
    elsif (source == "google" || source == "googleads" || source == "gads") && (medium.match?(/(cpc|ppc|paid|ad)/) || campaign.present?) && medium != "organic"
      return GOOGLE_ADS
    elsif medium.match?(/(cpc|ppc)/) && (source.blank? || source == "google")
      return GOOGLE_ADS
    end

    # 2. WhatsApp (Priority #2)
    if source.match?(/(whatsapp|wa)/) || ref.match?(/(wa\.me|whatsapp\.com)/)
      return WHATSAPP
    end

    # 3. Other Paid Campaigns (Priority #3: Facebook & Instagram Ads)
    if is_fb_click
      if ref.include?("instagram") || source.match?(/(instagram|ig)/)
        return INSTAGRAM_ADS
      else
        return FACEBOOK_ADS
      end
    end

    if source.match?(/(facebook|fb)/) && (medium.match?(/(cpc|cpm|ad|paid)/) || campaign.present?)
      return FACEBOOK_ADS
    elsif source.match?(/(facebook_ads|fb_ads|facebook-ads)/)
      return FACEBOOK_ADS
    end

    if source.match?(/(instagram|ig)/) && (medium.match?(/(cpc|cpm|ad|paid)/) || campaign.present?)
      return INSTAGRAM_ADS
    elsif source.match?(/(instagram_ads|ig_ads|instagram-ads)/)
      return INSTAGRAM_ADS
    end

    # 4. Organic Google Search (Priority #4: Organic Google traffic)
    if (ref.match?(/(google\.com|google\.co\.in|google\.[a-z]{2,3})/) || source == "google") && !medium.match?(/(cpc|ppc|paid|ad)/)
      return ORGANIC_GOOGLE_SEARCH
    elsif source == "google" && medium == "organic"
      return ORGANIC_GOOGLE_SEARCH
    end

    # Organic / Social fallbacks
    if source.match?(/(youtube|yt)/) || ref.match?(/(youtube\.com|youtu\.be)/)
      return YOUTUBE
    end

    if source == "email" || source == "newsletter" || medium.match?(/(email|newsletter)/)
      return EMAIL
    end

    if ref.include?("instagram.com")
      return INSTAGRAM_ADS
    elsif ref.include?("facebook.com") || ref.include?("fb.com")
      return FACEBOOK_ADS
    end

    # 5. Direct (Priority #5: No referrer, no UTMs)
    if source.blank? && ref.blank?
      return DIRECT
    end

    # 6. Referral Website (Priority #6: Other external referrer)
    if ref.present?
      return REFERRAL_WEBSITE
    end

    OTHER
  end

  # Geolocate an IP address using ip-api.com
  def self.geolocate_ip(ip)
    return { country: "India", state: "Karnataka", city: "Bengaluru" } if local_ip?(ip)

    begin
      url = URI("http://ip-api.com/json/#{ip}")
      response = Net::HTTP.get(url)
      data = JSON.parse(response)
      if data["status"] == "success"
        {
          country: data["country"].presence || "India",
          state: data["regionName"].presence || "Karnataka",
          city: data["city"].presence || "Bengaluru"
        }
      else
        { country: "India", state: "Karnataka", city: "Bengaluru" }
      end
    rescue => e
      Rails.logger.error "IP Geolocation failed for #{ip}: #{e.message}"
      { country: "India", state: "Karnataka", city: "Bengaluru" }
    end
  end

  # Parse User-Agent into device type, browser, and operating system
  def self.parse_user_agent(ua_string)
    ua = ua_string.to_s.downcase

    # Device type
    device = if ua.match?(/(ipad|tablet|playbook|silk)/)
               "Tablet"
             elsif ua.match?(/(mobile|android|iphone|ipod|iemobile|blackberry)/)
               "Mobile"
             else
               "Desktop"
             end

    # Browser
    browser = if ua.match?(/(edge|edg)\//)
                "Edge"
              elsif ua.match?(/(opr|opera)\//)
                "Opera"
              elsif ua.match?(/(chrome|crios)\//)
                "Chrome"
              elsif ua.match?(/firefox|fxios/)
                "Firefox"
              elsif ua.match?(/safari/) && !ua.match?(/chrome/)
                "Safari"
              elsif ua.match?(/msie|trident/)
                "IE"
              else
                "Other"
              end

    # OS
    os = if ua.match?(/iphone|ipad|ipod/)
           "iOS"
         elsif ua.match?(/android/)
           "Android"
         elsif ua.match?(/windows/)
           "Windows"
         elsif ua.match?(/macintosh|mac os x/)
           "macOS"
         elsif ua.match?(/linux/)
           "Linux"
         else
           "Other"
         end

    { device_type: device, browser: browser, operating_system: os }
  end

  def gclid
    landing_page.to_s.match(/gclid=([^&]+)/)&.captures&.first
  end

  def associate_with_order(order)
    return if order.nil?
    order.update_columns(
      booking_source: booking_source || "Other",
      utm_source: utm_source,
      utm_medium: utm_medium,
      utm_campaign: utm_campaign,
      utm_term: utm_term,
      utm_content: utm_content,
      referrer: referrer,
      landing_page: landing_page,
      first_visit_at: created_at,
      device_type: device_type,
      browser: browser,
      operating_system: operating_system,
      ip_address: ip_address,
      attribution_country: country,
      attribution_state: state,
      attribution_city: city
    )
  end

  private

  def self.local_ip?(ip)
    ip.blank? || ip == "127.0.0.1" || ip == "::1" || ip.start_with?("192.168.", "10.", "172.16.")
  end
end

