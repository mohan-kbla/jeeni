require 'prawn'
require 'prawn/table'

class TrackOrdersController < ApplicationController
  def invoice
    raw_order_number = params[:order_number].to_s.strip.upcase
    verification = params[:verification].to_s.strip

    if raw_order_number.present? && verification.present?
      clean_number = raw_order_number.gsub(/[^A-Z0-9]/, '')

      order = Spree::Order.where("completed_at IS NOT NULL OR state IN ('complete', 'dispatched', 'out_for_delivery', 'delivered')")
                          .where("UPPER(number) = ? OR UPPER(number) = ?", raw_order_number, clean_number)
                          .first

      if order && verify_order_access(order, verification)
        # Generate PDF invoice using Prawn
        pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
        
        # Title & Header
        pdf.font "Helvetica"
        pdf.text "INVOICE", size: 28, style: :bold, color: "333333"
        pdf.stroke_horizontal_rule
        pdf.move_down 20
        
        # Metadata
        pdf.text "Invoice No: INV-#{clean_pdf_text(order.number)}", size: 10, style: :bold
        if order.completed_at
          pdf.text "Date: #{order.completed_at.strftime('%B %d, %Y')}", size: 10
        else
          pdf.text "Date: Pending", size: 10
        end
        pdf.text "Payment: #{clean_pdf_text(order.payments.completed.first&.payment_method&.name || 'Pending')}", size: 10
        
        pdf.move_down 20
        
        # Billing / Shipping details
        pdf.text "Billing Address:", size: 12, style: :bold
        bill = order.bill_address
        if bill
          pdf.text clean_pdf_text("#{bill.full_name}\n#{bill.address1}\n#{bill.city}, #{bill.state&.name || bill.state_name} #{bill.zipcode}\n#{bill.country.name}"), size: 10
        else
          pdf.text "No billing address recorded.", size: 10
        end
        
        pdf.move_down 15
        
        pdf.text "Shipping Address:", size: 12, style: :bold
        ship = order.ship_address
        if ship
          pdf.text clean_pdf_text("#{ship.full_name}\n#{ship.address1}\n#{ship.city}, #{ship.state&.name || ship.state_name} #{ship.zipcode}\n#{ship.country.name}"), size: 10
        else
          pdf.text "No shipping address recorded.", size: 10
        end
        
        pdf.move_down 25
        
        # Items Table Header
        pdf.text "Line Items", size: 14, style: :bold
        pdf.move_down 10
        
        table_data = [["Product", "Sku", "Price", "Qty", "Total"]]
        order.line_items.each do |item|
          table_data << [
            clean_pdf_text(item.product.name),
            clean_pdf_text(item.variant.sku),
            clean_pdf_text(item.single_money.to_s.gsub('₹', 'Rs. ')),
            clean_pdf_text(item.quantity.to_s),
            clean_pdf_text(item.display_amount.to_s.gsub('₹', 'Rs. '))
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
          pdf.text "Subtotal: #{clean_pdf_text(order.display_item_total.to_s.gsub('₹', 'Rs. '))}", size: 10, align: :right
          pdf.text "Shipping: #{clean_pdf_text(order.display_shipment_total.to_s.gsub('₹', 'Rs. '))}", size: 10, align: :right
          pdf.text "Tax: #{clean_pdf_text(order.display_tax_total.to_s.gsub('₹', 'Rs. '))}", size: 10, align: :right
          pdf.move_down 5
          pdf.text "Total: #{clean_pdf_text(order.display_total.to_s.gsub('₹', 'Rs. '))}", size: 12, style: :bold, align: :right, color: "4F46E5"
        end
        
        # Footer details
        pdf.move_down 45
        pdf.stroke_horizontal_line 0, 500
        pdf.move_down 10
        
        pdf.text "Manufacturer & FBO Details:", size: 9, style: :bold, color: "444444"
        pdf.text "Jeevitha Enterprises (Karnataka State)", size: 9, color: "555555"
        pdf.text "Registered Address: No. 343, 6th Cross, J.C. Nagar, Sira Taluk, Tumkur District, Karnataka - 572137", size: 8, color: "777777"
        pdf.text "Customer Care Helpline: +91 76249 31166 / +91 74066 61438 | support@jeenimilletmix.in", size: 8, color: "777777"
        
        # Stream PDF as dynamic attachment download
        send_data pdf.render,
                  filename: "JEENI-Invoice-#{order.number}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      else
        flash[:alert] = "You are not authorized to download this invoice."
        redirect_to root_path
      end
    else
      flash[:alert] = "Missing order number or verification info."
      redirect_to root_path
    end
  end

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

  def clean_pdf_text(text)
    text.to_s.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '').strip
  end

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
