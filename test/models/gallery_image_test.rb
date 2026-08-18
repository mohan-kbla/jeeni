require "test_helper"

class GalleryImageTest < ActiveSupport::TestCase
  setup do
    shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default")
    store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    product = Spree::Product.first || Spree::Product.create!(
      name: "Test",
      price: 10,
      sku: "TEST-1",
      shipping_category: shipping_category,
      stores: [store]
    )
    @gallery = ProductGallery.create!(product: product)
  end

  test "should be invalid without a file" do
    gi = GalleryImage.new(product_gallery: @gallery)
    assert_not gi.valid?
    assert_includes gi.errors[:file], "can't be blank"
  end

  test "should be invalid with non-image file type" do
    gi = GalleryImage.new(product_gallery: @gallery)
    gi.file.attach(io: StringIO.new("test"), filename: "test.txt", content_type: "text/plain")
    assert_not gi.valid?
    assert_includes gi.errors[:file], "must be a JPEG, PNG, GIF, or WEBP image"
  end

  test "should be valid with correct image format" do
    gi = GalleryImage.new(product_gallery: @gallery)
    gi.file.attach(io: StringIO.new("fake-image-data"), filename: "test.png", content_type: "image/png")
    assert gi.valid?
  end

  test "should be invalid with image file over size limit" do
    gi = GalleryImage.new(product_gallery: @gallery)
    # mock size to be 11MB
    gi.file.attach(io: StringIO.new("fake-image-data"), filename: "test.png", content_type: "image/png")
    def (gi.file.blob).byte_size
      11.megabytes
    end
    assert_not gi.valid?
    assert_includes gi.errors[:file], "size must be less than 10MB"
  end
end
