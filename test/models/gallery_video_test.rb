require "test_helper"

class GalleryVideoTest < ActiveSupport::TestCase
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

  test "should be invalid without file and without external url" do
    gv = GalleryVideo.new(product_gallery: @gallery)
    assert_not gv.valid?
    assert_includes gv.errors[:base], "Must have an uploaded video or an external URL"
  end

  test "should be valid with external url only" do
    gv = GalleryVideo.new(product_gallery: @gallery, external_url: "https://youtube.com/watch?v=123")
    assert gv.valid?
  end

  test "should be invalid with non-video file type" do
    gv = GalleryVideo.new(product_gallery: @gallery)
    gv.file.attach(io: StringIO.new("test"), filename: "test.txt", content_type: "text/plain")
    assert_not gv.valid?
    assert_includes gv.errors[:file], "must be a valid video file"
  end

  test "should be valid with correct video format" do
    gv = GalleryVideo.new(product_gallery: @gallery)
    gv.file.attach(io: StringIO.new("fake-video-data"), filename: "test.mp4", content_type: "video/mp4")
    assert gv.valid?
  end

  test "should be invalid with video file over size limit" do
    gv = GalleryVideo.new(product_gallery: @gallery)
    # mock size to be 501MB
    gv.file.attach(io: StringIO.new("fake-video-data"), filename: "test.mp4", content_type: "video/mp4")
    def (gv.file.blob).byte_size
      501.megabytes
    end
    assert_not gv.valid?
    assert_includes gv.errors[:file], "size must be less than 500MB"
  end
end
