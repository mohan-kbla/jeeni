require 'test_helper'

class ActiveStorage::Blob
  def analyze; end
  def analyzed?; true; end
end

class AdminCustom::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shipping_category = Spree::ShippingCategory.first || Spree::ShippingCategory.create!(name: "Default")
    @store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    
    @admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @admin_user = Spree::User.find_or_initialize_by(email: "admin_reports_test@example.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
    end
    @admin_user.spree_roles << @admin_role unless @admin_user.spree_roles.include?(@admin_role)
    @admin_user.save!(validate: false)

    @prod1 = Spree::Product.first || Spree::Product.create!(name: "Test Prod 1", price: 100, sku: "TEST-PROD-1", shipping_category: @shipping_category, stores: [@store])
    @prod2 = Spree::Product.create!(name: "Test Prod 2", price: 200, sku: "TEST-PROD-2", shipping_category: @shipping_category, stores: [@store])
  end

  test "guest visitor should be redirected when accessing reports" do
    get admin_custom_reports_path
    assert_response :redirect
  end

  test "admin user can view reports index page with multi-product filter UI" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "password123" }
    }
    get admin_custom_reports_path
    assert_response :success
    assert_select "h1", text: /Reports & Analytics/
    assert_select "#product-multiselect-wrapper"
    assert_select "#product-dropdown-btn"
    assert_select "#product-dropdown-menu"
  end

  test "admin user can filter reports by multiple product IDs" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "password123" }
    }

    get admin_custom_reports_path, params: { product_ids: [@prod1.id.to_s, @prod2.id.to_s] }
    assert_response :success
    assert_select "#product-dropdown-label", text: /2 Products Selected/
  end

  test "admin user can export CSV with multiple product IDs filter" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "password123" }
    }

    get "/admin_custom/reports/export", params: { format: "csv", product_ids: [@prod1.id.to_s, @prod2.id.to_s] }
    assert_response :success
    assert_equal "text/csv", response.media_type
  end
end
