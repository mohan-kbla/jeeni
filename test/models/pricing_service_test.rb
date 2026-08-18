require "test_helper"

class PricingServiceTest < ActiveSupport::TestCase
  setup do
    store = Spree::Store.first
    if store.nil?
      store = Spree::Store.new(
        name: "Jeeni Shop",
        code: "spree",
        url: "jeenimilletmix.in",
        mail_from_address: "info@jeenimilletmix.in",
        default_currency: "INR"
      )
      store.save(validate: false)
    end

    shipping_category = Spree::ShippingCategory.first_or_create!(name: "Default")
    @product = Spree::Product.new(
      name: "Test Product",
      price: 1899.00,
      shipping_category: shipping_category
    )
    @product.stores << store
    @product.save!

    @variant = @product.master
    @variant.update!(karnataka_price: 1575.00)
    
    @country = Spree::Country.find_or_create_by!(name: "India") do |c|
      c.iso_name = "INDIA"
      c.iso = "IN"
      c.iso3 = "IND"
    end

    @karnataka_state = Spree::State.find_or_create_by!(name: "Karnataka", abbr: "KA") do |state|
      state.country = @country
    end
    
    @other_state = Spree::State.find_or_create_by!(name: "Tamil Nadu", abbr: "TN") do |state|
      state.country = @country
    end
  end

  test "is_karnataka? returns true for Karnataka state name" do
    address = Spree::Address.new(state: @karnataka_state, zipcode: "600001")
    assert PricingService.is_karnataka?(address)
  end

  test "is_karnataka? returns true for Karnataka state abbreviation" do
    address = Spree::Address.new(state: Spree::State.new(name: "KA", abbr: "KA"), zipcode: "600001")
    assert PricingService.is_karnataka?(address)
  end

  test "is_karnataka? returns true for Karnataka state_name string" do
    address = Spree::Address.new(state_name: "Karnataka", zipcode: "600001")
    assert PricingService.is_karnataka?(address)
  end

  test "is_karnataka? returns true for Karnataka pincode range (56xxxx to 59xxxx)" do
    # Bangalore pincode
    address = Spree::Address.new(state: @other_state, zipcode: "560001")
    assert PricingService.is_karnataka?(address)
    
    # Hubli pincode
    address2 = Spree::Address.new(state: @other_state, zipcode: "580020")
    assert PricingService.is_karnataka?(address2)
  end

  test "is_karnataka? returns false for other states and non-Karnataka pincodes" do
    address = Spree::Address.new(state: @other_state, zipcode: "600001")
    assert_not PricingService.is_karnataka?(address)
  end

  test "calculate returns karnataka_price if visitor is from Karnataka" do
    address = Spree::Address.new(state: @karnataka_state, zipcode: "560001")
    assert_equal 1575.00, PricingService.calculate(@variant, address).to_f
  end

  test "calculate returns default price if visitor is from another state" do
    address = Spree::Address.new(state: @other_state, zipcode: "600001")
    assert_equal 1899.00, PricingService.calculate(@variant, address).to_f
  end

  test "calculate falls back to default price if karnataka_price is nil" do
    @variant.update!(karnataka_price: nil)
    address = Spree::Address.new(state: @karnataka_state, zipcode: "560001")
    assert_equal 1899.00, PricingService.calculate(@variant, address).to_f
  end

  test "price validation: karnataka_price cannot exceed default price" do
    price_record = @variant.default_price
    price_record.karnataka_price = 2000.00
    assert_not price_record.valid?
    assert_includes price_record.errors[:karnataka_price], "cannot be greater than Default Price"
  end
end
