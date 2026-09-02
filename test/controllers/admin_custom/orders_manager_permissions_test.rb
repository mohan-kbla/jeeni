require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class AdminCustom::OrdersManagerPermissionsTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    @shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default")
    @product = Spree::Product.first || Spree::Product.create!(
      name: "Test Prod Permissions",
      price: 100,
      sku: "TEST-PERM-1",
      shipping_category: @shipping_category,
      stores: [@store]
    )

    @orders_manager_role = Spree::Role.find_or_create_by!(name: "orders_manager")
    @navane_user = Spree::User.find_or_initialize_by(email: "navaneshivaraju@gmail.com") do |u|
      u.password = "Password@123"
      u.password_confirmation = "Password@123"
      u.first_name = "Navane"
      u.last_name = "Shivaraju"
    end
    @navane_user.spree_roles << @orders_manager_role unless @navane_user.spree_roles.include?(@orders_manager_role)
    @navane_user.save!(validate: false)

    @order = Spree::Order.create!(
      store: @store,
      state: "complete",
      completed_at: Time.current,
      total: 100.0,
      payment_total: 100.0,
      currency: "INR"
    )
  end

  test "navane user can login and redirect to admin custom orders path" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @navane_user.email, password: "Password@123" }
    }
    assert_redirected_to admin_custom_orders_path
  end

  test "orders manager user can view orders index and order details page" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @navane_user.email, password: "Password@123" }
    }

    get admin_custom_orders_path
    assert_response :success
    assert_select "h1", text: /Orders/

    get admin_custom_order_path(id: @order.number)
    assert_response :success
  end

  test "orders manager user can update order status and information" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @navane_user.email, password: "Password@123" }
    }

    patch update_status_admin_custom_order_path(id: @order.number), params: { state: "canceled" }
    assert_response :success
    @order.reload
    assert_equal "canceled", @order.state
  end

  test "orders manager user is blocked from unauthorized admin pages" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @navane_user.email, password: "Password@123" }
    }

    # Products page -> Forbidden
    get admin_custom_products_path
    assert_response :forbidden
    assert_equal "403 Access Denied: You only have access to the Orders page.", flash[:alert]

    # Users page -> Forbidden
    get admin_custom_users_path
    assert_response :forbidden

    # CRO Settings page -> Forbidden
    get edit_admin_custom_settings_path
    assert_response :forbidden

    # Daily updates page -> Forbidden
    get admin_custom_daily_company_updates_path
    assert_response :forbidden
  end
end
