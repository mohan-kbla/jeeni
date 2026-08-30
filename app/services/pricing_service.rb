class PricingService
  def self.calculate(variant, order_or_address, session = nil)
    address = get_address(order_or_address)
    if is_karnataka?(address, session)
      variant.karnataka_price.present? ? variant.karnataka_price : variant.price
    else
      variant.price
    end
  end

  def self.is_karnataka?(address, session = nil)
    # Priority 1: Check shipping address first if we have state or pincode details
    if address.present?
      has_state = false
      if address.state.present?
        has_state = true
        state_name = address.state.name.to_s.downcase.strip
        state_abbr = address.state.abbr.to_s.downcase.strip
        return true if state_name == 'karnataka' || state_abbr == 'ka'
      elsif address.state_name.present?
        has_state = true
        state_name = address.state_name.to_s.downcase.strip
        return true if state_name == 'karnataka'
      end

      pincode = address.zipcode.to_s.gsub(/\D/, '').strip
      if pincode.present?
        return true if pincode.match?(/\A5[6-9]\d{4}\z/)
        # If pincode is entered but it doesn't match Karnataka, and no state overrides it
        return false
      elsif has_state
        # If state is set but it wasn't Karnataka, and no pincode overrides it
        return false
      end
    end

    # Priority 2: Fall back to session override if address is not present or doesn't have details
    sess = session || Thread.current[:visitor_session]
    if sess.present?
      return true if sess[:visitor_state].to_s.downcase == 'karnataka'
      pincode = sess[:visitor_pincode].to_s.gsub(/\D/, '').strip
      return true if pincode.match?(/\A5[6-9]\d{4}\z/)
    end

    false
  end

  private

  def self.get_address(order_or_address)
    if order_or_address.is_a?(Spree::Address)
      order_or_address
    elsif order_or_address.respond_to?(:ship_address) && order_or_address.ship_address.present?
      order_or_address.ship_address
    elsif order_or_address.respond_to?(:bill_address) && order_or_address.bill_address.present?
      order_or_address.bill_address
    else
      nil
    end
  end

  def self.state_by_pincode(pincode)
    pincode = pincode.to_s.gsub(/\D/, '').strip
    return nil if pincode.length != 6
    
    prefix = pincode[0..1]
    abbr = case prefix
    when '11' then 'DL'
    when '12', '13' then 'HR'
    when '14', '15' then 'PB'
    when '16' then 'CH'
    when '17' then 'HP'
    when '18', '19' then 'JK'
    when '20', '21', '22', '23', '24', '25', '26', '27', '28' then 'UP'
    when '30', '31', '32', '33', '34' then 'RJ'
    when '36', '37', '38', '39' then 'GJ'
    when '40', '41', '42', '43', '44' then 'MH'
    when '45', '46', '47', '48' then 'MP'
    when '49' then 'CT'
    when '50', '51', '52', '53' then 'AP'
    when '56', '57', '58', '59' then 'KA'
    when '60', '61', '62', '63', '64' then 'TN'
    when '67', '68', '69' then 'KL'
    when '70', '71', '72', '73', '74' then 'WB'
    when '75', '76', '77' then 'OR'
    when '78' then 'AS'
    when '79' then 'ML'
    when '80', '81', '82', '83', '84', '85' then 'BR'
    else nil
    end

    if abbr.present?
      Spree::State.find_by(abbr: abbr)
    else
      nil
    end
  end

  def self.detect_state(pincode: nil, state_name: nil, city_name: nil)
    # 1. Try to find state by pincode
    if pincode.present?
      state_obj = state_by_pincode(pincode)
      return state_obj if state_obj.present?
    end

    india = Spree::Country.find_by(iso: "IN") || Spree::Country.default

    # 2. Try to find state by state name
    if state_name.present?
      state_obj = Spree::State.where(country: india).where("LOWER(name) = ? OR LOWER(abbr) = ?", state_name.to_s.downcase.strip, state_name.to_s.downcase.strip).first
      return state_obj if state_obj.present?
    end

    # 3. Try to find state by city name
    if city_name.present?
      state_obj = Spree::State.where(country: india).where("LOWER(name) = ? OR LOWER(abbr) = ?", city_name.to_s.downcase.strip, city_name.to_s.downcase.strip).first
      return state_obj if state_obj.present?
    end

    nil
  end
end
