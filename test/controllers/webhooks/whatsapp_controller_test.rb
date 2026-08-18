require "test_helper"

class Webhooks::WhatsappControllerTest < ActionDispatch::IntegrationTest
  test "GET verify returns challenge if token matches" do
    get webhooks_whatsapp_path, params: {
      "hub.mode" => "subscribe",
      "hub.challenge" => "test_challenge_code",
      "hub.verify_token" => "mock_verify_token"
    }
    assert_response :success
    assert_equal "test_challenge_code", response.body
  end

  test "GET verify returns forbidden if token is incorrect" do
    get webhooks_whatsapp_path, params: {
      "hub.mode" => "subscribe",
      "hub.challenge" => "test_challenge_code",
      "hub.verify_token" => "wrong_token"
    }
    assert_response :forbidden
    assert_equal "Forbidden", response.body
  end

  test "POST receive processes incoming messages and returns ok" do
    payload = {
      object: "whatsapp_business_account",
      entry: [
        {
          id: "WABA_ID",
          changes: [
            {
              value: {
                messaging_product: "whatsapp",
                metadata: {
                  display_phone_number: "16505553333",
                  phone_number_id: "PHONE_NUMBER_ID"
                },
                contacts: [
                  {
                    profile: { name: "Alice" },
                    wa_id: "1234567890"
                  }
                ],
                messages: [
                  {
                    from: "1234567890",
                    id: "wamid.ID",
                    timestamp: "1603017253",
                    text: { body: "hello" },
                    type: "text"
                  }
                ]
              },
              field: "messages"
            }
          ]
        }
      ]
    }

    assert_difference "WhatsappChat.count", 1 do
      post webhooks_whatsapp_path, params: payload, as: :json
      assert_response :success
    end

    chat = WhatsappChat.find_by(phone_number: "1234567890")
    assert_equal "idle", chat.state
  end

  test "POST receive ignores status updates without messages and returns ok" do
    payload = {
      object: "whatsapp_business_account",
      entry: [
        {
          id: "WABA_ID",
          changes: [
            {
              value: {
                messaging_product: "whatsapp",
                statuses: [
                  {
                    id: "wamid.ID",
                    status: "sent",
                    timestamp: "1603017253",
                    recipient_id: "1234567890"
                  }
                ]
              },
              field: "messages"
            }
          ]
        }
      ]
    }

    assert_no_difference "WhatsappChat.count" do
      post webhooks_whatsapp_path, params: payload, as: :json
      assert_response :success
    end
  end
end
