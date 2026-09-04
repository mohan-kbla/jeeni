require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class AdminCustom::DilipAdminAccessTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(
      name: "Default Store",
      code: "spree",
      mail_from_address: "store@example.com",
      url: "example.com",
      default_currency: "INR"
    )
    @store.update_columns(default_currency: "INR") if @store.default_currency.blank?

    @admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @dilip_user = Spree::User.find_or_initialize_by(email: "dilipsira222@gmail.com") do |u|
      u.password = "Password@123"
      u.password_confirmation = "Password@123"
      u.first_name = "Dilip"
      u.last_name = "Sira"
    end
    @dilip_user.spree_roles.clear
    @dilip_user.spree_roles << @admin_role
    @dilip_user.save!(validate: false)
  end

  test "dilipsira222@gmail.com with admin role has access to general admin custom pages" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @dilip_user.email, password: "Password@123" }
    }

    get admin_custom_root_path
    assert_response :success

    get admin_custom_orders_path
    assert_response :success

    get admin_custom_users_path
    assert_response :success

    get admin_custom_products_path
    assert_response :success
  end

  test "dilipsira222@gmail.com is denied access to main analytics page but granted access to booking_sources" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @dilip_user.email, password: "Password@123" }
    }

    get admin_custom_analytics_path
    assert_redirected_to admin_custom_orders_path
    assert_equal "403 Access Denied: You do not have access to the main Analytics page.", flash[:alert]

    get admin_custom_analytics_booking_sources_path
    assert_response :success
  end
end
