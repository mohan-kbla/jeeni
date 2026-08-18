require 'test_helper'

class TrackOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.default || Spree::Store.first || Spree::Store.create!(
      name: "Jeeni Store",
      code: "jeeni",
      url: "jeenimilletmix.in",
      mail_from_address: "no-reply@jeenimilletmix.in",
      default_currency: "INR"
    )

    @country = Spree::Country.first || Spree::Country.create!(
      name: "India",
      iso_name: "INDIA",
      iso: "IN",
      iso3: "IND"
    )

    @state = Spree::State.first || Spree::State.create!(
      name: "Karnataka",
      abbr: "KA",
      country: @country
    )
    
    # Create guest order
    @guest_order = Spree::Order.create!(
      number: "R999888777",
      email: "guest_checkout@example.com",
      state: "complete",
      completed_at: Time.current,
      currency: "INR",
      total: 500.0,
      store: @store
    )

    address_attribs = {
      firstname: "Guest",
      lastname: "Customer",
      address1: "123 Main Street",
      city: "Bengaluru",
      zipcode: "560001",
      phone: "9876543210",
      country: @country,
      state: @state
    }

    @ship_address = Spree::Address.create!(address_attribs)
    @guest_order.update_columns(ship_address_id: @ship_address.id, bill_address_id: @ship_address.id)

    # Create registered user order
    @user = Spree::User.new(
      email: "registered_user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @user.first_name = "Registered" if @user.respond_to?(:first_name=)
    @user.last_name = "User" if @user.respond_to?(:last_name=)
    @user.save!(validate: false)

    @user_order = Spree::Order.create!(
      number: "R111222333",
      email: @user.email,
      user_id: @user.id,
      state: "dispatched",
      completed_at: 1.day.ago,
      currency: "INR",
      total: 1200.0,
      store: @store
    )
    
    user_address = Spree::Address.create!(address_attribs.merge(firstname: "Registered", phone: "9123456789"))
    @user_order.update_columns(ship_address_id: user_address.id, bill_address_id: user_address.id)
  end

  test "should get show page without login" do
    get track_order_path
    assert_response :success
    assert_select "h1", text: "Track Your Order"
    assert_select "input[name='order_number']"
    assert_select "input[name='verification']"
  end

  test "should track guest order with matching email" do
    get track_order_path, params: { order_number: @guest_order.number, verification: "guest_checkout@example.com" }
    assert_response :success
    assert_select "h2", text: /Order Status Timeline/
    assert_select "strong", text: @guest_order.number
  end

  test "should track guest order with matching mobile number" do
    get track_order_path, params: { order_number: @guest_order.number, verification: "9876543210" }
    assert_response :success
    assert_select "h2", text: /Order Status Timeline/
    assert_select "strong", text: @guest_order.number
  end

  test "should track registered user order with matching email" do
    get track_order_path, params: { order_number: @user_order.number, verification: "REGISTERED_USER@EXAMPLE.COM" }
    assert_response :success
    assert_select "h2", text: /Order Status Timeline/
    assert_select "strong", text: @user_order.number
  end

  test "should track registered user order with matching mobile number" do
    get track_order_path, params: { order_number: @user_order.number, verification: "9123456789" }
    assert_response :success
    assert_select "h2", text: /Order Status Timeline/
    assert_select "strong", text: @user_order.number
  end

  test "should show error for invalid order number" do
    get track_order_path, params: { order_number: "INVALID123", verification: "guest_checkout@example.com" }
    assert_response :success
    assert_includes response.body, "Order not found. Please check your Order Number and Email/Mobile."
    assert_select "h2", { count: 0, text: /Order Status Timeline/ }
  end

  test "should show error for mismatched email or mobile number" do
    get track_order_path, params: { order_number: @guest_order.number, verification: "wrong_email@example.com" }
    assert_response :success
    assert_includes response.body, "Order not found. Please check your Order Number and Email/Mobile."
    assert_select "h2", { count: 0, text: /Order Status Timeline/ }
  end
end
