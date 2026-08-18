# db/seeds_booking_sources.rb
puts "--- Seeding Booking Sources & Attribution Data ---"

# Ensure we have active records to associate
orders = Spree::Order.complete
if orders.empty?
  puts "Warning: No completed orders found. Please ensure you have complete orders before seeding attributions."
end

# 1. Clean existing VisitorAttributions
puts "Cleaning existing visitor attributions..."
VisitorAttribution.delete_all

# Pre-defined attributes for realistic distribution
sources_info = [
  { source: "Facebook Ads", utm_source: "facebook", utm_medium: "cpc", utm_campaign: "summer_sale_2026", referrer: "https://l.instagram.com/", weight: 25 },
  { source: "Instagram Ads", utm_source: "instagram", utm_medium: "cpc", utm_campaign: "millets_launch", referrer: "https://l.instagram.com/", weight: 20 },
  { source: "Google Ads", utm_source: "google", utm_medium: "cpc", utm_campaign: "brand_awareness", referrer: "https://www.google.com/", weight: 15 },
  { source: "Organic Google Search", utm_source: nil, utm_medium: nil, utm_campaign: nil, referrer: "https://www.google.co.in/", weight: 15 },
  { source: "Direct", utm_source: nil, utm_medium: nil, utm_campaign: nil, referrer: nil, weight: 10 },
  { source: "WhatsApp", utm_source: "whatsapp", utm_medium: "social", utm_campaign: "group_share", referrer: "https://wa.me/", weight: 5 },
  { source: "YouTube", utm_source: "youtube", utm_medium: "referral", utm_campaign: "video_review", referrer: "https://youtube.com/watch?v=123", weight: 4 },
  { source: "Email", utm_source: "newsletter", utm_medium: "email", utm_campaign: "monthly_newsletter", referrer: nil, weight: 3 },
  { source: "Referral Website", utm_source: "partner_blog", utm_medium: "referral", utm_campaign: nil, referrer: "https://healthymilletsblog.com/top-10-millets", weight: 3 }
]

devices = [
  { type: "Mobile", browser: "Chrome", os: "Android", weight: 40 },
  { type: "Mobile", browser: "Safari", os: "iOS", weight: 25 },
  { type: "Desktop", browser: "Chrome", os: "Windows", weight: 20 },
  { type: "Desktop", browser: "Safari", os: "macOS", weight: 8 },
  { type: "Desktop", browser: "Firefox", os: "Linux", weight: 4 },
  { type: "Tablet", browser: "Chrome", os: "Android", weight: 3 }
]

locations = [
  { country: "India", state: "Karnataka", city: "Bengaluru", weight: 45 },
  { country: "India", state: "Maharashtra", city: "Mumbai", weight: 15 },
  { country: "India", state: "Tamil Nadu", city: "Chennai", weight: 12 },
  { country: "India", state: "Delhi", city: "New Delhi", weight: 10 },
  { country: "India", state: "Telangana", city: "Hyderabad", weight: 8 },
  { country: "India", state: "Karnataka", city: "Mysuru", weight: 6 },
  { country: "India", state: "Maharashtra", city: "Pune", weight: 4 }
]

landing_pages = [
  "http://localhost:3000/",
  "http://localhost:3000/products",
  "http://localhost:3000/products/jeeni-millet-mix-1kg",
  "http://localhost:3000/products/sugaramla-500g",
  "http://localhost:3000/about",
  "http://localhost:3000/blogs"
]

# Helper to sample based on weights
def sample_weighted(list)
  total_weight = list.sum { |item| item[:weight] }
  target = rand(total_weight)
  current = 0
  list.each do |item|
    current += item[:weight]
    return item if target < current
  end
  list.first
end

# 2. Seed 400 mock VisitorAttributions over the last 30 days to build analytics charts
puts "Creating 400 visitor attribution records..."
visitors_count = 400
visitors_count.times do |i|
  source_item = sample_weighted(sources_info)
  device_item = sample_weighted(devices)
  loc_item = sample_weighted(locations)
  
  created_at = rand(0..29).days.ago - rand(0..23).hours - rand(0..59).minutes
  
  # Set a custom UTM Campaign variation occasionally
  campaign = source_item[:utm_campaign]
  if campaign.present? && rand < 0.3
    campaign = "#{campaign}_promo_#{['v1', 'v2', 'spring'].sample}"
  end

  VisitorAttribution.create!(
    visitor_id: SecureRandom.uuid,
    booking_source: source_item[:source],
    utm_source: source_item[:utm_source],
    utm_medium: source_item[:utm_medium],
    utm_campaign: campaign,
    utm_term: campaign.present? ? ["millets", "jeeni", "diet", "healthy"].sample : nil,
    utm_content: campaign.present? ? ["banner_ad", "sidebar_ad", "text_link"].sample : nil,
    referrer: source_item[:referrer],
    landing_page: landing_pages.sample,
    current_url: landing_pages.sample,
    device_type: device_item[:type],
    browser: device_item[:browser],
    operating_system: device_item[:os],
    ip_address: "103.#{rand(10..254)}.#{rand(0..254)}.#{rand(1..254)}",
    country: loc_item[:country],
    state: loc_item[:state],
    city: loc_item[:city],
    created_at: created_at,
    updated_at: created_at
  )
end
puts "Seeded #{VisitorAttribution.count} Visitor Attribution records."

# 3. Retroactively attribute existing completed orders
puts "Updating existing completed orders with attribution data..."
orders.each_with_index do |order, idx|
  # Sample a random VisitorAttribution from our created records
  # Or generate a new one specifically matching this order time
  created_at = order.completed_at || Time.current
  first_visit_at = created_at - rand(1..240).minutes # Visited before purchase
  
  source_item = sample_weighted(sources_info)
  device_item = sample_weighted(devices)
  loc_item = sample_weighted(locations)
  campaign = source_item[:utm_campaign]
  
  order.update_columns(
    booking_source: source_item[:source],
    utm_source: source_item[:utm_source],
    utm_medium: source_item[:utm_medium],
    utm_campaign: campaign,
    utm_term: campaign.present? ? ["millets", "jeeni", "diet", "healthy"].sample : nil,
    utm_content: campaign.present? ? ["banner_ad", "sidebar_ad", "text_link"].sample : nil,
    referrer: source_item[:referrer],
    landing_page: landing_pages.sample,
    first_visit_at: first_visit_at,
    device_type: device_item[:type],
    browser: device_item[:browser],
    operating_system: device_item[:os],
    ip_address: "103.#{rand(10..254)}.#{rand(0..254)}.#{rand(1..254)}",
    attribution_country: loc_item[:country],
    attribution_state: loc_item[:state],
    attribution_city: loc_item[:city]
  )
  
  # Also create a corresponding VisitorAttribution record matching this order so conversion rates align!
  VisitorAttribution.create!(
    visitor_id: SecureRandom.uuid,
    booking_source: source_item[:source],
    utm_source: source_item[:utm_source],
    utm_medium: source_item[:utm_medium],
    utm_campaign: campaign,
    utm_term: campaign.present? ? ["millets", "jeeni", "diet", "healthy"].sample : nil,
    utm_content: campaign.present? ? ["banner_ad", "sidebar_ad", "text_link"].sample : nil,
    referrer: source_item[:referrer],
    landing_page: order.landing_page,
    current_url: order.landing_page,
    device_type: device_item[:type],
    browser: device_item[:browser],
    operating_system: device_item[:os],
    ip_address: order.ip_address,
    country: loc_item[:country],
    state: loc_item[:state],
    city: loc_item[:city],
    created_at: first_visit_at,
    updated_at: first_visit_at
  )
end

puts "Successfully attributed #{orders.count} orders."
puts "Total Visitors: #{VisitorAttribution.count}"
puts "Total Bookings: #{Spree::Order.complete.count}"
puts "Seeding completed successfully!"
