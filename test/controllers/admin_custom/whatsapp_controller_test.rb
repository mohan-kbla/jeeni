require 'test_helper'

class AdminCustom::WhatsappControllerTest < ActionDispatch::IntegrationTest
  setup do
    @store = Spree::Store.first || Spree::Store.create!(name: "Default Store", code: "spree", mail_from_address: "store@example.com", url: "example.com", default_currency: "INR")
    @admin_user = Spree::User.find_or_initialize_by(email: "admin_test_whatsapp@example.com") do |u|
      u.password = "Password@123"
      u.password_confirmation = "Password@123"
      u.first_name = "Admin"
      u.last_name = "User"
    end
    admin_role = Spree::Role.find_or_create_by!(name: "admin")
    @admin_user.spree_roles << admin_role unless @admin_user.spree_roles.include?(admin_role)
    @admin_user.save!(validate: false)

    @conversation = WhatsappConversation.create!(
      wa_id: "919999999999",
      phone_number: "919999999999",
      customer_name: "Test Customer",
      state: "COMPLETED",
      product_name: "Jeeni Slim",
      quantity: 1
    )

    @message = WhatsappMessage.create!(
      message_id: "test_msg_id_123",
      wa_id: "919999999999",
      message_type: "text",
      payload: { text: { body: "Hello World" } }.to_json
    )
  end

  test "admin user can view whatsapp chats index" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "Password@123" }
    }

    get admin_custom_whatsapp_index_path
    assert_response :success
    assert_select "h1", text: /WhatsApp Bot & Customer Conversations/
    assert_select "strong", text: /Test Customer/
  end

  test "admin user can filter whatsapp chats by state and search query" do
    post spree_create_new_session_path, params: {
      spree_user: { email: @admin_user.email, password: "Password@123" }
    }

    get admin_custom_whatsapp_index_path(state: "COMPLETED", query: "Test")
    assert_response :success
    assert_select "strong", text: /Test Customer/
  end
end
