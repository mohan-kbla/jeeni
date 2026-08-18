require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get "/contact-us"
    assert_response :success
  end

  test "should get create" do
    post "/contacts/create", params: { name: "Test User", email: "test@example.com", mobile: "9876543210", message: "Hello there" }
    assert_response :redirect
    assert_redirected_to "/contact-us"
  end
end
