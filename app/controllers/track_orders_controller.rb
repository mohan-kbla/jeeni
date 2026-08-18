class TrackOrdersController < ApplicationController
  def show
    raw_order_number = params[:order_number].to_s.strip.upcase
    @order_number = raw_order_number
    @verification = params[:verification].to_s.strip

    if raw_order_number.present? && @verification.present?
      # Strip non-alphanumeric characters (e.g. leading '#' symbol like #R464013369)
      clean_number = raw_order_number.gsub(/[^A-Z0-9]/, '')

      # Find order using Order Number (case-insensitive)
      order = Spree::Order.where("completed_at IS NOT NULL OR state IN ('complete', 'dispatched', 'out_for_delivery', 'delivered')")
                          .where("UPPER(number) = ? OR UPPER(number) = ?", raw_order_number, clean_number)
                          .first

      if order && verify_order_access(order, @verification)
        @order = order
        @current_step = calculate_tracker_step(order)
      else
        @error = "Order not found. Please check your Order Number and Email/Mobile."
      end
    elsif raw_order_number.present? && @verification.blank?
      @info = "Please enter your Email or Mobile Number to track your order."
    elsif params[:commit].present? || params[:verification].present?
      @error = "Order not found. Please check your Order Number and Email/Mobile."
    end
  end

  private

  def verify_order_access(order, verification)
    input_clean = verification.downcase.strip
    input_digits = verification.gsub(/\D/, '')

    # 1. Match Email (Order email)
    if order.email.present? && order.email.to_s.downcase.strip == input_clean
      return true
    end

    # 2. Match Mobile / Phone Number
    if input_digits.length >= 7
      phones = [
        order.ship_address&.phone,
        order.bill_address&.phone
      ].compact.map { |p| p.to_s.gsub(/\D/, '') }

      phones.each do |phone_digits|
        next if phone_digits.blank?
        if phone_digits == input_digits ||
           (phone_digits.length >= 10 && input_digits.length >= 10 && phone_digits.last(10) == input_digits.last(10)) ||
           phone_digits.end_with?(input_digits) || input_digits.end_with?(phone_digits)
          return true
        end
      end
    end

    false
  end

  def calculate_tracker_step(order)
    return 0 if order.state == 'canceled' || order.state == 'returned'

    case order.state
    when 'delivered'
      6
    when 'out_for_delivery'
      5
    when 'dispatched'
      4
    when 'processing'
      3
    when 'payment_confirm', 'confirm'
      2
    else
      if order.shipment_state == 'shipped'
        4
      elsif order.shipment_state == 'ready'
        3
      elsif order.payment_state == 'paid' || order.state == 'complete'
        2
      else
        1
      end
    end
  end
end
