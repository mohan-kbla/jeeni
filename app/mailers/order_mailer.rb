class OrderMailer < ApplicationMailer
  default from: "store@example.com"

  def confirm_email(order)
    @order = order
    mail(to: @order.email, subject: "Order Confirmation - ##{@order.number}")
  end

  def shipment_email(order)
    @order = order
    mail(to: @order.email, subject: "Your Shipment is on the Way! - ##{@order.number}")
  end

  def cancelled_email(order)
    @order = order
    mail(to: @order.email, subject: "Order Cancelled - ##{@order.number}")
  end

  def admin_alert_email(order)
    @order = order
    mail(to: "admin@example.com", subject: "ALERT: New Order Received - ##{@order.number}")
  end
end
