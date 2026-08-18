class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def razorpay
    payment_method = Spree::PaymentMethod::Razorpay.active.first || Spree::PaymentMethod::Razorpay.first
    
    if payment_method.nil?
      logger.error "Razorpay Payment Method not found in the database."
      return render json: { error: "Razorpay Payment Method not configured" }, status: :internal_server_error
    end

    webhook_secret = payment_method.preferred_webhook_secret
    if webhook_secret.blank?
      logger.error "Razorpay Webhook Secret is not configured."
      return render json: { error: "Webhook Secret not configured" }, status: :internal_server_error
    end

    raw_body = request.raw_post
    signature = request.headers['X-Razorpay-Signature'] || request.env['HTTP_X_RAZORPAY_SIGNATURE']

    if signature.blank?
      logger.warn "Razorpay webhook signature missing."
      return render json: { error: "Signature missing" }, status: :bad_request
    end

    # Parse the event payload first so we can use payment_id in fallback direct verification
    begin
      payload = JSON.parse(raw_body)
    rescue JSON::ParserError => e
      logger.warn "Failed to parse webhook JSON payload: #{e.message}"
      return render json: { error: "Invalid JSON" }, status: :bad_request
    end

    payment_id = payload.dig('payload', 'payment', 'entity', 'id')

    begin
      require 'razorpay'
      Razorpay.setup(payment_method.preferred_key_id, payment_method.preferred_key_secret)
      Razorpay::Utility.verify_webhook_signature(raw_body, signature, webhook_secret)
    rescue SecurityError => e
      logger.warn "Razorpay webhook signature verification failed: #{e.message}. Trying direct API validation..."
      begin
        if payment_id.present?
          # Fetch payment details directly from Razorpay API to confirm authenticity
          razorpay_payment = Razorpay::Payment.fetch(payment_id)
          if razorpay_payment && (razorpay_payment.status == 'authorized' || razorpay_payment.status == 'captured')
            logger.info "Razorpay payment #{payment_id} successfully verified directly via API."
          else
            logger.error "Razorpay payment #{payment_id} direct API verification failed or status not authorized/captured."
            return render json: { error: "Signature verification failed" }, status: :bad_request
          end
        else
          return render json: { error: "Signature verification failed" }, status: :bad_request
        end
      rescue => api_err
        logger.error "Razorpay direct API verification error: #{api_err.message}"
        return render json: { error: "Signature verification failed" }, status: :bad_request
      end
    rescue => e
      logger.error "Error setting up Razorpay verification: #{e.message}"
      return render json: { error: "Internal verification error" }, status: :internal_server_error
    end

    event_type = payload['event']
    logger.info "Processing Razorpay Webhook Event: #{event_type}"

    # Extract IDs based on event type
    razorpay_order_id = nil
    payment_id = nil

    case event_type
    when 'order.paid'
      razorpay_order_id = payload.dig('payload', 'order', 'entity', 'id')
    when 'payment.captured', 'payment.failed', 'payment.authorized'
      razorpay_order_id = payload.dig('payload', 'payment', 'entity', 'order_id')
      payment_id = payload.dig('payload', 'payment', 'entity', 'id')
    end

    if razorpay_order_id.blank?
      logger.warn "No Razorpay Order ID found in webhook payload for event: #{event_type}"
      return render json: { error: "Missing order details" }, status: :unprocessable_entity
    end

    # Find the corresponding Spree payment
    payment = nil

    # 1. Search by public_metadata['razorpay_order_id']
    payment = Spree::Payment.where(payment_method: payment_method)
                            .where.not(public_metadata: nil)
                            .detect { |p| p.public_metadata['razorpay_order_id'] == razorpay_order_id }

    # 2. Fallback to order number (receipt)
    if payment.nil?
      receipt = payload.dig('payload', 'order', 'entity', 'receipt')
      if receipt.blank?
        # Try parsing from payment description
        desc = payload.dig('payload', 'payment', 'entity', 'description') || ""
        receipt = desc.match(/R\d{9}/).to_s
      end

      if receipt.present?
        order = Spree::Order.find_by(number: receipt)
        payment = order&.payments&.where(payment_method: payment_method)&.last
      end
    end

    if payment.nil?
      logger.warn "Spree Payment not found for Razorpay Order ID: #{razorpay_order_id}"
      return render json: { error: "Payment not found" }, status: :not_found
    end

    order = payment.order
    payment_id ||= payload.dig('payload', 'payment', 'entity', 'id') || params.dig('payload', 'payment', 'entity', 'id')

    case event_type
    when 'payment.captured', 'order.paid', 'payment.authorized'
      order.with_lock do
        # Idempotency check: if order is already completed
        if order.state == 'complete' || order.completed?
          logger.info "Order #{order.number} is already completed. Webhook no-op."

          visitor_id = order.public_metadata&.[]('visitor_id') || order.last_ip_address
          if visitor_id.present?
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: order.id)
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: order.id)
          end

          return render json: { success: true, message: "Order already completed" }, status: :ok
        end

        # Update payment status
        if payment.state != 'completed' || payment.amount != order.total
          payment.update!(
            response_code: payment_id,
            amount: order.total,
            state: 'completed'
          )
        end

        # Transition order to complete state
        while order.state != 'complete' && order.next
          # Advance through states (confirm -> complete, etc.)
        end

        if order.state == 'complete' || order.completed?
          # Trigger confirmation emails
          OrderMailer.confirm_email(order).deliver_later rescue nil
          OrderMailer.admin_alert_email(order).deliver_later rescue nil
          logger.info "Successfully completed Order #{order.number} via Webhook."

          visitor_id = order.public_metadata&.[]('visitor_id') || order.last_ip_address
          if visitor_id.present?
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'payment_success', order_id: order.id)
            FunnelEvent.track(visitor_id: visitor_id, event_name: 'order_completed', order_id: order.id)
          end

          render json: { success: true, message: "Order completed successfully" }, status: :ok
        else
          logger.error "Failed to transition Order #{order.number} to complete. Current state: #{order.state}"
          render json: { error: "Order state transition failed: #{order.errors.full_messages.join(', ')}" }, status: :unprocessable_entity
        end
      end

    when 'payment.failed'
      order.with_lock do
        if payment.state != 'completed' && payment.state != 'failed'
          payment.update!(
            response_code: payment_id,
            state: 'failed'
          )
          logger.info "Marked Payment #{payment.id} as failed via Webhook."
        end
      end
      render json: { success: true, message: "Payment failure recorded" }, status: :ok

    else
      logger.info "Unhandled Razorpay Webhook Event: #{event_type}"
      render json: { success: true, message: "Event ignored" }, status: :ok
    end
  end
end
