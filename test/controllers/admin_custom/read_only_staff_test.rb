require 'test_helper'

class AdminCustom::ReadOnlyStaffTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(
      name: "Jeeni Store",
      code: "spree",
      url: "localhost:3000",
      mail_from_address: "store@example.com",
      default_currency: "INR"
    )

    @admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @read_only_role = Spree::Role.find_or_create_by!(name: "read_only_orders")

    # Full Admin
    @admin_user = Spree::User.find_or_initialize_by(email: "admin_test@example.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
    end
    @admin_user.first_name = "Admin" if @admin_user.respond_to?(:first_name=)
    @admin_user.last_name = "User" if @admin_user.respond_to?(:last_name=)
    @admin_user.spree_roles << @admin_role unless @admin_user.spree_roles.include?(@admin_role)
    @admin_user.save!(validate: false)

    # Read-Only Staff
    @staff_user = Spree::User.find_or_initialize_by(email: "accounts@jeenimilletmix.in") do |u|
      u.password = "password"
      u.password_confirmation = "password"
    end
    @staff_user.first_name = "Accounts" if @staff_user.respond_to?(:first_name=)
    @staff_user.last_name = "Staff" if @staff_user.respond_to?(:last_name=)
    @staff_user.spree_roles << @read_only_role unless @staff_user.spree_roles.include?(@read_only_role)
    @staff_user.save!(validate: false)

    # Create test order
    @order = Spree::Order.create!(
      number: "R888777666",
      email: "customer@example.com",
      state: "complete",
      completed_at: Time.current,
      currency: "INR",
      total: 750.0,
      item_total: 750.0,
      store: @store
    )
  end

  test "staff user login redirects to admin_custom/orders" do
    post spree_create_new_session_path, params: {
      spree_user: { email: "accounts@jeenimilletmix.in", password: "password" }
    }
    assert_response :redirect
    assert_redirected_to admin_custom_orders_path
  end

  test "staff user can view orders index and show details" do
    post spree_create_new_session_path, params: {
      spree_user: { email: "accounts@jeenimilletmix.in", password: "password" }
    }

    get admin_custom_orders_path
    assert_response :success
    assert_select "h1", text: /Orders Fulfillment/
    assert_select "td", text: @order.number

    get admin_custom_order_path(@order.number)
    assert_response :success
    assert_select "h1", text: /Manage Order: #{@order.number}/
    assert_select "input[value='🚚 Ship Items']", count: 0
    assert_select "input[value='💰 Capture Payment']", count: 0
  end

  test "staff user is blocked 403 from updating order status" do
    post spree_create_new_session_path, params: {
      spree_user: { email: "accounts@jeenimilletmix.in", password: "password" }
    }

    patch update_status_admin_custom_order_path(@order.number), params: { state: "dispatched" }, headers: { "Accept" => "application/json" }
    assert_response :forbidden
    json = JSON.parse(response.body)
    assert_equal false, json["success"]
    assert_includes json["error"], "403 Forbidden"

    @order.reload
    assert_equal "complete", @order.state
  end

  test "staff user is blocked 403 from accessing other admin pages" do
    post spree_create_new_session_path, params: {
      spree_user: { email: "accounts@jeenimilletmix.in", password: "password" }
    }

    get admin_custom_root_path
    assert_response :forbidden

    get admin_custom_products_path
    assert_response :forbidden

    get admin_custom_users_path
    assert_response :forbidden

    get admin_custom_analytics_path
    assert_response :forbidden
  end

  test "admin user retains full access to everything" do
    post spree_create_new_session_path, params: {
      spree_user: { email: "admin_test@example.com", password: "password123" }
    }

    get admin_custom_root_path
    assert_response :success

    get admin_custom_products_path
    assert_response :success

    patch update_status_admin_custom_order_path(@order.number), params: { state: "dispatched" }, headers: { "Accept" => "application/json" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]

    @order.reload
    assert_equal "dispatched", @order.state
  end
end
