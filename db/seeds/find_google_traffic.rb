# db/seeds/find_google_traffic.rb
puts "=================================================="
puts "SEARCHING ALL ORDERS SINCE SEPT 1ST FOR GOOGLE SIGNALS:"
puts "=================================================="

orders = Spree::Order.complete.where('completed_at >= ?', 4.days.ago)
orders.each do |o|
  landing = o.landing_page.to_s.downcase
  ref = o.referrer.to_s.downcase
  source = o.utm_source.to_s.downcase
  medium = o.utm_medium.to_s.downcase
  
  if landing.include?('gclid') || landing.include?('gad_source') || landing.include?('srsltid') || landing.include?('gbraid') || landing.include?('wbraid') || source.include?('google') || medium.include?('cpc') || ref.include?('tagassistant')
    puts "MATCHED ORDER: #{o.number} | Date: #{o.completed_at} | Source: #{o.booking_source}"
    puts "  Landing: #{o.landing_page}"
    puts "  Referrer: #{o.referrer}"
    puts "  UTMs: source=#{o.utm_source}, medium=#{o.utm_medium}, campaign=#{o.utm_campaign}"
  end
end

puts "\n=================================================="
puts "SEARCHING ALL VISITOR ATTRIBUTIONS SINCE SEPT 1ST FOR GOOGLE SIGNALS:"
puts "=================================================="
attrs = VisitorAttribution.where('created_at >= ?', 4.days.ago)
attrs.each do |a|
  landing = a.landing_page.to_s.downcase
  ref = a.referrer.to_s.downcase
  source = a.utm_source.to_s.downcase
  medium = a.utm_medium.to_s.downcase

  if landing.include?('gclid') || landing.include?('gad_source') || landing.include?('srsltid') || landing.include?('gbraid') || landing.include?('wbraid') || source.include?('google') || medium.include?('cpc') || ref.include?('tagassistant')
    puts "MATCHED VISITOR: #{a.visitor_id} | Date: #{a.created_at} | Source: #{a.booking_source}"
    puts "  Landing: #{a.landing_page}"
    puts "  Referrer: #{a.referrer}"
    puts "  UTMs: source=#{a.utm_source}, medium=#{a.utm_medium}, campaign=#{a.utm_campaign}"
  end
end
