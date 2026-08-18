require "test_helper"

class Whatsapp::ProcessorServiceTest < ActiveSupport::TestCase
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
    @stock_location = Spree::StockLocation.find_or_create_by!(name: "Main Warehouse") do |loc|
      loc.active = true
      loc.country = Spree::Country.default || Spree::Country.first
      loc.city = "Bangalore"
      loc.state_name = "Karnataka"
    end
    
    @global_zone = Spree::Zone.find_or_create_by!(name: "Global Zone")
    if @global_zone.zone_members.empty?
      @global_zone.zone_members.create!(zoneable: Spree::Country.default || Spree::Country.first)
    end

    @shipping_method = Spree::ShippingMethod.find_or_initialize_by(name: "Standard Shipping")
    @shipping_method.code = "STD-SHIP"
    @shipping_method.display_on = "both"
    @shipping_method.shipping_categories << @shipping_category unless @shipping_method.shipping_categories.include?(@shipping_category)
    @shipping_method.zones << @global_zone unless @shipping_method.zones.include?(@global_zone)
    @shipping_method.calculator ||= Spree::Calculator::FlatRate.create!(preferred_amount: 0.00, preferred_currency: "INR")
    @shipping_method.calculator.preferred_amount = 0.00
    @shipping_method.save!

    @cod_payment_method = Spree::PaymentMethod::Check.first
    if @cod_payment_method.nil?
      @cod_payment_method = Spree::PaymentMethod::Check.new(
        name: "Check",
        description: "Cash on Delivery",
        active: true,
        display_on: "both"
      )
      @cod_payment_method.stores << @store
      @cod_payment_method.save!
    end

    @product1 = Spree::Product.new(
      name: "Super Juice",
      price: 15.00,
      description: "Tastes good",
      shipping_category: @shipping_category,
      available_on: Time.current,
      status: 'active'
    )
    @product1.stores << @store
    @product1.save!

    stock_item1 = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @product1.master)
    stock_item1.set_count_on_hand(20)

    @phone = "9876543210"
  end

  test "hello commands return welcome message" do
    response = Whatsapp::ProcessorService.call(@phone, "Hello")
    assert_match "Welcome to our WhatsApp Store!", response
    chat = WhatsappChat.find_by(phone_number: @phone)
    assert_equal "idle", chat.state
  end

  test "list command shows products and transitions state" do
    response = Whatsapp::ProcessorService.call(@phone, "list")
    assert_match "Super Juice", response
    chat = WhatsappChat.find_by(phone_number: @phone)
    assert_equal "selecting_product", chat.state
  end

  test "selecting product transitions to quantity" do
    Whatsapp::ProcessorService.call(@phone, "list")

    response = Whatsapp::ProcessorService.call(@phone, @product1.id.to_s)
    assert_match "You selected *Super Juice*", response
    assert_match "How many would you like to add?", response

    chat = WhatsappChat.find_by(phone_number: @phone)
    assert_equal "entering_quantity", chat.state
    assert_equal @product1.id, chat.get_metadata("selected_product_id")
  end

  test "entering quantity adds item to cart" do
    chat = WhatsappChat.create!(phone_number: @phone, state: "entering_quantity")
    chat.update_metadata("selected_product_id", @product1.id)

    response = Whatsapp::ProcessorService.call(@phone, "3")
    assert_match "Added 3 x *Super Juice* to your cart!", response

    chat.reload
    assert_equal "idle", chat.state
    assert_nil chat.get_metadata("selected_product_id")
    assert_not_nil chat.cart_id
    
    order = Spree::Order.find(chat.cart_id)
    assert_equal 1, order.line_items.count
    assert_equal 3, order.line_items.first.quantity
  end

  test "full simplified checkout and order creation flow" do
    # Prepare order
    order = Spree::Order.create!(store: @store)
    Spree::Cart::AddItem.call(order: order, variant: @product1.master, quantity: 2)

    chat = WhatsappChat.create!(phone_number: @phone, state: "idle", cart_id: order.id)

    # 1. Start checkout
    response = Whatsapp::ProcessorService.call(@phone, "checkout")
    assert_match "What is your full name?", response
    assert_equal "entering_name", chat.reload.state

    # 2. Enter Name
    response = Whatsapp::ProcessorService.call(@phone, "Bob Vance")
    assert_match "Which city are you in?", response
    assert_equal "Bob Vance", chat.reload.get_metadata("name")
    assert_equal "entering_city", chat.state

    # 3. Enter City
    response = Whatsapp::ProcessorService.call(@phone, "Scranton")
    assert_match "local area/place", response
    assert_equal "Scranton", chat.reload.get_metadata("city")
    assert_equal "entering_place", chat.state

    # 4. Enter Place
    response = Whatsapp::ProcessorService.call(@phone, "Vance Plaza")
    assert_match "pincode", response
    assert_equal "Vance Plaza", chat.reload.get_metadata("place")
    assert_equal "entering_pincode", chat.state

    # 5. Enter Pincode
    response = Whatsapp::ProcessorService.call(@phone, "18503")
    assert_match "Order Summary", response
    assert_match "Vance Plaza, Scranton, 18503", response
    assert_equal "18503", chat.reload.get_metadata("pincode")
    assert_equal "confirming", chat.state

    # 6. Confirm Order
    response = Whatsapp::ProcessorService.call(@phone, "confirm")
    assert_match "placed successfully", response

    chat.reload
    assert_equal "idle", chat.state
    assert_nil chat.cart_id
    assert_equal({}, chat.metadata)

    order.reload
    assert order.completed?
    assert_equal "Bob", order.ship_address.firstname
    assert_equal "Vance", order.ship_address.lastname
    assert_equal @phone, order.ship_address.phone
    assert_equal "Vance Plaza, Scranton, 18503", order.ship_address.address1
  end

  test "checkout with skipped pincode and detailed address" do
    order = Spree::Order.create!(store: @store)
    Spree::Cart::AddItem.call(order: order, variant: @product1.master, quantity: 2)

    chat = WhatsappChat.create!(phone_number: @phone, state: "idle", cart_id: order.id)

    # Walk to pincode stage
    Whatsapp::ProcessorService.call(@phone, "checkout")
    Whatsapp::ProcessorService.call(@phone, "Alice Smith")
    Whatsapp::ProcessorService.call(@phone, "Delhi")
    Whatsapp::ProcessorService.call(@phone, "Connaught Place")
    
    # Skip pincode
    response = Whatsapp::ProcessorService.call(@phone, "skip")
    assert_match "Connaught Place, Delhi", response
    assert_equal "confirming", chat.reload.state

    # Opt to provide detailed address
    response = Whatsapp::ProcessorService.call(@phone, "address")
    assert_match "detailed shipping address", response
    assert_equal "entering_detailed_address", chat.reload.state

    # Enter detailed address
    response = Whatsapp::ProcessorService.call(@phone, "Block H, 4th Floor")
    assert_match "Block H, 4th Floor, Connaught Place, Delhi", response
    assert_equal "confirming_detailed", chat.reload.state

    # Confirm order
    response = Whatsapp::ProcessorService.call(@phone, "confirm")
    assert_match "placed successfully", response

    order.reload
    assert order.completed?
    assert_equal "Alice", order.ship_address.firstname
    assert_equal "Smith", order.ship_address.lastname
    assert_equal "Block H, 4th Floor, Connaught Place, Delhi", order.ship_address.address1
  end

  test "OrderAutoPlacementJob places order automatically after delay" do
    order = Spree::Order.create!(store: @store)
    Spree::Cart::AddItem.call(order: order, variant: @product1.master, quantity: 4)

    chat = WhatsappChat.create!(
      phone_number: @phone,
      state: "confirming",
      cart_id: order.id,
      updated_at: 20.minutes.ago
    )
    chat.update_metadata("name", "David Warner")
    chat.update_metadata("city", "Mumbai")
    chat.update_metadata("place", "Bandra")
    chat.update_metadata("pincode", "400050")

    Whatsapp::OrderAutoPlacementJob.perform_now(chat.id, order.id)

    chat.reload
    assert_equal "idle", chat.state
    assert_nil chat.cart_id

    order.reload
    assert order.completed?
    assert_equal "David", order.ship_address.firstname
    assert_equal "Warner", order.ship_address.lastname
    assert_equal "Bandra, Mumbai, 400050", order.ship_address.address1
  end
end
