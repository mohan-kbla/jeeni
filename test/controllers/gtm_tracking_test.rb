require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class GtmTrackingTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    @shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default")
    @product = Spree::Product.first || Spree::Product.create!(
      name: "Test GTM Product",
      price: 150,
      sku: "TEST-GTM-1",
      shipping_category: @shipping_category,
      stores: [@store]
    )

    @order = Spree::Order.create!(
      store: @store,
      state: "complete",
      completed_at: Time.current,
      total: 150.0,
      payment_total: 150.0,
      currency: "INR"
    )
  end

  test "renders GTM-N28R82Z script in head and noscript iframe in body" do
    get root_path
    assert_response :success

    # Verify GTM script in head
    assert_includes response.body, "https://www.googletagmanager.com/gtm.js?id='+i+dl"
    assert_includes response.body, "'GTM-N28R82Z'"

    # Verify GTM noscript in body
    assert_includes response.body, '<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=GTM-N28R82Z"'
  end

  test "renders exactly ONE GTM container without duplicates" do
    get root_path
    assert_response :success

    # Count occurrences of GTM loader and container ID
    gtm_script_count = response.body.scan(/gtm\.js\?id=/).count
    gtm_id_count = response.body.scan(/GTM-N28R82Z/).count

    assert_equal 1, gtm_script_count, "Expected exactly 1 GTM script tag"
    assert_equal 2, gtm_id_count, "Expected GTM-N28R82Z in script and noscript"
  end

  test "preserves existing Google Tag GT-55KXGQZ and Meta Pixel tracking" do
    get root_path
    assert_response :success

    # Verify Google Tag (gtag.js) GT-55KXGQZ is preserved
    assert_includes response.body, 'https://www.googletagmanager.com/gtag/js?id=GT-55KXGQZ'
    assert_includes response.body, "gtag('config', 'GT-55KXGQZ')"

    # Verify Meta Pixel is preserved
    assert_includes response.body, 'https://connect.facebook.net/en_US/fbevents.js'
    assert_includes response.body, "fbq('init', '1355071780050188')"
  end
end
