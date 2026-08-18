p = Spree::Product.create!(
  name: "Multiple Images Test",
  sku: "MULTIPLE-TEST-#{SecureRandom.hex(3)}",
  price: 50.0,
  shipping_category: Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default"),
  stores: [Spree::Store.first || Spree::Store.create!(name: "Jeeni Store", code: "jeeni", url: "localhost", mail_from_address: "store@example.com")],
  product_gallery_attributes: {
    new_images: [
      Rack::Test::UploadedFile.new(Rails.root.join('public/favicon.ico'), 'image/png'),
      Rack::Test::UploadedFile.new(Rails.root.join('public/favicon.ico'), 'image/png')
    ]
  }
)
puts "=== RUNNER TEST RESULT ==="
puts "Product: #{p.name}"
puts "Gallery images count: #{p.product_gallery.gallery_images.count}"
p.destroy
