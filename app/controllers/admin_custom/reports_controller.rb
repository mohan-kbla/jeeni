require 'csv'
require 'prawn'

class AdminCustom::ReportsController < ApplicationController
  before_action :authorize_admin!
  layout "admin_custom"

  def index
    # Load lookup tables for filters
    @payment_methods = Spree::PaymentMethod.all.order(name: :asc)
    @products = Spree::Product.all.order(name: :asc)
    @order_statuses = Spree::Order.complete.pluck(:state).uniq.compact

    # Apply filters
    filtered_orders = apply_filters(Spree::Order.complete)

    # 1. Sales Revenue Grouped by Day (MySQL DATE format, converted to IST)
    @sales_by_day = filtered_orders
                      .group(Arel.sql("DATE(CONVERT_TZ(completed_at, '+00:00', '+05:30'))"))
                      .order(Arel.sql("DATE(CONVERT_TZ(completed_at, '+00:00', '+05:30')) ASC"))
                      .sum(:total)

    # 2. Sales Revenue Grouped by State (Geographical)
    @sales_by_state = filtered_orders
                        .joins(:bill_address)
                        .joins("LEFT JOIN spree_states ON spree_addresses.state_id = spree_states.id")
                        .group("COALESCE(spree_states.name, spree_addresses.state_name)")
                        .sum(:total)

    # 3. Product Sales Quantity (Volume)
    filtered_order_ids = filtered_orders.pluck(:id)
    @sales_by_product = Spree::LineItem.joins(:order, :variant)
                                       .joins("INNER JOIN spree_products ON spree_variants.product_id = spree_products.id")
                                       .where(order_id: filtered_order_ids)
                                       .group("spree_products.name")
                                       .sum("spree_line_items.quantity")

    # Load paginated list of records
    @orders = filtered_orders.includes(:ship_address, :bill_address, line_items: [:product, :variant]).order(completed_at: :desc).page(params[:page]).per(15)
  end

  def export
    format = params[:format]
    orders = apply_filters(Spree::Order.complete).includes(:ship_address, :bill_address, line_items: [:product, :variant]).order(completed_at: :desc)

    case format
    when "csv"
      csv_data = CSV.generate(headers: true) do |csv|
        csv << ["Order Date", "Customer name", "Phone no", "Total amount", "Product", "Address"]
        orders.each do |order|
          addr = order.ship_address || order.bill_address
          addr_str = addr ? [addr.full_name, addr.address1, addr.address2, addr.city, addr.state&.name || addr.state_name, addr.zipcode, addr.country&.name].reject(&:blank?).join(", ") : ""
          prod_str = order.line_items.map { |li| "#{li.product&.name || li.variant&.name} (x#{li.quantity})" }.join(", ")

          csv << [
            order.completed_at&.in_time_zone('Kolkata')&.strftime("%Y-%m-%d") || "",
            order.ship_address&.full_name || order.bill_address&.full_name || "",
            order.ship_address&.phone || order.bill_address&.phone || "",
            order.total.to_f,
            prod_str,
            addr_str
          ]
        end
      end
      send_data csv_data, filename: "orders-report-#{Time.current.to_i}.csv", type: "text/csv"
      
    when "excel"
      p = Axlsx::Package.new
      p.workbook.add_worksheet(name: "Orders Report") do |sheet|
        sheet.add_row ["Order Date", "Customer name", "Phone no", "Total amount", "Product", "Address"]
        orders.each do |order|
          addr = order.ship_address || order.bill_address
          addr_str = addr ? [addr.full_name, addr.address1, addr.address2, addr.city, addr.state&.name || addr.state_name, addr.zipcode, addr.country&.name].reject(&:blank?).join(", ") : ""
          prod_str = order.line_items.map { |li| "#{li.product&.name || li.variant&.name} (x#{li.quantity})" }.join(", ")

          sheet.add_row [
            order.completed_at&.in_time_zone('Kolkata')&.strftime("%Y-%m-%d") || "",
            order.ship_address&.full_name || order.bill_address&.full_name || "",
            order.ship_address&.phone || order.bill_address&.phone || "",
            order.total.to_f,
            prod_str,
            addr_str
          ]
        end
      end
      send_data p.to_stream.read, filename: "orders-report-#{Time.current.to_i}.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      
    when "pdf"
      pdf = Prawn::Document.new(page_size: 'A4', margin: 40)
      pdf.font "Helvetica"
      
      pdf.text "EXECUTIVE SALES REPORT", size: 24, style: :bold, color: "333333"
      pdf.text "Generated on: #{Time.current.strftime('%B %d, %Y at %I:%M %p')}", size: 10, color: "666666"
      pdf.stroke_horizontal_rule
      pdf.move_down 20

      # Summary KPI Metrics
      total_revenue = orders.sum(:total)
      pdf.text "Total Completed Sales Revenue: #{Spree::Money.new(total_revenue).to_s.gsub('₹', 'Rs. ')}", size: 12, style: :bold
      pdf.text "Total Order Count: #{orders.count}", size: 12
      pdf.move_down 20

      # Table details
      table_data = [["Order No", "Date", "Customer", "Payment", "Shipment", "Total"]]
      orders.each do |order|
        table_data << [
          order.number,
          order.completed_at.strftime("%Y-%m-%d"),
          order.email,
          order.payment_state || "Pending",
          order.shipment_state || "Pending",
          order.display_total.to_s.gsub('₹', 'Rs. ')
        ]
      end

      pdf.table(table_data, header: true, width: 510) do
        row(0).style(background_color: 'E2E8F0', font_style: :bold)
        cells.style(borders: [:bottom], border_color: 'CBD5E1', padding: 6, size: 8)
      end

      send_data pdf.render, filename: "orders-report-#{Time.current.to_i}.pdf", type: "application/pdf", disposition: "inline"
    else
      flash[:alert] = "Invalid format request."
      redirect_to admin_custom_reports_path
    end
  end

  private

  def apply_filters(relation)
    # 1. Filter by From Date (datetime-local YYYY-MM-DDTHH:MM)
    if params[:from_date].present?
      begin
        from_time = Time.zone.parse(params[:from_date])
        relation = relation.where("spree_orders.completed_at >= ?", from_time)
      rescue => e
        Rails.logger.error "Error parsing from_date: #{e.message}"
      end
    end

    # 2. Filter by To Date (datetime-local YYYY-MM-DDTHH:MM)
    if params[:to_date].present?
      begin
        to_time = Time.zone.parse(params[:to_date])
        relation = relation.where("spree_orders.completed_at <= ?", to_time)
      rescue => e
        Rails.logger.error "Error parsing to_date: #{e.message}"
      end
    end

    # 3. Filter by Order Status (state)
    if params[:order_status].present?
      relation = relation.where(state: params[:order_status])
    end

    # 4. Filter by Payment Method (via subquery on order IDs)
    if params[:payment_method_id].present?
      order_ids_by_pm = Spree::Payment.where(payment_method_id: params[:payment_method_id]).pluck(:order_id)
      relation = relation.where(id: order_ids_by_pm)
    end

    # 5. Filter by Product (via subquery on order IDs)
    if params[:product_id].present?
      order_ids_by_prod = Spree::LineItem.joins(:variant).where(spree_variants: { product_id: params[:product_id] }).pluck(:order_id)
      relation = relation.where(id: order_ids_by_prod)
    end

    relation
  end
end
