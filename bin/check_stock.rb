product = Spree::Product.find_by(slug: "jeeni-sugar-amla-1kg-jeeni-sku4")
if product
  puts "Product: #{product.name}"
  puts "Master can_supply?: #{product.master.can_supply?}"
  puts "Master total_on_hand: #{product.master.total_on_hand}"
  puts "Variants count: #{product.variants.count}"
  product.variants.each do |v|
    puts "Variant ID: #{v.id}, options: #{v.options_text}, can_supply?: #{v.can_supply?}, total_on_hand: #{v.total_on_hand}"
  end
else
  puts "Product not found!"
end
