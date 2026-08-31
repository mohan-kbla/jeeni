require 'test_helper'

# Stub ActiveStorage analysis to prevent background thread database connection locks
class ActiveStorage::Blob
  def analyze
    # No-op
  end

  def analyzed?
    true
  end
end

class AdminCustom::DailyCompanyUpdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @read_only_role = Spree::Role.find_or_create_by!(name: "read_only_orders")

    @admin_user = Spree::User.find_or_initialize_by(email: "admin_test@example.com") do |u|
      u.password = "password123"
      u.password_confirmation = "password123"
    end
    @admin_user.spree_roles << @admin_role unless @admin_user.spree_roles.include?(@admin_role)
    @admin_user.save!(validate: false)

    @staff_user = Spree::User.find_or_initialize_by(email: "accounts@jeenimilletmix.in") do |u|
      u.password = "password"
      u.password_confirmation = "password"
    end
    @staff_user.spree_roles << @read_only_role unless @staff_user.spree_roles.include?(@read_only_role)
    @staff_user.save!(validate: false)

    DailyCompanyUpdate.destroy_all
  end

  test "guest visitor should be redirected to root when accessing daily updates" do
    get admin_custom_daily_company_updates_path
    assert_response :redirect
  end

  test "admin user should access index page successfully" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "password123" }
    }
    get admin_custom_daily_company_updates_path
    assert_response :success
    assert_select "h1", text: /Daily Company Updates/
  end

  test "admin user can upload an update and activate it" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "password123" }
    }

    assert_difference "DailyCompanyUpdate.count", 1 do
      post admin_custom_daily_company_updates_path, params: {
        daily_company_update: {
          title: "New Outlet Launch",
          media_type: "image",
          media: fixture_file_upload(Rails.root.join("test/fixtures/files", ".keep"), "image/png")
        },
        save_and_activate: "true"
      }
    end

    assert_redirected_to admin_custom_daily_company_updates_path
    new_update = DailyCompanyUpdate.last
    assert_equal "New Outlet Launch", new_update.title
    assert new_update.active?
  end

  test "staff user with read-only role cannot upload updates" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @staff_user.email, password: "password" }
    }

    # Staff user is blocked when trying to access or post
    get admin_custom_daily_company_updates_path
    assert_response :forbidden

    assert_no_difference "DailyCompanyUpdate.count" do
      post admin_custom_daily_company_updates_path, params: {
        daily_company_update: {
          title: "Staff Upload Attempt",
          media_type: "image",
          media: fixture_file_upload(Rails.root.join("test/fixtures/files", ".keep"), "image/png")
        }
      }
    end
    assert_response :forbidden
  end

  test "homepage renders successfully when active media exists" do
    update = DailyCompanyUpdate.new(title: "Active Promo Image", media_type: "image", active: true)
    update.media.attach(io: StringIO.new("fake"), filename: "test.jpg", content_type: "image/jpeg")
    update.save!

    get root_path
    assert_response :success
    assert_select "span", text: "🌿 Jeeni Today"
    assert_select "div.daily-update-box img"
  end

  test "homepage renders default text when no active media exists" do
    get root_path
    assert_response :success
    assert_select "span", text: "🌾 Wholesome & Traditional Grains"
  end
end
