require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class AdminCustom::BookingSourcesGoogleAdsTest < ActionDispatch::IntegrationTest
  setup do
    @admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @admin_user = Spree::User.find_or_initialize_by(email: "admin_ads_test@example.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
    end
    @admin_user.spree_roles << @admin_role unless @admin_user.spree_roles.include?(@admin_role)
    @admin_user.save!(validate: false)

    @store = Spree::Store.first || Spree::Store.create!(
      name: "Default Store",
      code: "spree",
      mail_from_address: "store@example.com",
      url: "example.com",
      default_currency: "INR"
    )

    @headers = {
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }
  end

  test "1. gclid parameter classifies visitor as Google Ads" do
    get root_path, params: { gclid: "TEST_GCLID_12345" }, headers: @headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::GOOGLE_ADS, attr_record.booking_source
    assert_equal "TEST_GCLID_12345", attr_record.gclid
  end

  test "2. Organic google referrer without gclid classifies visitor as Organic Google Search" do
    headers = @headers.merge("HTTP_REFERER" => "https://www.google.com/search?q=jeeni+millet")
    get root_path, headers: headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::ORGANIC_GOOGLE_SEARCH, attr_record.booking_source
  end

  test "3. utm_source=google & utm_medium=cpc classifies visitor as Google Ads" do
    get root_path, params: { utm_source: "google", utm_medium: "cpc", utm_campaign: "summer_sale" }, headers: @headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::GOOGLE_ADS, attr_record.booking_source
    assert_equal "google", attr_record.utm_source
    assert_equal "cpc", attr_record.utm_medium
    assert_equal "summer_sale", attr_record.utm_campaign
  end

  test "4. utm_source=google & utm_medium=organic classifies visitor as Organic Google Search" do
    get root_path, params: { utm_source: "google", utm_medium: "organic" }, headers: @headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::ORGANIC_GOOGLE_SEARCH, attr_record.booking_source
  end

  test "5. Direct visitor without params or referrer classifies as Meta Ads" do
    get root_path, headers: @headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::DIRECT, attr_record.booking_source
    assert_equal "Meta Ads", attr_record.booking_source
  end

  test "6. WhatsApp visitor classifies as WhatsApp" do
    get root_path, params: { utm_source: "whatsapp" }, headers: @headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::WHATSAPP, attr_record.booking_source
  end

  test "7. External referral website classifies as Referral Website" do
    headers = @headers.merge("HTTP_REFERER" => "https://someotherblog.com/top-health-drinks")
    get root_path, headers: headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_not_nil attr_record
    assert_equal VisitorAttribution::REFERRAL_WEBSITE, attr_record.booking_source
  end

  test "8. Order completed after landing with gclid receives Google Ads attribution" do
    get root_path, params: { gclid: "TEST_GCLID_ORDER_999", utm_source: "google", utm_medium: "cpc" }, headers: @headers
    assert_response :success

    cookie_visitor_id = cookies[:visitor_id]
    assert cookie_visitor_id.present?

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_equal VisitorAttribution::GOOGLE_ADS, attr_record.booking_source

    order = Spree::Order.create!(store: @store, currency: "INR", email: "testbuyer@example.com")
    attr_record.associate_with_order(order)

    assert_equal VisitorAttribution::GOOGLE_ADS, order.booking_source
    assert_equal "TEST_GCLID_ORDER_999", attr_record.gclid
    assert_includes order.landing_page, "TEST_GCLID_ORDER_999"
    assert_equal "google", order.utm_source
  end

  test "9. Google Ads attribution persists across multi-page navigation before checkout" do
    get root_path, params: { gclid: "PERSIST_GCLID_777" }, headers: @headers
    assert_response :success
    cookie_visitor_id = cookies[:visitor_id]

    get products_path, headers: @headers
    assert_response :success
    assert_equal cookie_visitor_id, cookies[:visitor_id]

    attr_record = VisitorAttribution.find_by(visitor_id: cookie_visitor_id)
    assert_equal VisitorAttribution::GOOGLE_ADS, attr_record.booking_source

    get cart_path, headers: @headers
    assert_response :success
    attr_record.reload
    assert_equal VisitorAttribution::GOOGLE_ADS, attr_record.booking_source
  end

  test "10. Admin can view analytics booking_sources page showing Google Ads" do
    Spree::Order.create!(
      store: @store,
      currency: "INR",
      email: "ads_buyer@example.com",
      booking_source: VisitorAttribution::GOOGLE_ADS,
      total: 500.0,
      payment_state: "paid",
      completed_at: Time.current
    )

    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "password123" }
    }

    get admin_custom_analytics_booking_sources_path
    assert_response :success
    assert_includes response.body, "Booking Sources"
    assert_includes response.body, VisitorAttribution::GOOGLE_ADS
  end
end
