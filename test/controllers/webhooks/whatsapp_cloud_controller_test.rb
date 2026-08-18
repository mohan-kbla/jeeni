require "test_helper"

class Webhooks::WhatsappCloudControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Configure ENV variables for testing
    ENV["WHATSAPP_CLOUD_VERIFY_TOKEN"] = "test_verify_token"
    ENV["WHATSAPP_CLOUD_API_TOKEN"] = "" # Keep it blank to trigger mock behavior
    ENV["WHATSAPP_CLOUD_PHONE_NUMBER_ID"] = ""

    # Clear conversations/messages
    WhatsappConversation.destroy_all
    WhatsappMessage.destroy_all

    # Setup Spree Store and defaults
    @store = Spree::Store.default
    if @store.nil?
      @store = Spree::Store.new(
        code: "spree",
        name: "Jeeni Shop",
        url: "localhost:3000",
        mail_from_address: "store@example.com",
        default_currency: "INR",
        default: true
      )
    else
      @store.code = "spree" if @store.code.blank?
      @store.name = "Jeeni Shop" if @store.name.blank?
      @store.url = "localhost:3000" if @store.url.blank?
      @store.mail_from_address = "store@example.com" if @store.mail_from_address.blank?
      @store.default_currency = "INR" if @store.default_currency.blank?
    end
    @store.default_country ||= Spree::Country.default || Spree::Country.first || Spree::Country.create!(name: "India", iso_name: "INDIA", iso: "IN", iso3: "IND", numcode: 356)
    @store.save!

    @shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")

    @stock_location = Spree::StockLocation.find_or_create_by!(name: "Main Warehouse") do |loc|
      loc.active = true
      loc.country = Spree::Country.default || Spree::Country.first
      loc.city = "Bangalore"
      loc.state_name = "Karnataka"
    end

    @global_zone = Spree::Zone.find_or_create_by!(name: "Global Zone") do |z|
      z.description = "All countries zone"
    end
    if @global_zone.zone_members.empty?
      @global_zone.zone_members.create!(zoneable: Spree::Country.default || Spree::Country.first)
    end

    @shipping_method = Spree::ShippingMethod.find_or_initialize_by(name: "Standard Shipping")
    @shipping_method.code = "STD-SHIP"
    @shipping_method.display_on = "both"
    @shipping_method.shipping_categories << @shipping_category unless @shipping_method.shipping_categories.include?(@shipping_category)
    @shipping_method.zones << @global_zone unless @shipping_method.zones.include?(@global_zone)
    @shipping_method.calculator ||= Spree::Calculator::FlatRate.create!(preferred_amount: 0.00, preferred_currency: "INR")
    @shipping_method.save!

    # Create the Spree products
    @slim_product = Spree::Product.find_or_initialize_by(name: "Jeeni Slim Weight Loss & Energy Booster | ಜೀನಿ ಸ್ಲಿಮ್")
    @slim_product.slug = "jeeni-slim-new"
    @slim_product.price = 500.00
    @slim_product.shipping_category = @shipping_category
    @slim_product.available_on = Time.current
    @slim_product.status = 'active'
    @slim_product.stores << @store unless @slim_product.stores.include?(@store)
    @slim_product.save!

    stock_item_slim = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @slim_product.master)
    stock_item_slim.set_count_on_hand(20)

    @sugar_amla_product = Spree::Product.find_or_initialize_by(name: "Jeeni Sugaramla 1KG | ಜೀನಿ ಶುಗರ್ ಆಮ್ಲ")
    @sugar_amla_product.slug = "jeeni-sugaramla-1kg-sugaramla-1kg"
    @sugar_amla_product.price = 600.00
    @sugar_amla_product.shipping_category = @shipping_category
    @sugar_amla_product.available_on = Time.current
    @sugar_amla_product.status = 'active'
    @sugar_amla_product.stores << @store unless @sugar_amla_product.stores.include?(@store)
    @sugar_amla_product.save!

    stock_item_amla = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @sugar_amla_product.master)
    stock_item_amla.set_count_on_hand(20)

    @millet_mix_product = Spree::Product.find_or_initialize_by(name: "JEENI MILLET TRADITIONAL MIX 900gm")
    @millet_mix_product.slug = "jeeni-millet-traditional-mix-900gm"
    @millet_mix_product.price = 450.00
    @millet_mix_product.shipping_category = @shipping_category
    @millet_mix_product.available_on = Time.current
    @millet_mix_product.status = 'active'
    @millet_mix_product.stores << @store unless @millet_mix_product.stores.include?(@store)
    @millet_mix_product.save!

    stock_item_millet = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @millet_mix_product.master)
    stock_item_millet.set_count_on_hand(20)

    @check_method = Spree::PaymentMethod::Check.first
    if @check_method.nil?
      @check_method = Spree::PaymentMethod::Check.new(
        name: "Check",
        description: "Pay by check",
        active: true,
        display_on: "both"
      )
      @check_method.stores << @store
      @check_method.save!
    end
  end

  # ==========================================
  # 1. Webhook Verification Tests
  # ==========================================
  test "GET verify subscription with correct token" do
    get webhooks_whatsapp_cloud_url, params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "test_verify_token",
      "hub.challenge" => "my_challenge_code"
    }
    assert_response :success
    assert_equal "my_challenge_code", response.body
  end

  test "GET verify subscription with incorrect token returns 403 Forbidden" do
    get webhooks_whatsapp_cloud_url, params: {
      "hub.mode" => "subscribe",
      "hub.verify_token" => "wrong_token",
      "hub.challenge" => "my_challenge_code"
    }
    assert_response :forbidden
    assert_equal "Forbidden", response.body
  end

  # ==========================================
  # 2. Conversation Flow Test Sequence
  # ==========================================
  test "full conversational booking flow to completed order" do
    wa_id = "919900990099"

    # Step 2.1: Initial message "Hi" -> greets and transitions to ASK_PRODUCT
    assert_difference "WhatsappConversation.count", 1 do
      post_text_message(wa_id, "Hi", "msg_1")
    end
    assert_response :ok

    conv = WhatsappConversation.find_by(wa_id: wa_id)
    assert_equal "ASK_PRODUCT", conv.state

    # Step 2.2: Product selection button reply
    post_interactive_button(wa_id, "product_jeeni_slim", "JEENI SLIM", "msg_2")
    assert_response :ok
    conv.reload
    assert_equal "ASK_NAME", conv.state
    assert_equal @slim_product.id, conv.product_id

    # Step 2.3: Name collection
    post_text_message(wa_id, "Mohan Kumar", "msg_3")
    assert_response :ok
    conv.reload
    assert_equal "ASK_LOCATION", conv.state
    assert_equal "Mohan Kumar", conv.customer_name

    # Step 2.4: Location collection
    post_text_message(wa_id, "Bangalore South", "msg_4")
    assert_response :ok
    conv.reload
    assert_equal "ASK_ADDRESS", conv.state
    assert_equal "Bangalore South", conv.city

    # Step 2.5: Address collection
    post_text_message(wa_id, "No. 12, 5th Cross, Jayanagar", "msg_5")
    assert_response :ok
    conv.reload
    assert_equal "ASK_ZIPCODE", conv.state
    assert_equal "No. 12, 5th Cross, Jayanagar", conv.address

    # Step 2.6: Zipcode collection (invalid check first)
    post_text_message(wa_id, "123", "msg_6")
    assert_response :ok
    conv.reload
    assert_equal "ASK_ZIPCODE", conv.state # state should not change

    # Zipcode collection (valid check)
    post_text_message(wa_id, "560041", "msg_7")
    assert_response :ok
    conv.reload
    assert_equal "CONFIRM_ORDER", conv.state
    assert_equal "560041", conv.zipcode

    # Step 2.7: Confirm Order
    assert_difference "Spree::Order.count", 1 do
      post_interactive_button(wa_id, "confirm_order", "CONFIRM ORDER", "msg_8")
    end
    assert_response :ok

    conv.reload
    assert_equal "COMPLETED", conv.state
    assert_not_nil conv.spree_order_id

    order = Spree::Order.find(conv.spree_order_id)
    assert_equal "WhatsApp", order.booking_source
    assert_equal true, order.public_metadata["whatsapp_cloud_booking"]
    assert_equal "complete", order.state
    assert_equal "Mohan", order.bill_address.firstname
    assert_equal "Kumar", order.bill_address.lastname
    assert_equal "Bangalore South", order.bill_address.city
    assert_equal "560041", order.bill_address.zipcode
    assert_equal "No. 12, 5th Cross, Jayanagar", order.bill_address.address1
  end

  # ==========================================
  # 3. Cancellation Flow Test
  # ==========================================
  test "conversational flow cancellation" do
    wa_id = "918888888888"

    post_text_message(wa_id, "Hello", "msg_c1")
    conv = WhatsappConversation.find_by(wa_id: wa_id)
    assert_equal "ASK_PRODUCT", conv.state

    # Cancel via text
    post_text_message(wa_id, "cancel", "msg_c2")
    conv.reload
    assert_equal "CANCELLED", conv.state
    assert_nil conv.product_id
  end

  # ==========================================
  # 4. Restart Flow Test
  # ==========================================
  test "conversational flow restart" do
    wa_id = "917777777777"

    post_text_message(wa_id, "Hi", "msg_r1")
    post_interactive_button(wa_id, "product_jeeni_sugar_amla", "JEENI SUGAR AMLA", "msg_r2")
    conv = WhatsappConversation.find_by(wa_id: wa_id)
    assert_equal "ASK_NAME", conv.state

    # Restart
    post_text_message(wa_id, "restart", "msg_r3")
    conv.reload
    assert_equal "ASK_PRODUCT", conv.state
    assert_nil conv.product_id
  end

  # ==========================================
  # 5. Idempotency Test
  # ==========================================
  test "duplicate message id is ignored" do
    wa_id = "916666666666"

    assert_difference "WhatsappMessage.count", 1 do
      post_text_message(wa_id, "Hi", "msg_dup")
    end
    assert_response :ok

    # Post same message ID again -> Message count should not increase, and should return ok
    assert_no_difference "WhatsappMessage.count" do
      post_text_message(wa_id, "Hi", "msg_dup")
    end
    assert_response :ok
  end

  private

  def post_text_message(wa_id, body, message_id)
    post webhooks_whatsapp_cloud_url, params: {
      "object" => "whatsapp_business_account",
      "entry" => [
        {
          "id" => "biz_id",
          "changes" => [
            {
              "value" => {
                "messaging_product" => "whatsapp",
                "metadata" => {
                  "display_phone_number" => "12345",
                  "phone_number_id" => "phone_id"
                },
                "contacts" => [
                  {
                    "profile" => { "name" => "User Profile Name" },
                    "wa_id" => wa_id
                  }
                ],
                "messages" => [
                  {
                    "from" => wa_id,
                    "id" => message_id,
                    "timestamp" => Time.current.to_i.to_s,
                    "text" => { "body" => body },
                    "type" => "text"
                  }
                ]
              },
              "field" => "messages"
            }
          ]
        }
      ]
    }, as: :json
  end

  def post_interactive_button(wa_id, button_id, button_title, message_id)
    post webhooks_whatsapp_cloud_url, params: {
      "object" => "whatsapp_business_account",
      "entry" => [
        {
          "id" => "biz_id",
          "changes" => [
            {
              "value" => {
                "messaging_product" => "whatsapp",
                "metadata" => {
                  "display_phone_number" => "12345",
                  "phone_number_id" => "phone_id"
                },
                "contacts" => [
                  {
                    "profile" => { "name" => "User Profile Name" },
                    "wa_id" => wa_id
                  }
                ],
                "messages" => [
                  {
                    "from" => wa_id,
                    "id" => message_id,
                    "timestamp" => Time.current.to_i.to_s,
                    "type" => "interactive",
                    "interactive" => {
                      "type" => "button_reply",
                      "button_reply" => {
                        "id" => button_id,
                        "title" => button_title
                      }
                    }
                  }
                ]
              },
              "field" => "messages"
            }
          ]
        }
      ]
    }, as: :json
  end
end
