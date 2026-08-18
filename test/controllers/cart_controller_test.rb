require "test_helper"

class CartControllerTest < ActionDispatch::IntegrationTest
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

    @product = Spree::Product.find_by(slug: "jeeni-slim-new")
    if @product.nil?
      @product = Spree::Product.new(
        name: "Jeeni Slim Natural Millet Health Mix",
        slug: "jeeni-slim-new",
        price: 500.00,
        shipping_category: @shipping_category,
        available_on: Time.current,
        status: 'active'
      )
      @product.stores << @store
      @product.save!
    end

    stock_item = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: @product.master)
    stock_item.set_count_on_hand(20)
  end

  test "should redirect to checkout and track easy booking click event" do
    assert_difference "FunnelEvent.where(event_name: 'click_easy_booking').count", 1 do
      post "/cart/add", params: { variant_id: @product.master.id, quantity: 1, checkout: '1' }
    end
    assert_redirected_to "/checkout"
  end

  test "should redirect to cart and not track easy booking click event on standard cart addition" do
    assert_no_difference "FunnelEvent.where(event_name: 'click_easy_booking').count" do
      post "/cart/add", params: { variant_id: @product.master.id, quantity: 1 }
    end
    assert_redirected_to "/cart"
  end

  test "Buy Now checkout should be idempotent and not accumulate quantity on duplicate calls" do
    post "/cart/add", params: { variant_id: @product.master.id, quantity: 1, checkout: '1' }
    assert_redirected_to "/checkout"
    
    order = Spree::Order.last
    assert_equal 1, order.line_items.find_by(variant_id: @product.master.id).quantity
    
    # Duplicate post should keep quantity at 1 instead of accumulating to 2
    post "/cart/add", params: { variant_id: @product.master.id, quantity: 1, checkout: '1' }
    assert_redirected_to "/checkout"
    
    order.reload
    assert_equal 1, order.line_items.find_by(variant_id: @product.master.id).quantity
  end

  test "should be able to add Vegetable Cofpee to cart alone at normal price" do
    gift_product = Spree::Product.find_by(slug: "vegetable-cofpee")
    if gift_product.nil?
      gift_product = Spree::Product.new(
        name: "Jeeni Vegetable Cofpee",
        slug: "vegetable-cofpee",
        price: 299.00,
        shipping_category: @shipping_category,
        available_on: Time.current,
        status: 'active'
      )
      gift_product.stores << @store
      gift_product.save!
    end
    stock_item_gift = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: gift_product.master)
    stock_item_gift.set_count_on_hand(20)

    post "/cart/add", params: { variant_id: gift_product.master.id, quantity: 1 }
    assert_redirected_to "/cart"
    
    order = Spree::Order.last
    assert order.present?
    
    line_item = order.line_items.find_by(variant_id: gift_product.master.id)
    assert line_item.present?, "Vegetable Cofpee should be present in the cart"
    assert_equal 299.00, line_item.price.to_f, "Vegetable Cofpee price should be its normal price"
  end

  test "Vegetable Cofpee is not added to cart by default but is added for online payment and not for COD" do
    gift_product = Spree::Product.find_by(slug: "vegetable-cofpee")
    if gift_product.nil?
      gift_product = Spree::Product.new(
        name: "Jeeni Vegetable Cofpee",
        slug: "vegetable-cofpee",
        price: 299.00,
        shipping_category: @shipping_category,
        available_on: Time.current,
        status: 'active'
      )
      gift_product.stores << @store
      gift_product.save!
    end
    stock_item_gift = Spree::StockItem.find_or_create_by!(stock_location: @stock_location, variant: gift_product.master)
    stock_item_gift.set_count_on_hand(20)

    # 1. Add eligible product
    post "/cart/add", params: { variant_id: @product.master.id, quantity: 1 }
    assert_redirected_to "/cart"

    order = Spree::Order.last
    order.reload

    # Check that gift is NOT added automatically by default in cart
    gift_line_item = order.line_items.find_by(variant_id: gift_product.master.id)
    assert_nil gift_line_item, "Free gift should not be added to cart by default"

    # 2. Simulate selecting Razorpay (Online payment)
    PromotionService.apply_promotions!(order, "razorpay")
    order.reload
    gift_line_item = order.line_items.find_by(variant_id: gift_product.master.id)
    assert gift_line_item.present?, "Free gift should be added for online payment"
    assert_equal 0.0, gift_line_item.price.to_f, "Free gift price should be 0.0"

    # 3. Simulate selecting COD
    cod_method = Spree::PaymentMethod::Check.find_or_initialize_by(name: "Cash on Delivery")
    cod_method.active = true
    cod_method.stores << @store unless cod_method.stores.include?(@store)
    cod_method.save!
    
    # Apply promotions with COD method
    PromotionService.apply_promotions!(order, "cod")
    order.reload

    # Check that gift is removed
    assert_nil order.line_items.find_by(variant_id: gift_product.master.id), "Free gift should be removed for COD payment method"
  end
end