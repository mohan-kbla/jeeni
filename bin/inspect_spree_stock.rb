puts "=== Spree Stock Locations ==="
Spree::StockLocation.all.each do |sl|
  puts "ID: #{sl.id}, Name: #{sl.name}, Active?: #{sl.active}, Propagate?: #{sl.propagate_all_variants}"
end

puts "=== Spree Stock Items Count ==="
puts "Total Stock Items: #{Spree::StockItem.count}"

puts "=== Creating Default Stock Location if None ==="
if Spree::StockLocation.count == 0
  sl = Spree::StockLocation.create!(name: "Default Location", active: true, propagate_all_variants: true)
  puts "Created Stock Location: #{sl.name}"
end

# Make sure all variants have stock items
Spree::Variant.all.each do |variant|
  Spree::StockLocation.active.each do |stock_location|
    unless stock_location.stock_item(variant)
      stock_location.propagate_variant(variant)
      puts "Propagated stock item for Variant ID #{variant.id} (#{variant.sku}) in #{stock_location.name}"
    end
  end
end
