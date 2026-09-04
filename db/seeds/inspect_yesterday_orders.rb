# db/seeds/inspect_yesterday_orders.rb
yesterday_start = 2.days.ago.beginning_of_day
yesterday_end = Time.current.end_of_day

orders = Spree::Order.complete.where(completed_at: yesterday_start..yesterday_end).order(completed_at: :desc)
puts "=========================================="
puts "COMPLETED ORDERS IN LAST 48 HOURS (#{orders.count} total):"
puts "=========================================="

orders.each do |o|
  puts "Order #: #{o.number}"
  puts "  Completed At : #{o.completed_at}"
  puts "  Email        : #{o.email}"
  puts "  Total        : ₹#{o.total}"
  puts "  Source       : #{o.booking_source}"
  puts "  Landing Page : #{o.landing_page}"
  puts "  Referrer     : #{o.referrer}"
  puts "  UTM Source   : #{o.utm_source}"
  puts "  UTM Medium   : #{o.utm_medium}"
  puts "  UTM Campaign : #{o.utm_campaign}"
  puts "  UTM Term     : #{o.utm_term}"
  puts "  UTM Content  : #{o.utm_content}"
  puts "  Public Meta  : #{o.public_metadata}"
  puts "------------------------------------------"
end
