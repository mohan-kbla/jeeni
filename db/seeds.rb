# db/seeds.rb

puts "--- Seeding Database ---"

# 1. Setup Spree Roles and Users
puts "Setting up Spree Roles and Users..."
admin_role = Spree::Role.find_or_create_by!(name: "admin")
user_role  = Spree::Role.find_or_create_by!(name: "user")

# Create Admin User
admin_user = Spree::User.find_or_initialize_by(email: "admin@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end
admin_user.spree_roles << admin_role unless admin_user.spree_roles.include?(admin_role)
admin_user.save!(validate: false)
puts "Admin User created: admin@example.com / password"

# Create Customer User
customer_user = Spree::User.find_or_initialize_by(email: "customer@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end
customer_user.spree_roles << user_role unless customer_user.spree_roles.include?(user_role)
customer_user.save!(validate: false)
puts "Customer User created: customer@example.com / password"

# Create Read-Only Staff User for Orders
read_only_role = Spree::Role.find_or_create_by!(name: "read_only_orders")
staff_user = Spree::User.find_or_initialize_by(email: "accounts@jeenimilletmix.in") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end
staff_user.first_name = "Accounts" if staff_user.respond_to?(:first_name=)
staff_user.last_name = "Staff" if staff_user.respond_to?(:last_name=)
staff_user.spree_roles << read_only_role unless staff_user.spree_roles.include?(read_only_role)
staff_user.save!(validate: false)
puts "Read-Only Staff User created: accounts@jeenimilletmix.in / password"



# 2. Setup Logistics Foundations (Required for Checkout Flow)
puts "Setting up Store, Stock Location, Shipping, Zones, and Payments..."

# Default Store
store = Spree::Store.find_or_initialize_by(code: "spree")
store.name = "Jeeni Shop"
store.url = "localhost:3000"
store.mail_from_address = "store@example.com"
store.default_currency = "INR"
store.default = true
store.default_country = Spree::Country.default || Spree::Country.first
store.save!
puts "Default Store created: Jeeni Shop"

# Stock Location
stock_location = Spree::StockLocation.find_or_create_by!(name: "Main Warehouse") do |loc|
  loc.active = true
  loc.country = Spree::Country.default || Spree::Country.first || Spree::Country.create!(name: "India", iso_name: "INDIA", iso: "IN", iso3: "IND", numcode: 356)
  loc.city = "Bangalore"
  loc.state_name = "Karnataka"
end

# Shipping Category
shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")

# Zone (Global Zone containing all countries)
global_zone = Spree::Zone.find_or_create_by!(name: "Global Zone") do |z|
  z.description = "All countries zone"
end
if global_zone.zone_members.empty?
  global_zone.zone_members.create!(zoneable: Spree::Country.default || Spree::Country.first)
end

# Shipping Method (Flat rate)
shipping_method = Spree::ShippingMethod.find_or_initialize_by(name: "Standard Shipping")
shipping_method.code = "STD-SHIP"
shipping_method.display_on = "both"
shipping_method.shipping_categories << shipping_category unless shipping_method.shipping_categories.include?(shipping_category)
shipping_method.zones << global_zone unless shipping_method.zones.include?(global_zone)
shipping_method.calculator ||= Spree::Calculator::FlatRate.create!(preferred_amount: 0.00, preferred_currency: "INR")
shipping_method.calculator.preferred_amount = 0.00
shipping_method.calculator.save!
shipping_method.save!
puts "Shipping Method configured: Standard Shipping (₹0.00)"

# Payment Method (Check/COD)
payment_method = Spree::PaymentMethod::Check.find_or_initialize_by(name: "Check / Cash on Delivery")
payment_method.description = "Pay by check or cash on delivery"
payment_method.active = true
payment_method.display_on = "both"
payment_method.stores << store unless payment_method.stores.include?(store)
payment_method.save!
puts "Payment Method configured: Check / Cash on Delivery"

# 3. Setup Categories (Taxonomies & Taxons)
puts "Setting up Taxonomies and Categories..."
millets_tax = Spree::Taxonomy.find_or_create_by!(name: "Jeeni Millet Products", store_id: store.id)
# weight_tax = Spree::Taxonomy.find_or_create_by!(name: "Weight Management", store_id: store.id)
# sugar_tax = Spree::Taxonomy.find_or_create_by!(name: "Sugaramla", store_id: store.id)
# confect_tax = Spree::Taxonomy.find_or_create_by!(name: "Confectionery", store_id: store.id)
# oil_tax = Spree::Taxonomy.find_or_create_by!(name: "Oil Products", store_id: store.id)
# baby_tax = Spree::Taxonomy.find_or_create_by!(name: "Nutritious Baby Foods", store_id: store.id)

millets_taxon = millets_tax.root
# weight_taxon = weight_tax.root
# sugar_taxon = sugar_tax.root
# confect_taxon = confect_tax.root
# oil_taxon = oil_tax.root
# baby_taxon = baby_tax.root

# 4. Setup Products and Stock
puts "Creating Products and Variant Stock Items..."

products_data = []

products_data.each do |p_info|
  master_variant = Spree::Variant.find_by(sku: p_info[:sku], is_master: true)
  prod = master_variant ? master_variant.product : Spree::Product.new
  prod.sku = p_info[:sku]
  prod.name = p_info[:name]
  prod.description = p_info[:description]
  prod.price = p_info[:price]
  prod.shipping_category = shipping_category
  prod.available_on = Time.current
  prod.state = p_info[:state]
  prod.district = p_info[:district]
  prod.featured = p_info[:featured]
  prod.category_id = p_info[:taxon].taxonomy_id if p_info[:taxon]
  prod.active = true
  prod.status = 'active'
  
  # Link store & taxon
  prod.stores << store unless prod.stores.include?(store)
  prod.taxons << p_info[:taxon] unless prod.taxons.include?(p_info[:taxon])
  prod.save!
  
  # Ensure stock item exists
  stock_item = Spree::StockItem.find_or_create_by!(stock_location: stock_location, variant: prod.master)
  stock_item.set_count_on_hand(20) # 20 units in stock
end
puts "Products successfully populated."


# 5. Setup Blogs and Comments
puts "Creating Blogs and Comments..."

blogs_data = []

blogs_data.each do |b_info|
  blog = Blog.find_or_initialize_by(title: b_info[:title]) do |b|
    b.body = b_info[:body]
    b.category = b_info[:category]
    b.tag_list = b_info[:tags]
    b.published = b_info[:published]
    b.published_at = b_info[:published_at]
  end
  blog.save!
  
  # Add comments to the first published post
  if blog.published? && blog.category == "Announcements"
    Comment.find_or_create_by!(blog: blog, user: customer_user, body: "Congratulations on the launch! The layout looks absolutely stunning, and the checkout wizard is incredibly fast and responsive.") do |c|
      c.status = "approved"
    end
    Comment.find_or_create_by!(blog: blog, user: customer_user, body: "Will you support international credit card payments soon? Looking forward to placing an order from Europe.") do |c|
      c.status = "pending"
    end
  end
end
puts "Blog posts and comments successfully populated."

# 6. Load India states and set default country
puts "Loading India states..."
load File.expand_path('../db_update_india.rb', __dir__)

# 7. Seed Razorpay Payment Method
# puts "Seeding Razorpay Payment Method..."
# if defined?(Spree::PaymentMethod::Razorpay)
#   store = Spree::Store.default
#   payment_method = Spree::PaymentMethod::Razorpay.find_or_initialize_by(name: "Razorpay")
#   payment_method.description = "Pay securely via Razorpay (UPI, Card, NetBanking)"
#   payment_method.active = true
#   payment_method.display_on = "both"
#   payment_method.preferred_key_id = "rzp_test_dummykeyid"
#   payment_method.preferred_key_secret = "dummysecret"
#   payment_method.preferred_webhook_secret = "dummy_webhook_secret"
#   payment_method.stores << store unless payment_method.stores.include?(store)
#   payment_method.save!
#   puts "SUCCESS: Seeded Razorpay Payment Method"
# else
#   puts "WARNING: Spree::PaymentMethod::Razorpay not defined. Skipping."
# end

# puts "--- Seeding Completed Successfully ---"

