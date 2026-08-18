require "test_helper"

class FacebookFeedControllerTest < ActionDispatch::IntegrationTest
  setup do
    store = Spree::Store.find_or_create_by!(
      code: "spree",
      name: "Default Store",
      url: "localhost:3000",
      mail_from_address: "store@example.com",
      default_currency: "INR"
    )
    shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")
    @product = Spree::Product.create!(
      name: "Jeeni Millet Test Mix",
      price: 150.0,
      shipping_category: shipping_category,
      active: true,
      stores: [store]
    )
    # Ensure master variant has a SKU
    @product.master.update!(sku: "TEST-SKU-123")
  end

  test "should get facebook feed xml" do
    get "/facebook_feed.xml"
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
    
    # Assert XML content presence
    assert_match "<rss version=\"2.0\"", response.body
    assert_match "<channel>", response.body
    assert_match "<title>Jeeni Millet Mix Catalog</title>", response.body
    assert_match "<g:brand>JEENI</g:brand>", response.body
    assert_match "<g:id>TEST-SKU-123</g:id>", response.body
  end

  test "should route /facebook_feed without extension" do
    get "/facebook_feed"
    assert_response :success
    assert_equal "application/xml; charset=utf-8", response.content_type
  end
end
