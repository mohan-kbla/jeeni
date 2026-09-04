# db/seeds/find_and_reclassify_google_orders.rb
puts "=================================================="
puts "RE-EVALUATING ORDERS FOR GOOGLE ADS SIGNALS:"
puts "=================================================="

orders = Spree::Order.complete
reclassified_count = 0

orders.each do |o|
  url = o.landing_page.to_s.downcase.strip
  ref = o.referrer.to_s.downcase.strip
  source = o.utm_source.to_s.downcase.strip
  medium = o.utm_medium.to_s.downcase.strip
  campaign = o.utm_campaign.to_s.downcase.strip

  is_google_ads_signal = url.include?("gclid=") || ref.include?("gclid=") ||
                         url.include?("gad_source=") || ref.include?("gad_source=") ||
                         url.include?("gbraid=") || ref.include?("gbraid=") ||
                         url.include?("wbraid=") || ref.include?("wbraid=") ||
                         url.include?("srsltid=") || ref.include?("srsltid=") ||
                         url.include?("gtm_debug=") || ref.include?("tagassistant.google.com")

  if is_google_ads_signal
    old_source = o.booking_source
    o.update_columns(booking_source: VisitorAttribution::GOOGLE_ADS)
    reclassified_count += 1
    puts "Reclassified Order ##{o.number} (Completed: #{o.completed_at}) from '#{old_source}' -> 'Google Ads'"
    puts "  Landing: #{o.landing_page}"
    puts "  Referrer: #{o.referrer}"
  end
end

puts "=================================================="
puts "TOTAL ORDERS RECLASSIFIED TO GOOGLE ADS: #{reclassified_count}"
puts "=================================================="
