india = Spree::Country.find_or_create_by!(iso: "IN") do |c|
  c.iso_name = "INDIA"
  c.iso3 = "IND"
  c.name = "India"
  c.numcode = 356
end

states = [
  { name: "Andhra Pradesh", abbr: "AP" },
  { name: "Arunachal Pradesh", abbr: "AR" },
  { name: "Assam", abbr: "AS" },
  { name: "Bihar", abbr: "BR" },
  { name: "Chhattisgarh", abbr: "CT" },
  { name: "Goa", abbr: "GA" },
  { name: "Gujarat", abbr: "GJ" },
  { name: "Haryana", abbr: "HR" },
  { name: "Himachal Pradesh", abbr: "HP" },
  { name: "Jharkhand", abbr: "JH" },
  { name: "Karnataka", abbr: "KA" },
  { name: "Kerala", abbr: "KL" },
  { name: "Madhya Pradesh", abbr: "MP" },
  { name: "Maharashtra", abbr: "MH" },
  { name: "Manipur", abbr: "MN" },
  { name: "Meghalaya", abbr: "ML" },
  { name: "Mizoram", abbr: "MZ" },
  { name: "Nagaland", abbr: "NL" },
  { name: "Odisha", abbr: "OR" },
  { name: "Punjab", abbr: "PB" },
  { name: "Rajasthan", abbr: "RJ" },
  { name: "Sikkim", abbr: "SK" },
  { name: "Tamil Nadu", abbr: "TN" },
  { name: "Telangana", abbr: "TG" },
  { name: "Tripura", abbr: "TR" },
  { name: "Uttar Pradesh", abbr: "UP" },
  { name: "Uttarakhand", abbr: "UT" },
  { name: "West Bengal", abbr: "WB" },
  { name: "Andaman and Nicobar Islands", abbr: "AN" },
  { name: "Chandigarh", abbr: "CH" },
  { name: "Dadra and Nagar Haveli and Daman and Diu", abbr: "DN" },
  { name: "Lakshadweep", abbr: "LD" },
  { name: "Delhi", abbr: "DL" },
  { name: "Puducherry", abbr: "PY" },
  { name: "Jammu and Kashmir", abbr: "JK" },
  { name: "Ladakh", abbr: "LA" }
]

states.each do |state_data|
  Spree::State.find_or_create_by!(name: state_data[:name], country: india) do |s|
    s.abbr = state_data[:abbr]
  end
end

Spree::Config[:default_country_id] = india.id
puts "India states populated and default country set."

us = Spree::Country.find_by(iso: "US")
if us
  us.states.destroy_all
  us.destroy
  puts "US data deleted."
end

# Update stock locations default to India
Spree::StockLocation.update_all(country_id: india.id, state_name: "Karnataka", city: "Bangalore")
puts "Stock locations updated."

# Ensure Promotional Products exist with exact slugs
store = Spree::Store.default || Spree::Store.first
shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")
stock_location = Spree::StockLocation.first_or_create!(name: "Default Location")

promotional_products = [
  { name: "Jeeni Vegetable Cofpee", slug: "vegetable-cofpee", sku: "VEG-COFFEE-GIFT", price: 279.00 },
  { name: "Jeeni Sugaramla 1KG", slug: "jeeni-sugaramla-1kg-sugaramla-1kg", sku: "SUGARAMLA-1KG", price: 499.00 }
]

promotional_products.each do |p_info|
  variant = Spree::Variant.find_by(sku: p_info[:sku])
  prod = Spree::Product.find_by(slug: p_info[:slug]) || variant&.product || Spree::Product.new
  prod.name = p_info[:name]
  prod.slug = p_info[:slug]
  prod.price = p_info[:price]
  prod.shipping_category = shipping_category
  prod.available_on = Time.current
  prod.status = 'active' if prod.respond_to?(:status=)
  prod.stores << store unless prod.stores.include?(store)
  prod.save!

  if prod.master
    prod.master.update_column(:sku, p_info[:sku])
  end

  stock_item = Spree::StockItem.find_or_create_by!(stock_location: stock_location, variant: prod.master)
  stock_item.set_count_on_hand(100)
end
puts "Promotional products seeded successfully."

