class AdminCustom::AnalyticsController < ApplicationController
  before_action :authorize_admin!
  layout "admin_custom"

  def index
    @date_filter = params[:date_filter] || "today"
    
    case @date_filter
    when "today"
      @start_time = Time.current.beginning_of_day
      @end_time = Time.current.end_of_day
      @date_display = "Today (#{Time.current.strftime('%b %d, %Y')})"
    when "yesterday"
      yesterday = 1.day.ago
      @start_time = yesterday.beginning_of_day
      @end_time = yesterday.end_of_day
      @date_display = "Yesterday (#{yesterday.strftime('%b %d, %Y')})"
    when "custom"
      @start_time = params[:from_date].present? ? Time.zone.parse(params[:from_date]).beginning_of_day : Time.current.beginning_of_day
      @end_time = params[:to_date].present? ? Time.zone.parse(params[:to_date]).end_of_day : Time.current.end_of_day
      @date_display = "#{@start_time.strftime('%b %d, %Y')} to #{@end_time.strftime('%b %d, %Y')}"
    else
      @start_time = Time.current.beginning_of_day
      @end_time = Time.current.end_of_day
      @date_display = "Today (#{Time.current.strftime('%b %d, %Y')})"
    end

    @visits = Visit.where(created_at: @start_time..@end_time)
    @orders_all = Spree::Order.complete.where(created_at: @start_time..@end_time)

    # Summary Cards
    @total_visitors = @visits.count
    @total_orders = @orders_all.count
    @conversion_rate = @total_visitors > 0 ? ((@total_orders.to_f / @total_visitors) * 100).round(2) : 0
    @total_revenue = @orders_all.sum(:total).to_f.round(2)
    @average_order_value = @total_orders > 0 ? (@total_revenue / @total_orders).round(2) : 0

    # Conversion Funnel Metrics & Drop-off Percentages (Scope #18)
    if ActiveRecord::Base.connection.table_exists?(:funnel_events)
      @funnel_events = FunnelEvent.where(created_at: @start_time..@end_time)
      v_views = @funnel_events.where(event_name: 'view_product').select(:visitor_id).distinct.count
      v_clicks = @funnel_events.where(event_name: 'click_easy_booking').select(:visitor_id).distinct.count
      v_checkout = @funnel_events.where(event_name: 'initiate_checkout').select(:visitor_id).distinct.count
      v_address = @funnel_events.where(event_name: 'address_submitted').select(:visitor_id).distinct.count
      v_payment = @funnel_events.where(event_name: 'payment_started').select(:visitor_id).distinct.count

      # Enforce monotonicity to ensure the report always makes sense mathematically
      f_visitors = @total_visitors
      f_views = [v_views, f_visitors].min
      f_clicks = [v_clicks, f_views].min
      f_checkout = [v_checkout, f_clicks].min
      f_address = [v_address, f_checkout].min
      f_payment = [v_payment, f_address].min
      f_completed = [@total_orders, f_payment].min

      @funnel_counts = {
        visitors: f_visitors,
        product_views: f_views,
        easy_booking_clicks: f_clicks,
        checkout_started: f_checkout,
        address_submitted: f_address,
        payment_started: f_payment,
        orders_completed: f_completed
      }

      @funnel_dropoffs = {
        product_views: @funnel_counts[:visitors] > 0 ? ([0, (((@funnel_counts[:visitors] - @funnel_counts[:product_views]).to_f / @funnel_counts[:visitors]) * 100)].max).round(1) : 0,
        easy_booking_clicks: @funnel_counts[:product_views] > 0 ? ([0, (((@funnel_counts[:product_views] - @funnel_counts[:easy_booking_clicks]).to_f / @funnel_counts[:product_views]) * 100)].max).round(1) : 0,
        checkout_started: @funnel_counts[:easy_booking_clicks] > 0 ? ([0, (((@funnel_counts[:easy_booking_clicks] - @funnel_counts[:checkout_started]).to_f / @funnel_counts[:easy_booking_clicks]) * 100)].max).round(1) : 0,
        address_submitted: @funnel_counts[:checkout_started] > 0 ? ([0, (((@funnel_counts[:checkout_started] - @funnel_counts[:address_submitted]).to_f / @funnel_counts[:checkout_started]) * 100)].max).round(1) : 0,
        payment_started: @funnel_counts[:address_submitted] > 0 ? ([0, (((@funnel_counts[:address_submitted] - @funnel_counts[:payment_started]).to_f / @funnel_counts[:address_submitted]) * 100)].max).round(1) : 0,
        orders_completed: @funnel_counts[:payment_started] > 0 ? ([0, (((@funnel_counts[:payment_started] - @funnel_counts[:orders_completed]).to_f / @funnel_counts[:payment_started]) * 100)].max).round(1) : 0
      }
    end


    # Groupings & Trends (Hourly vs Daily)
    if @date_filter == "today" || @date_filter == "yesterday"
      visitors_trend_raw = @visits.group("DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m-%d %H:00:00')").count
      orders_trend_raw = @orders_all.group("DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m-%d %H:00:00')").count

      @visitors_trend = {}
      @orders_trend = {}
      @table_data = []

      (0..23).each do |hour|
        hour_time = @start_time + hour.hours
        key_raw = hour_time.strftime('%Y-%m-%d %H:00:00')
        label = hour_time.strftime('%I %P')
        @visitors_trend[label] = visitors_trend_raw[key_raw] || 0
        @orders_trend[label] = orders_trend_raw[key_raw] || 0

        # Detailed row
        hour_start = hour_time
        hour_end = hour_start + 59.minutes + 59.seconds
        v = @visits.where(created_at: hour_start..hour_end).count
        o = @orders_all.where(created_at: hour_start..hour_end)
        o_count = o.count
        rev = o.sum(:total).to_f.round(2)
        conv = v > 0 ? ((o_count.to_f / v) * 100).round(2) : 0
        @table_data << {
          date: hour_start.strftime("%I:00 %p"),
          visitors: v,
          orders: o_count,
          conversion: conv,
          revenue: rev
        }
      end
    else
      visitors_trend_raw = @visits.group("DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m-%d')").count
      orders_trend_raw = @orders_all.group("DATE_FORMAT(CONVERT_TZ(created_at, '+00:00', '+05:30'), '%Y-%m-%d')").count

      @visitors_trend = {}
      @orders_trend = {}
      @table_data = []

      (@start_time.to_date..@end_time.to_date).each do |date|
        key_raw = date.strftime('%Y-%m-%d')
        label = date.strftime('%b %d')
        @visitors_trend[label] = visitors_trend_raw[key_raw] || 0
        @orders_trend[label] = orders_trend_raw[key_raw] || 0

        # Detailed row
        day_start = date.beginning_of_day
        day_end = date.end_of_day
        v = @visits.where(created_at: day_start..day_end).count
        o = @orders_all.where(created_at: day_start..day_end)
        o_count = o.count
        rev = o.sum(:total).to_f.round(2)
        conv = v > 0 ? ((o_count.to_f / v) * 100).round(2) : 0
        @table_data << {
          date: date.strftime("%b %d, %Y"),
          visitors: v,
          orders: o_count,
          conversion: conv,
          revenue: rev
        }
      end
    end

    @visitors_vs_orders = [
      { name: "Visitors", data: @visitors_trend },
      { name: "Orders", data: @orders_trend }
    ]

    status_raw = @orders_all.group(:state).count
    @order_statuses = status_raw.transform_keys { |k| k.to_s.titleize }

    respond_to do |format|
      format.html
      format.xlsx do
        p = Axlsx::Package.new
        wb = p.workbook
        wb.add_worksheet(name: "Website Analytics") do |sheet|
          title = sheet.styles.add_style(sz: 16, b: true)
          header = sheet.styles.add_style(bg_color: "224229", fg_color: "FFFFFF", b: true)
          
          sheet.add_row ["Website Analytics Report (#{@date_display})"], style: title
          sheet.add_row []
          sheet.add_row ["KPI Summary"]
          sheet.add_row ["Total Visitors", @total_visitors]
          sheet.add_row ["Total Orders", @total_orders]
          sheet.add_row ["Conversion Rate (%)", "#{@conversion_rate}%"]
          sheet.add_row ["Total Revenue (INR)", @total_revenue]
          sheet.add_row ["Average Order Value (INR)", @average_order_value]
          sheet.add_row []
          sheet.add_row ["Detailed Trend Breakdown"]
          sheet.add_row ["Date/Time", "Visitors", "Orders", "Conversion Rate (%)", "Revenue (INR)"], style: header
          @table_data.each do |row|
            sheet.add_row [row[:date], row[:visitors], row[:orders], "#{row[:conversion]}%", row[:revenue]]
          end
        end
        send_data p.to_stream.read, filename: "website_analytics_#{@date_display.parameterize}.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end
      format.pdf do
        pdf = Prawn::Document.new(page_size: "A4", margin: 40)
        pdf.font "Helvetica-Bold"
        pdf.font_size 24
        pdf.text "Website Analytics Report", color: "224229", align: :center
        pdf.font_size 12
        pdf.text @date_display, align: :center, style: :italic
        pdf.move_down 20
        
        pdf.text "Summary KPIs", size: 14, color: "224229"
        pdf.move_down 10
        summary_data = [
          ["Total Visitors", @total_visitors.to_s],
          ["Total Orders", @total_orders.to_s],
          ["Conversion Rate", "#{@conversion_rate}%"],
          ["Total Revenue", "Rs. #{@total_revenue}"],
          ["Average Order Value (AOV)", "Rs. #{@average_order_value}"]
        ]
        pdf.table(summary_data, width: pdf.bounds.width) do
          row(0..-1).borders = [:bottom]
          row(0..-1).border_color = "CCCCCC"
          column(0).font_style = :bold
          column(1).align = :right
        end
        pdf.move_down 30
        
        pdf.text "Detailed Trend Breakdown", size: 14, color: "224229"
        pdf.move_down 10
        table_rows = [["Date/Time", "Visitors", "Orders", "Conversion Rate", "Revenue"]]
        @table_data.each do |row|
          table_rows << [
            row[:date],
            row[:visitors].to_s,
            row[:orders].to_s,
            "#{row[:conversion]}%",
            "Rs. #{row[:revenue]}"
          ]
        end
        pdf.table(table_rows, width: pdf.bounds.width, header: true) do
          row(0).font_style = :bold
          row(0).background_color = "224229"
          row(0).text_color = "FFFFFF"
          column(1..4).align = :right
          self.row_colors = ["FFFFFF", "F9F8F3"]
        end
        
        send_data pdf.render, filename: "website_analytics_#{@date_display.parameterize}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def booking_sources
    @date_filter = params[:date_filter] || "last_7_days"
    
    case @date_filter
    when "today"
      @start_time = Time.current.beginning_of_day
      @end_time = Time.current.end_of_day
      @date_display = "Today (#{Time.current.strftime('%b %d, %Y')})"
    when "yesterday"
      yesterday = 1.day.ago
      @start_time = yesterday.beginning_of_day
      @end_time = yesterday.end_of_day
      @date_display = "Yesterday (#{yesterday.strftime('%b %d, %Y')})"
    when "last_7_days"
      @start_time = 6.days.ago.beginning_of_day
      @end_time = Time.current.end_of_day
      @date_display = "Last 7 Days (#{@start_time.strftime('%b %d')} - #{@end_time.strftime('%b %d, %Y')})"
    when "last_30_days"
      @start_time = 29.days.ago.beginning_of_day
      @end_time = Time.current.end_of_day
      @date_display = "Last 30 Days (#{@start_time.strftime('%b %d')} - #{@end_time.strftime('%b %d, %Y')})"
    when "this_month"
      @start_time = Time.current.beginning_of_month
      @end_time = Time.current.end_of_month
      @date_display = "This Month (#{Time.current.strftime('%B %Y')})"
    when "last_month"
      last_month = 1.month.ago
      @start_time = last_month.beginning_of_month
      @end_time = last_month.end_of_month
      @date_display = "Last Month (#{last_month.strftime('%B %Y')})"
    when "custom"
      @start_time = params[:from_date].present? ? Time.zone.parse(params[:from_date]).beginning_of_day : 6.days.ago.beginning_of_day
      @end_time = params[:to_date].present? ? Time.zone.parse(params[:to_date]).end_of_day : Time.current.end_of_day
      @date_display = "#{@start_time.strftime('%b %d, %Y')} to #{@end_time.strftime('%b %d, %Y')}"
    else
      @start_time = 6.days.ago.beginning_of_day
      @end_time = Time.current.end_of_day
      @date_display = "Last 7 Days (#{@start_time.strftime('%b %d')} - #{@end_time.strftime('%b %d, %Y')})"
    end

    # Core data queries
    @visitor_query = VisitorAttribution.where(created_at: @start_time..@end_time)
    @orders_query = Spree::Order.complete.where(completed_at: @start_time..@end_time)

    # Summary Cards
    @total_visitors = @visitor_query.count
    @total_bookings = @orders_query.count
    @conversion_rate = @total_visitors > 0 ? ((@total_bookings.to_f / @total_visitors) * 100).round(2) : 0
    @total_revenue = @orders_query.sum(:total).to_f.round(2)

    # Groupings & Trends
    @bookings_by_source = @orders_query.group("COALESCE(booking_source, 'Other')").count
    @revenue_by_source = @orders_query.group("COALESCE(booking_source, 'Other')").sum(:total).transform_values { |v| v.to_f.round(2) }
    @orders_by_campaign = @orders_query.where.not(utm_campaign: [nil, ""]).group(:utm_campaign).count
    @orders_by_landing_page = @orders_query.where.not(landing_page: [nil, ""]).group(:landing_page).count
    @orders_by_device = @orders_query.group("COALESCE(device_type, 'Unknown')").count
    @orders_by_state = @orders_query.group("COALESCE(attribution_state, 'Unknown')").count
    @orders_by_city = @orders_query.group("COALESCE(attribution_city, 'Unknown')").count

    # Daily Visitors vs Bookings Trend Chart (IST)
    visitors_trend = @visitor_query.group("DATE(CONVERT_TZ(created_at, '+00:00', '+05:30'))").count
    bookings_trend = @orders_query.group("DATE(CONVERT_TZ(completed_at, '+00:00', '+05:30'))").count

    @visitors_vs_bookings = [
      { name: "Unique Visitors", data: visitors_trend },
      { name: "Bookings", data: bookings_trend }
    ]

    @detailed_orders = @orders_query.order(completed_at: :desc)

    respond_to do |format|
      format.html
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          csv << [
            "Order Number", "Completed At", "Email", "Total (INR)",
            "Booking Source", "UTM Source", "UTM Medium", "UTM Campaign", "UTM Term", "UTM Content",
            "Referrer", "Landing Page", "First Visit Date",
            "Device Type", "Browser", "OS", "IP Address", "Country", "State", "City"
          ]
          @detailed_orders.each do |order|
            csv << [
              order.number,
              order.completed_at&.strftime("%Y-%m-%d %H:%M:%S"),
              order.email,
              order.total.to_f,
              order.booking_source || "Other",
              order.utm_source,
              order.utm_medium,
              order.utm_campaign,
              order.utm_term,
              order.utm_content,
              order.referrer,
              order.landing_page,
              order.first_visit_at&.strftime("%Y-%m-%d %H:%M:%S"),
              order.device_type,
              order.browser,
              order.operating_system,
              order.ip_address,
              order.attribution_country,
              order.attribution_state,
              order.attribution_city
            ]
          end
        end
        send_data csv_data, filename: "booking_sources_report_#{@date_display.parameterize}.csv", type: "text/csv"
      end
      format.xlsx do
        p = Axlsx::Package.new
        wb = p.workbook
        wb.add_worksheet(name: "Attribution Report") do |sheet|
          title = sheet.styles.add_style(sz: 16, b: true)
          header = sheet.styles.add_style(bg_color: "224229", fg_color: "FFFFFF", b: true)
          
          sheet.add_row ["Booking Sources & Attribution Report (#{@date_display})"], style: title
          sheet.add_row []
          
          sheet.add_row ["Summary Metrics"]
          sheet.add_row ["Total Visitors", @total_visitors]
          sheet.add_row ["Total Bookings", @total_bookings]
          sheet.add_row ["Conversion Rate (%)", "#{@conversion_rate}%"]
          sheet.add_row ["Total Revenue (INR)", @total_revenue]
          sheet.add_row []
          
          sheet.add_row [
            "Order Number", "Completed At", "Email", "Total (INR)",
            "Booking Source", "UTM Source", "UTM Medium", "UTM Campaign", "UTM Term", "UTM Content",
            "Referrer", "Landing Page", "First Visit Date",
            "Device Type", "Browser", "OS", "IP Address", "Country", "State", "City"
          ], style: header
          
          @detailed_orders.each do |order|
            sheet.add_row [
              order.number,
              order.completed_at&.strftime("%Y-%m-%d %H:%M:%S"),
              order.email,
              order.total.to_f,
              order.booking_source || "Other",
              order.utm_source,
              order.utm_medium,
              order.utm_campaign,
              order.utm_term,
              order.utm_content,
              order.referrer,
              order.landing_page,
              order.first_visit_at&.strftime("%Y-%m-%d %H:%M:%S"),
              order.device_type,
              order.browser,
              order.operating_system,
              order.ip_address,
              order.attribution_country,
              order.attribution_state,
              order.attribution_city
            ]
          end
        end
        send_data p.to_stream.read, filename: "booking_sources_report_#{@date_display.parameterize}.xlsx", type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      end
    end
  end
end
