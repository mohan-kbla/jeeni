class VisitorAttribution < ApplicationRecord
  validates :visitor_id, presence: true, uniqueness: true

  # Classify traffic source based on UTMs and Referrer
  def self.classify(utm_source, utm_medium, utm_campaign, referrer, landing_page_url = nil)
    source = utm_source.to_s.downcase.strip
    medium = utm_medium.to_s.downcase.strip
    campaign = utm_campaign.to_s.downcase.strip
    ref = referrer.to_s.downcase.strip
    url = landing_page_url.to_s.downcase.strip

    # Check for Facebook Click Identifier (fbclid) in the landing page URL
    is_fb_click = url.include?("fbclid=")

    # 1. Google Ads
    if source == "google" && (medium.match?(/(cpc|ppc|paid|ad)/) || campaign.present?)
      return "Google Ads"
    elsif source.match?(/(google_ads|gads|google-ads)/)
      return "Google Ads"
    end

    # 2. Facebook Ads (prioritize Instagram if referrer/source matches, otherwise classify as Facebook Ads)
    if is_fb_click
      if ref.include?("instagram") || source.match?(/(instagram|ig)/)
        return "Instagram Ads"
      else
        return "Facebook Ads"
      end
    end

    if source.match?(/(facebook|fb)/) && (medium.match?(/(cpc|cpm|ad|paid)/) || campaign.present?)
      return "Facebook Ads"
    elsif source.match?(/(facebook_ads|fb_ads|facebook-ads)/)
      return "Facebook Ads"
    end

    # 3. Instagram Ads
    if source.match?(/(instagram|ig)/) && (medium.match?(/(cpc|cpm|ad|paid)/) || campaign.present?)
      return "Instagram Ads"
    elsif source.match?(/(instagram_ads|ig_ads|instagram-ads)/)
      return "Instagram Ads"
    end

    # 4. WhatsApp
    if source.match?(/(whatsapp|wa)/) || ref.match?(/(wa\.me|whatsapp\.com)/)
      return "WhatsApp"
    end

    # 5. YouTube
    if source.match?(/(youtube|yt)/) || ref.match?(/(youtube\.com|youtu\.be)/)
      return "YouTube"
    end

    # 6. Email
    if source == "email" || source == "newsletter" || medium.match?(/(email|newsletter)/)
      return "Email"
    end

    # 7. Organic Google Search
    if ref.match?(/(google\.com|google\.co\.in)/) && !medium.match?(/(cpc|ppc|paid|ad)/)
      return "Organic Google Search"
    end

    # Organic / Referral Social media fallbacks (if no campaign parameters are present but they come from social)
    if ref.include?("instagram.com")
      return "Instagram Ads"
    elsif ref.include?("facebook.com") || ref.include?("fb.com")
      return "Facebook Ads"
    end

    # 8. Direct
    if source.blank? && ref.blank?
      return "Direct"
    end

    # 9. Referral Website
    if ref.present?
      return "Referral Website"
    end

    "Other"
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

  private

  def self.local_ip?(ip)
    ip.blank? || ip == "127.0.0.1" || ip == "::1" || ip.start_with?("192.168.", "10.", "172.16.")
  end
end
