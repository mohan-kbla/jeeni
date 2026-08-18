product = Spree::Product.find_by(slug: "jeeni-sugar-amla-1kg-jeeni-sku4")
if product
  puts "Product: #{product.name}"
  master_variant = product.master
  puts "Master Variant ID: #{master_variant.id}"
  stock_items = master_variant.stock_items
  puts "Stock Items count: #{stock_items.count}"
  stock_items.each do |si|
    puts "Stock Location: #{si.stock_location.name}"
    puts "  Count on Hand: #{si.count_on_hand}"
    puts "  Backorderable?: #{si.backorderable}"
    puts "  Can supply?: #{si.variant.can_supply?}"
  end
else
  puts "Product not found!"
end
