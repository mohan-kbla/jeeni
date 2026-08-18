require "test_helper"

class CheckoutControllerTest < ActionDispatch::IntegrationTest
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
    
    @shipping_category = Spree::ShippingCategory.find_or_create_by!(name: "Default")
    
    # Setup Stock Location
    @stock_location = Spree::StockLocation.find_or_create_by!(name: "Main Warehouse") do |loc|
      loc.active = true
      loc.country = Spree::Country.default || Spree::Country.first
      loc.city = "Bangalore"
      loc.state_name = "Karnataka"
    end

    # Setup Zone
    @global_zone = Spree::Zone.find_or_create_by!(name: "Global Zone") do |z|
      z.description = "All countries zone"
    end
    if @global_zone.zone_members.empty?
      @global_zone.zone_members.create!(zoneable: Spree::Country.default || Spree::Country.first)
    end

    # Setup Shipping Method
    @shipping_method = Spree::ShippingMethod.find_or_initialize_by(name: "Standard Shipping")
    @shipping_method.code = "STD-SHIP"
    @shipping_method.display_on = "both"
    @shipping_method.shipping_categories << @shipping_category unless @shipping_method.shipping_categories.include?(@shipping_category)
    @shipping_method.zones << @global_zone unless @shipping_method.zones.include?(@global_zone)
    @shipping_method.calculator ||= Spree::Calculator::FlatRate.create!(preferred_amount: 0.00, preferred_currency: "INR")
    @shipping_method.calculator.preferred_amount = 0.00
    @shipping_method.calculator.save!
    @shipping_method.save!

    # Create the eligible product
    @eligible_product = Spree::Product.find_by(slug: "jeeni-slim-new")
    if @eligible_product.nil?
      @eligible_product = Spree::Product.new(
        name: "Jeeni Slim Weight Loss & Energy Booster | ಜೀನಿ ಸ್ಲಿಮ್",
        slug: "jeeni-slim-new",
        price: 500.00,
        shipping_category: @shipping_category,
        available_on: Time.current,
        status: 'active'
      )
      @eligible_product.stores << @store
      @eligible_product.save!
    else
      @eligible_product.update!(name: "Jeeni Slim Weight Loss & Energy Booster | ಜೀನಿ ಸ್ಲಿಮ್")
    end

    # Ensure stock item exists
    stock_item = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @eligible_product.master)
    stock_item.set_count_on_hand(20)

    # Create the Sugar Amla product
    @sugar_amla_product = Spree::Product.find_by(slug: "jeeni-sugaramla-1kg-sugaramla-1kg")
    if @sugar_amla_product.nil?
      @sugar_amla_product = Spree::Product.new(
        name: "Jeeni Sugaramla 1KG | ಜೀನಿ ಶುಗರ್ ಆಮ್ಲ",
        slug: "jeeni-sugaramla-1kg-sugaramla-1kg",
        price: 600.00,
        shipping_category: @shipping_category,
        available_on: Time.current,
        status: 'active'
      )
      @sugar_amla_product.stores << @store
      @sugar_amla_product.save!
    else
      @sugar_amla_product.update!(name: "Jeeni Sugaramla 1KG | ಜೀನಿ ಶುಗರ್ ಆಮ್ಲ")
    end

    stock_item_amla = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @sugar_amla_product.master)
    stock_item_amla.set_count_on_hand(20)
    
    # Create the gift product
    @gift_product = Spree::Product.find_by(slug: "vegetable-cofpee")
    if @gift_product.nil?
      @gift_product = Spree::Product.new(
        name: "Jeeni Vegetable Cofpee",
        slug: "vegetable-cofpee",
        price: 279.00,
        shipping_category: @shipping_category,
        available_on: Time.current,
        status: 'active'
      )
      @gift_product.stores << @store
      @gift_product.save!
    end

    stock_item_gift = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @gift_product.master)
    stock_item_gift.set_count_on_hand(20)

    # Ensure payment methods exist
    @check_method = Spree::PaymentMethod::Check.first
    if @check_method.nil?
      @check_method = Spree::PaymentMethod::Check.new(
        name: "Check / Cash on Delivery",
        description: "Pay by check or cash on delivery",
        active: true,
        display_on: "both"
      )
      @check_method.stores << @store
      @check_method.save!
    end

    @razorpay_method = Spree::PaymentMethod::Razorpay.first
    if @razorpay_method.nil?
      @razorpay_method = Spree::PaymentMethod::Razorpay.new(
        name: "Razorpay",
        description: "Pay securely via Razorpay",
        active: true,
        display_on: "both"
      )
      @razorpay_method.stores << @store
      @razorpay_method.save!
    end

    # Add product to cart to initialize cart session
    post "/cart/add", params: { variant_id: @eligible_product.master.id, quantity: 1 }
    assert_response :redirect
  end

  test "GET /checkout/payment renders custom payment step components correctly" do
    country = Spree::Country.default || Spree::Country.first
    state = Spree::State.where(country: country).first || Spree::State.create!(name: "Karnataka", abbr: "KA", country: country)

    # Complete Address Step
    patch "/checkout/update", params: {
      order: {
        use_billing: "1",
        bill_address_attributes: {
          full_name: "John Doe",
          address1: "123 Main St",
          city: "Bangalore",
          zipcode: "560001",
          phone: "9876543210",
          country_id: country.id,
          state_id: state.id
        }
      }
    }
    assert_response :redirect

    # Manually transition the order to the payment state to bypass shipping rate configuration complexity
    order = Spree::Order.last
    order.update_column(:state, "payment")

    # Now request the payment page!
    get "/checkout/payment"
    assert_response :success

    # Verify that neither payment method is checked (no checked attribute in input radio)
    assert_select "input[type='radio'][checked]", count: 0
    
    # Verify that the submit button has the disabled-btn class
    assert_select "#checkout-submit-btn.disabled-btn"

    # Verify that the validation error div is present
    assert_select "#payment-validation-message", text: /Please select a payment method to continue/
    
    # Verify that the promotional card is visible and displays gift details
    assert_select "#checkout-gift-notice-online"
    assert_select "#checkout-gift-notice-online", /FREE Vegetable Coffee/
    assert_select "#checkout-gift-notice-online", /Choose Razorpay and receive this gift absolutely FREE/

    # Verify that the Razorpay details and reassurance box are present in the HTML
    assert_select "#card_#{@razorpay_method.id}", /Secure payments powered by Razorpay/
    assert_select "#razorpay-reassurance-panel", text: /100% Secure Payment/
    assert_select "#razorpay-reassurance-panel li", text: "PCI-DSS compliant secure payment"
    assert_select "#razorpay-reassurance-panel li", text: "Your payment information is encrypted"
    assert_select "#razorpay-reassurance-panel li", text: "If payment fails, no money will be deducted."
    assert_select "#razorpay-reassurance-panel li", text: /If any amount is deducted during a failed transaction, it will be refunded automatically/
  end

  test "GET /checkout/payment succeeds even when zipcode is blank during address submission" do
    country = Spree::Country.default || Spree::Country.first
    state = Spree::State.where(country: country).first || Spree::State.create!(name: "Karnataka", abbr: "KA", country: country)

    # 0. Transition order from cart to address state
    get "/checkout"
    assert_response :redirect

    # 1. Complete Address Step with empty zipcode
    patch "/checkout/update", params: {
      order: {
        use_billing: "1",
        bill_address_attributes: {
          full_name: "John Doe",
          address1: "123 Main St",
          city: "Bangalore",
          zipcode: "",
          phone: "9876543210",
          country_id: country.id,
          state_id: state.id
        }
      }
    }
    assert_response :redirect

    order = Spree::Order.last
    assert_equal "payment", order.state
    assert_nil order.bill_address.zipcode.presence
  end

  test "COD shipping charges are calculated correctly based on state" do
    country = Spree::Country.default || Spree::Country.first
    state_ka = Spree::State.find_or_create_by!(name: "Karnataka", abbr: "KA", country: country)
    state_mh = Spree::State.find_or_create_by!(name: "Maharashtra", abbr: "MH", country: country)

    # 0. Transition order from cart to address state
    get "/checkout"
    assert_response :redirect

    # 1. Complete Address Step (using Karnataka state)
    patch "/checkout/update", params: {
      order: {
        use_billing: "1",
        bill_address_attributes: {
          firstname: "Karnataka",
          lastname: "User",
          address1: "123 KA St",
          city: "Bangalore",
          zipcode: "560001",
          phone: "9876543210",
          country_id: country.id,
          state_id: state_ka.id
        }
      }
    }
    assert_response :redirect

    order = Spree::Order.last
    assert_equal "payment", order.state
    assert order.shipments.any?

    # SCENARIO 1: Karnataka + COD = ₹0 Delivery Charge
    order.payments.destroy_all
    order.payments.create!(payment_method: @check_method, amount: order.total)
    order.update_with_updater!
    assert_equal 0.0, order.shipment_total.to_f
    assert_equal order.item_total.to_f, order.total.to_f

    # SCENARIO 2: Karnataka + Online = ₹0 Delivery Charge
    order.payments.destroy_all
    order.payments.create!(payment_method: @razorpay_method, amount: order.total)
    order.update_with_updater!
    assert_equal 0.0, order.shipment_total.to_f
    assert_equal order.item_total.to_f, order.total.to_f

    # SCENARIO 3: Non-Karnataka (Maharashtra) + COD = ₹80 Delivery Charge
    order.payments.destroy_all
    order.ship_address.update!(state: state_mh)
    order.payments.create!(payment_method: @check_method, amount: order.total)
    order.update_with_updater!
    assert_equal 80.0, order.shipment_total.to_f
    assert_equal (order.item_total + 80.0).to_f, order.total.to_f

    # SCENARIO 4: Non-Karnataka (Maharashtra) + Online = ₹0 Delivery Charge
    order.payments.destroy_all
    order.payments.create!(payment_method: @razorpay_method, amount: order.total)
    order.update_with_updater!
    assert_equal 0.0, order.shipment_total.to_f
    assert_equal order.item_total.to_f, order.total.to_f

    # SCENARIO 5: Completed orders are unaffected
    order.payments.destroy_all
    order.payments.create!(payment_method: @check_method, amount: order.total)
    order.update_with_updater!
    assert_equal 80.0, order.shipment_total.to_f
    
    # Complete the order
    order.update_columns(state: "complete", completed_at: Time.current)
    order.reload
    assert_equal 80.0, order.shipment_total.to_f

    # Now change address to Karnataka or payment to Razorpay, completed shipment cost must NOT change
    order.ship_address.update!(state: state_ka)
    order.payments.last.update!(payment_method: @razorpay_method)
    order.update_with_updater!
    assert_equal 80.0, order.shipment_total.to_f
  end

  test "POST /api/wati_webhook creates guest order and sets guest_order to true" do
    post "/api/wati_webhook", params: {
      full_name: "Wati Customer",
      phone: "9876543210",
      address1: "456 Test Road",
      city: "Bangalore",
      state: "Karnataka",
      zipcode: "560002",
      quantity: 1,
      variant_id: @eligible_product.master.id
    }
    assert_response :success
    
    order = Spree::Order.last
    assert_equal true, order.guest_order
    assert_equal "guest_#{order.number}@jeenimilletmix.in", order.email
    assert_equal "Wati", order.ship_address.firstname
    assert_equal "Customer", order.ship_address.lastname
    
    # Assert that no free gift is added
    assert_not order.line_items.any? { |li| li.variant_id == @gift_product.master.id }
  end

  test "POST /api/wati_webhook maps '🔥 JEENI Slim' to Slim product" do
    post "/api/wati_webhook", params: {
      full_name: "Slim Customer",
      phone: "9876543210",
      address1: "123 Slim Road",
      city: "Bangalore",
      state: "Karnataka",
      zipcode: "560002",
      quantity: 1,
      product: "🔥 JEENI Slim"
    }
    assert_response :success
    
    order = Spree::Order.last
    assert_equal 1, order.line_items.count
    assert_equal @eligible_product.master.id, order.line_items.first.variant_id
  end

  test "POST /api/wati_webhook maps '🍀 Sugar Amla' to Sugar Amla product" do
    post "/api/wati_webhook", params: {
      full_name: "Amla Customer",
      phone: "9876543210",
      address1: "123 Amla Road",
      city: "Bangalore",
      state: "Karnataka",
      zipcode: "560002",
      quantity: 1,
      product: "🍀 Sugar Amla"
    }
    assert_response :success
    
    order = Spree::Order.last
    assert_equal 1, order.line_items.count
    assert_equal @sugar_amla_product.master.id, order.line_items.first.variant_id
  end

  test "POST /api/wati_webhook returns error when product parameter is unknown" do
    post "/api/wati_webhook", params: {
      full_name: "Err Customer",
      phone: "9876543210",
      address1: "123 Err Road",
      city: "Bangalore",
      state: "Karnataka",
      zipcode: "560002",
      quantity: 1,
      product: "Unknown Product Box"
    }
    assert_response :success
    json_res = JSON.parse(response.body)
    assert_equal false, json_res["success"]
    assert_match /Unknown WATI product selection/, json_res["error"]
  end

  test "POST /api/wati_webhook handles invalid zipcode by cleaning and defaulting it" do
    post "/api/wati_webhook", params: {
      full_name: "Zipcode Customer",
      phone: "9876543210",
      address1: "123 Street",
      city: "Bangalore",
      state: "Karnataka",
      zipcode: "@zipcode",
      quantity: 1,
      variant_id: @eligible_product.master.id
    }
    assert_response :success
    order = Spree::Order.last
    assert_equal "560001", order.ship_address.zipcode
  end
end
