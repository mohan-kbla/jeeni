class Spree::PaymentMethod::Razorpay < Spree::PaymentMethod
  preference :key_id, :string
  preference :key_secret, :string
  preference :webhook_secret, :string

  def actions
    %w{capture void}
  end

  # Indicates whether it is possible to capture the payment
  def can_capture?(payment)
    ['checkout', 'pending'].include?(payment.state)
  end

  # Indicates whether it is possible to void the payment
  def can_void?(payment)
    payment.state != 'void'
  end

  def capture(*args)
    ActiveMerchant::Billing::Response.new(true, 'Razorpay payment captured', {}, {})
  end

  def source_required?
    false
  end
end
