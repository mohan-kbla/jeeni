require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class OrdersControllerTrackingTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    @shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default")
    
    @product = Spree::Product.first || Spree::Product.create!(
      name: "Jeeni Test Tracking Product",
      price: 150.00,
      sku: "JEENI-TRACK-1",
      status: "active",
      available_on: 1.day.ago,
      shipping_category: @shipping_category,
      stores: [@store]
    )

    @user = Spree::User.find_or_initialize_by(email: "tracking_user_test@example.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
    end
    @user.save!(validate: false)

    @order = Spree::Order.create!(
      user: @user,
      store: @store,
      state: "complete",
      completed_at: Time.current,
      total: 150.00,
      payment_total: 150.00,
      currency: "INR"
    )
    
    @line_item = Spree::LineItem.new(
      order: @order,
      variant: @product.master,
      price: 150.00,
      quantity: 1
    )
    @line_item.save!(validate: false)

    # Set default Google Tag ID in CroSetting
    CroSetting.set('google_tag_id', 'GT-55KXGQZ')
  end

  test "global google tag ID GT-55KXGQZ is present on home page layout" do
    get "/"
    assert_response :success
    assert_includes response.body, "gtag/js?id=GT-55KXGQZ"
    assert_includes response.body, "gtag('config', 'GT-55KXGQZ');"
  end

  test "orders show tracks purchase conversion on initial completed order load" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @user.email, password: "password123" }
    }

    get order_details_path(id: @order.number)
    assert_response :success
    assert_includes response.body, "gtag('event', 'purchase'"
    assert_includes response.body, @order.number
  end

  test "orders show prevents duplicate purchase event on page refresh or subsequent loads" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @user.email, password: "password123" }
    }

    # First load - fires event
    get order_details_path(id: @order.number)
    assert_response :success
    assert_includes response.body, "gtag('event', 'purchase'"

    # Reload order from DB to check public_metadata persistence
    @order.reload
    assert_equal true, @order.public_metadata['purchase_tracked']

    # Second load - must NOT fire purchase event
    get order_details_path(id: @order.number)
    assert_response :success
    refute_includes response.body, "gtag('event', 'purchase'"
  end

  test "orders show includes send_to when conversion ID and label are configured" do
    CroSetting.set('google_ads_conversion_id', 'AW-999888777')
    CroSetting.set('google_ads_conversion_label', 'LABEL_ABC123')

    post spree_create_new_session_path, params: {
      spree_user: { email: @user.email, password: "password123" }
    }

    get order_details_path(id: @order.number)
    assert_response :success
    assert_includes response.body, "googlePurchasePayload.send_to = 'AW-999888777/LABEL_ABC123';"
  end
end
