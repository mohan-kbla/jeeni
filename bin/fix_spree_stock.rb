puts "=== Setting propagate_all_variants to true ==="
Spree::StockLocation.update_all(propagate_all_variants: true)

puts "=== Propagating stock items for all variants ==="
Spree::Variant.all.each do |variant|
  Spree::StockLocation.active.each do |stock_location|
    stock_item = stock_location.stock_item(variant) || stock_location.propagate_variant(variant)
    if stock_item
      # Set stock level to 50 if it was 0
      if stock_item.count_on_hand == 0
        stock_item.set_count_on_hand(50)
        puts "Set count_on_hand of Variant ID #{variant.id} (#{variant.sku}) in #{stock_location.name} to 50"
      end
    end
  end
end
puts "=== Done fixing stock! ==="
