# db/seeds/check_recent_orders.rb
orders = Spree::Order.complete.where('completed_at >= ?', 3.days.ago).order(completed_at: :desc)
puts "Found #{orders.count} complete orders in last 3 days:"
orders.each do |o|
  puts "Order: #{o.number} | Completed: #{o.completed_at} | Email: #{o.email} | Source: #{o.booking_source} | Landing: #{o.landing_page} | Referrer: #{o.referrer} | UTM Source: #{o.utm_source} | UTM Medium: #{o.utm_medium} | UTM Campaign: #{o.utm_campaign}"
end

puts "\nChecking all visitor attributions in last 3 days:"
attrs = VisitorAttribution.where('created_at >= ?', 3.days.ago).order(created_at: :desc).limit(20)
attrs.each do |a|
  puts "Visitor: #{a.visitor_id} | Created: #{a.created_at} | Source: #{a.booking_source} | Landing: #{a.landing_page} | Referrer: #{a.referrer} | UTM Source: #{a.utm_source} | UTM Medium: #{a.utm_medium} | UTM Campaign: #{a.utm_campaign}"
end
