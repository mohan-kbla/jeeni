require 'test_helper'

class AdminCustom::OrdersReportExportTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    @admin_user = Spree::User.find_or_initialize_by(email: "admin_test_export@example.com") do |u|
      u.password = "Password@123"
      u.password_confirmation = "Password@123"
      u.first_name = "Admin"
      u.last_name = "User"
    end
    admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @admin_user.spree_roles << admin_role unless @admin_user.spree_roles.include?(admin_role)
    @admin_user.save!(validate: false)

    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "Password@123" }
    }
  end

  test "export_report returns flash alert if date range is missing" do
    get export_report_admin_custom_orders_path
    assert_redirected_to admin_custom_orders_path
    assert_equal "Please select both From Date and To Date to extract the report.", flash[:alert]
  end

  test "export_report returns flash alert if to_date is earlier than from_date" do
    get export_report_admin_custom_orders_path(from_date: "2026-09-10", to_date: "2026-09-01")
    assert_redirected_to admin_custom_orders_path(from_date: "2026-09-10", to_date: "2026-09-01")
    assert_equal "Invalid date range. To Date cannot be earlier than From Date.", flash[:alert]
  end

  test "export_report returns flash alert if no orders match the selected date range" do
    get export_report_admin_custom_orders_path(from_date: "1999-01-01", to_date: "1999-01-02")
    assert_redirected_to admin_custom_orders_path(from_date: "1999-01-01", to_date: "1999-01-02")
    assert_match /No orders found for the selected date range/, flash[:alert]
  end

  test "export_report streams ODS file when orders exist" do
    order = Spree::Order.create!(
      store: @store,
      state: "complete",
      completed_at: Time.current,
      total: 1575.0,
      payment_total: 1575.0,
      currency: "INR",
      email: "customer_test@example.com"
    )

    get export_report_admin_custom_orders_path(from_date: Time.current.to_date.to_s, to_date: Time.current.to_date.to_s)
    assert_response :success
    assert_equal "application/vnd.oasis.opendocument.spreadsheet", response.media_type
    assert_match /filename="jeeni_orders_report_/, response.headers["Content-Disposition"]
  end
end
