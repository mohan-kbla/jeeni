require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class AdminCustom::RevokeUserAccessTest < ActionDispatch::IntegrationTest
  setup do
    @admin_role = Spree::Role.find_or_create_by!(name: "admin")

    @admin_user = Spree::User.find_or_initialize_by(email: "admin_test@example.com") do |u|
      u.password = "Password@123"
      u.password_confirmation = "Password@123"
      u.first_name = "Admin"
      u.last_name = "Test"
    end
    @admin_user.spree_roles << @admin_role unless @admin_user.spree_roles.include?(@admin_role)
    @admin_user.save!(validate: false)

    @dilip_user = Spree::User.find_or_initialize_by(email: "dilipsira222@gmail.com") do |u|
      u.password = "Password@123"
      u.password_confirmation = "Password@123"
      u.first_name = "Dilip"
      u.last_name = "Sira"
    end
    # Ensure dilip has no admin or staff roles
    @dilip_user.spree_roles.clear
    @dilip_user.save!(validate: false)
  end

  test "dilip user without admin role is denied access to admin custom pages" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @dilip_user.email, password: "Password@123" }
    }
    assert_redirected_to spree.account_path

    # Try to access admin custom root
    get admin_custom_root_path
    assert_redirected_to root_path
    assert_equal "You are not authorized to access this page.", flash[:alert]

    # Try to access admin custom orders
    get admin_custom_orders_path
    assert_redirected_to root_path
  end

  test "admin user can revoke roles for another user" do
    # Temporarily grant admin to dilip
    @dilip_user.spree_roles << @admin_role

    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "Password@123" }
    }

    patch admin_custom_user_path(@dilip_user), params: { role_name: "revoke" }
    assert_redirected_to admin_custom_users_path

    @dilip_user.reload
    assert_empty @dilip_user.spree_roles.pluck(:name)
  end
end
