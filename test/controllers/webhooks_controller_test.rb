require "test_helper"
require "openssl"
require "json"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
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

    # 1. Setup payment method
    @payment_method = Spree::PaymentMethod::Razorpay.new(
      name: "Razorpay",
      active: true,
      display_on: "both"
    )
    @payment_method.stores << @store
    @payment_method.preferred_key_id = "test_key_id"
    @payment_method.preferred_key_secret = "test_key_secret"
    @payment_method.preferred_webhook_secret = "test_webhook_secret"
    @payment_method.save!

    # 2. Setup order
    @order = Spree::Order.create!(
      store: @store,
      number: "R999999999",
      total: 100.00,
      currency: "INR",
      state: "confirm",
      email: "customer@example.com"
    )

    # Stub next to transition state to complete and return true
    def @order.next
      self.update!(state: "complete")
      true
    end

    # 3. Setup payment
    @payment = @order.payments.create!(
      payment_method: @payment_method,
      amount: 100.00,
      state: "checkout"
    )
  end

  test "returns bad request if signature is missing" do
    post razorpay_webhook_path, params: { event: "payment.captured" }, as: :json
    assert_response :bad_request
    assert_includes response.body, "Signature missing"
  end

  test "returns bad request if signature verification fails" do
    post razorpay_webhook_path, 
         params: { event: "payment.captured" }, 
         headers: { "X-Razorpay-Signature" => "invalid_signature" }, 
         as: :json
    assert_response :bad_request
    assert_includes response.body, "Signature verification failed"
  end

  test "processes payment.captured event successfully and transitions order" do
    razorpay_order_id = "order_test123456"
    @payment.update!(
      public_metadata: { razorpay_order_id: razorpay_order_id }
    )

    payload = {
      event: "payment.captured",
      payload: {
        payment: {
          entity: {
            id: "pay_test123",
            order_id: razorpay_order_id,
            amount: 10000,
            currency: "INR",
            status: "captured",
            description: "Order R999999999"
          }
        }
      }
    }

    raw_payload = payload.to_json
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), "test_webhook_secret", raw_payload)

    post razorpay_webhook_path, 
         params: payload, 
         headers: { "X-Razorpay-Signature" => signature }, 
         as: :json

    assert_response :success
    assert_equal "completed", @payment.reload.state
    assert_equal "pay_test123", @payment.reload.response_code
    assert_equal "complete", @order.reload.state
  end

  test "processes order.paid event successfully and is idempotent" do
    razorpay_order_id = "order_test123456"
    @payment.update!(
      public_metadata: { razorpay_order_id: razorpay_order_id }
    )

    payload = {
      event: "order.paid",
      payload: {
        order: {
          entity: {
            id: razorpay_order_id,
            receipt: "R999999999",
            status: "paid"
          }
        },
        payment: {
          entity: {
            id: "pay_test123",
            order_id: razorpay_order_id
          }
        }
      }
    }

    raw_payload = payload.to_json
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), "test_webhook_secret", raw_payload)

    post razorpay_webhook_path, 
         params: payload, 
         headers: { "X-Razorpay-Signature" => signature }, 
         as: :json

    assert_response :success
    assert_equal "completed", @payment.reload.state
    assert_equal "complete", @order.reload.state

    # Test Idempotency: Send the same request again
    post razorpay_webhook_path, 
         params: payload, 
         headers: { "X-Razorpay-Signature" => signature }, 
         as: :json

    assert_response :success
    assert_includes response.body, "Order already completed"
  end

  test "processes payment.failed event successfully" do
    razorpay_order_id = "order_test123456"
    @payment.update!(
      public_metadata: { razorpay_order_id: razorpay_order_id }
    )

    payload = {
      event: "payment.failed",
      payload: {
        payment: {
          entity: {
            id: "pay_test_failed",
            order_id: razorpay_order_id,
            status: "failed",
            error_code: "BAD_REQUEST_ERROR"
          }
        }
      }
    }

    raw_payload = payload.to_json
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), "test_webhook_secret", raw_payload)

    post razorpay_webhook_path, 
         params: payload, 
         headers: { "X-Razorpay-Signature" => signature }, 
         as: :json

    assert_response :success
    assert_equal "failed", @payment.reload.state
    assert_equal "pay_test_failed", @payment.reload.response_code
  end
end
