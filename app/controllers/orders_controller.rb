require 'prawn'
require 'prawn/table'

class OrdersController < ApplicationController
  before_action :authenticate_spree_user!, only: [:index]
  before_action :set_order, only: [:show, :invoice]

  def index
    # Load all complete orders for the current user
    @orders = spree_current_user.orders.complete.order(completed_at: :desc)
  end

  def show
    # Renders order details view
    # Track purchase if order is completed, completed in the last 15 minutes, and not already tracked in this session
    if @order.completed? && @order.completed_at > 15.minutes.ago && !session[:purchase_tracked_orders]&.include?(@order.number)
      @track_purchase = true
      session[:purchase_tracked_orders] ||= []
      session[:purchase_tracked_orders] << @order.number

      # Record order_completed funnel event
      visitor_id = cookies[:visitor_id] || @order.last_ip_address
      if visitor_id.present?
        FunnelEvent.track(
          visitor_id: visitor_id,
          event_name: 'order_completed',
          order_id: @order.id,
          path: request.path
        )
      end
    end
  end

  def invoice
    # Generate PDF invoice using Prawn
    pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
    
    # Title & Header
    pdf.font "Helvetica"
    pdf.text "INVOICE", size: 28, style: :bold, color: "333333"
    pdf.stroke_horizontal_rule
    pdf.move_down 20
    
    # Metadata
    pdf.text "Invoice No: INV-#{@order.number}", size: 10, style: :bold
    if @order.completed_at
      pdf.text "Date: #{@order.completed_at.strftime('%B %d, %Y')}", size: 10
    else
      pdf.text "Date: Pending", size: 10
    end
    pdf.text "Payment: #{@order.payments.completed.first&.payment_method&.name || 'Pending'}", size: 10
    
    pdf.move_down 20
    
    # Billing / Shipping details
    pdf.text "Billing Address:", size: 12, style: :bold
    bill = @order.bill_address
    pdf.text "#{bill.full_name}\n#{ba = bill.address1}\n#{bill.city}, #{bill.state&.name || bill.state_name} #{bill.zipcode}\n#{bill.country.name}", size: 10
    
    pdf.move_down 15
    
    pdf.text "Shipping Address:", size: 12, style: :bold
    ship = @order.ship_address
    pdf.text "#{ship.full_name}\n#{ship.address1}\n#{ship.city}, #{ship.state&.name || ship.state_name} #{ship.zipcode}\n#{ship.country.name}", size: 10
    
    pdf.move_down 25
    
    # Items Table Header
    pdf.text "Line Items", size: 14, style: :bold
    pdf.move_down 10
    
    table_data = [["Product", "Sku", "Price", "Qty", "Total"]]
    @order.line_items.each do |item|
      table_data << [
        item.product.name,
        item.variant.sku,
        item.single_money.to_s.gsub('₹', 'Rs. '),
        item.quantity.to_s,
        item.display_amount.to_s.gsub('₹', 'Rs. ')
      ]
    end
    
    # Draw table
    pdf.table(table_data, header: true, width: 500) do
      row(0).style(background_color: 'F1F5F9', font_style: :bold)
      cells.style(borders: [:bottom], border_color: 'E2E8F0', padding: 8, size: 9)
    end
    
    pdf.move_down 30
    
    # Totals section
    pdf.bounding_box([320, pdf.cursor], width: 180) do
      pdf.text "Subtotal: #{@order.display_item_total.to_s.gsub('₹', 'Rs. ')}", size: 10, align: :right
      pdf.text "Shipping: #{@order.display_shipment_total.to_s.gsub('₹', 'Rs. ')}", size: 10, align: :right
      pdf.text "Tax: #{@order.display_tax_total.to_s.gsub('₹', 'Rs. ')}", size: 10, align: :right
      pdf.move_down 5
      pdf.text "Total: #{@order.display_total.to_s.gsub('₹', 'Rs. ')}", size: 12, style: :bold, align: :right, color: "4F46E5"
    end
    
    # FSSAI footer
    pdf.move_down 45
    pdf.stroke_horizontal_line 0, 500
    pdf.move_down 10
    
    pdf.text "Food Business Operator (FBO) Details:", size: 9, style: :bold, color: "444444"
    pdf.text "Jeevitha Enterprises | FSSAI License Number: 11220327000212 (Karnataka State)", size: 9, color: "555555"
    pdf.text "Registered Address: No. 343, 6th Cross, J.C. Nagar, Sira Taluk, Tumkur District, Karnataka - 572137", size: 8, color: "777777"
    pdf.text "Customer Care Helpline: +91 76249 31166 / +91 74066 61438 | support@jeenimilletmix.in", size: 8, color: "777777"
    
    # Stream PDF
    send_data pdf.render,
              filename: "invoice-#{@order.number}.pdf",
              type: "application/pdf",
              disposition: "inline"
  end

  private

  def set_order
    @order = Spree::Order.complete.find_by!(number: params[:id])

    # Authorize access: User must own the order, or have the matching guest token cookie, or session flag
    authorized = false
    if spree_current_user
      authorized = (@order.user_id == spree_current_user.id)
    else
      authorized = (@order.token == cookies.signed[:token] || session[:meta_pixel_purchase_order_id] == @order.id)
    end

    unless authorized
      flash[:alert] = "You are not authorized to view this page."
      redirect_to root_path
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Order not found."
    redirect_to root_path
  end
end
