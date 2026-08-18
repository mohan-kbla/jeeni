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
    # Priority 0: Check session override first
    sess = session || Thread.current[:visitor_session]
    if sess.present?
      return true if sess[:visitor_state].to_s.downcase == 'karnataka'
      pincode = sess[:visitor_pincode].to_s.gsub(/\D/, '').strip
      return true if pincode.match?(/\A5[6-9]\d{4}\z/)
    end

    return false if address.nil?

    # Priority 1: State name or abbreviation
    if address.state.present?
      state_name = address.state.name.to_s.downcase.strip
      state_abbr = address.state.abbr.to_s.downcase.strip
      return true if state_name == 'karnataka' || state_abbr == 'ka'
    elsif address.state_name.present?
      state_name = address.state_name.to_s.downcase.strip
      return true if state_name == 'karnataka'
    end

    # Priority 2: Pincode lookup (Karnataka: 56xxxx to 59xxxx)
    pincode = address.zipcode.to_s.gsub(/\D/, '').strip
    return true if pincode.match?(/\A5[6-9]\d{4}\z/)

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
end
