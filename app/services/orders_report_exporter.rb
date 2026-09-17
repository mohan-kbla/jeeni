require 'zip'
require 'nokogiri'

class OrdersReportExporter
  TEMPLATE_PATH = Rails.root.join('lib', 'templates', 'report_gen_template.ods').to_s

  def initialize(from_date, to_date, options = {})
    @from_date = parse_date_start(from_date)
    @to_date = parse_date_end(to_date)
    @options = options || {}
  end

  def valid_range?
    @from_date.present? && @to_date.present? && @from_date <= @to_date
  end

  def orders
    return Spree::Order.none unless valid_range?

    scope = Spree::Order.where("completed_at IS NOT NULL OR state IN ('complete', 'dispatched', 'out_for_delivery', 'delivered')")
                        .where(created_at: @from_date..@to_date)
                        .includes(:ship_address, line_items: { variant: :product }, shipments: :shipping_rates, payments: :payment_method)

    if @options[:order_number].present?
      order_num_query = "%#{@options[:order_number].to_s.strip.upcase}%"
      scope = scope.where("UPPER(spree_orders.number) LIKE ?", order_num_query)
    end

    if @options[:payment_filter].present?
      case @options[:payment_filter].to_s.downcase
      when 'paid', 'razorpay'
        scope = scope.joins(payments: :payment_method)
                     .where("spree_payment_methods.name LIKE '%Razorpay%' OR spree_orders.payment_state = 'paid'")
                     .distinct
      when 'cod'
        scope = scope.joins(payments: :payment_method)
                     .where("spree_payment_methods.name LIKE '%Cash%' OR spree_payment_methods.name LIKE '%Check%' OR spree_payment_methods.name LIKE '%COD%'")
                     .distinct
      end
    end

    scope.order(created_at: :asc)
  end

  def generate_ods
    qualifying_orders = orders
    return nil if qualifying_orders.empty?

    # Read base template zip entries
    entries = {}
    Zip::File.open(TEMPLATE_PATH) do |zip_file|
      zip_file.each do |entry|
        next if entry.directory?
        entries[entry.name] = zip_file.read(entry.name)
      end
    end

    doc = Nokogiri::XML(entries['content.xml'])
    ns = { 'table' => 'urn:oasis:names:tc:opendocument:xmlns:table:1.0',
           'office' => 'urn:oasis:names:tc:opendocument:xmlns:office:1.0',
           'text' => 'urn:oasis:names:tc:opendocument:xmlns:text:1.0' }

    table = doc.at_xpath('//table:table', ns)
    rows = table.xpath('.//table:table-row', ns)

    # Keep Header 1 (row 0) and Header 2 (row 1), remove existing sample data rows
    rows[2..-1].each(&:remove) if rows.length > 2

    # Append row for each order
    qualifying_orders.each do |order|
      row_data = build_row_data(order)
      row_node = Nokogiri::XML::Node.new('table:table-row', doc)

      row_data.each do |val|
        cell = Nokogiri::XML::Node.new('table:table-cell', doc)
        
        if val.is_a?(Numeric)
          cell['office:value-type'] = 'float'
          cell['office:value'] = val.to_s
          p = Nokogiri::XML::Node.new('text:p', doc)
          p.content = val.to_s
          cell.add_child(p)
        else
          str_val = sanitize_string(val.to_s)
          cell['office:value-type'] = 'string'
          p = Nokogiri::XML::Node.new('text:p', doc)
          p.content = str_val
          cell.add_child(p)
        end
        row_node.add_child(cell)
      end

      table.add_child(row_node)
    end

    entries['content.xml'] = doc.to_xml

    # Construct zipped ODS binary buffer
    string_io = Zip::OutputStream.write_buffer do |zip_stream|
      # mimetype must be uncompressed first entry in ODS spec
      if entries.key?('mimetype')
        zip_stream.put_next_entry('mimetype', nil, nil, Zip::Entry::STORED)
        zip_stream.write(entries['mimetype'])
      end

      entries.each do |name, content|
        next if name == 'mimetype'
        zip_stream.put_next_entry(name)
        zip_stream.write(content)
      end
    end

    string_io.string
  end

  private

  def parse_date_start(date_param)
    return nil if date_param.blank?
    Time.zone.parse(date_param).beginning_of_day rescue nil
  end

  def parse_date_end(date_param)
    return nil if date_param.blank?
    parsed = Time.zone.parse(date_param) rescue nil
    return nil unless parsed
    
    # If date input is plain YYYY-MM-DD (10 chars or less), use end_of_day
    if date_param.to_s.length <= 10
      parsed.end_of_day
    else
      parsed
    end
  end

  def sanitize_string(str)
    return "" if str.blank?
    s = str.to_s.strip
    # Prevent spreadsheet formula injection
    if s.start_with?('=', '+', '-', '@')
      "'#{s}"
    else
      s
    end
  end

  def build_row_data(order)
    ship = order.ship_address
    state_name = (ship&.state&.name || ship&.state_name).to_s.strip.upcase
    is_karnataka = state_name.include?('KARNATAKA') || state_name == 'KA'

    # Customer Phone cleaning (remove +91, leading 0, non-digits)
    raw_phone = ship&.phone.to_s
    clean_phone = raw_phone.gsub(/\D/, '').sub(/^91/, '').sub(/^0+/, '')

    # Product Description & Weight
    product_desc, total_weight = build_product_details(order)

    # Financials & Taxes (5% GST included)
    mrp = order.total.to_f
    product_value = (mrp / 1.05).round(2)
    tax_total = (mrp - product_value).round(2)

    if is_karnataka
      cgst = (tax_total / 2.0).round(2)
      sgst = (tax_total / 2.0).round(2)
      igst = 0.0
    else
      cgst = 0.0
      sgst = 0.0
      igst = tax_total
    end

    # Payment / COD check
    is_cod = order.payments.any? { |p| p.payment_method&.name.to_s.match?(/cod|cash|check/i) } ||
             (order.payment_state != 'paid' && !order.payments.any? { |p| p.payment_method&.name.to_s.match?(/razorpay|online|card|upi|netbanking/i) && p.state == 'completed' })
    cod_flag = is_cod ? "YES" : "NO"

    # Dates
    order_time = (order.completed_at || order.created_at).in_time_zone
    date_str = order_time.strftime("%-d/%-m/%Y")

    # Tracking number
    tracking = order.shipments.first&.tracking.presence || order.shipments.first&.number.presence || ""

    [
      tracking,                                                         # 1. Tracking Number
      order.number,                                                     # 2. Client Reference ID
      ship&.full_name || [ship&.firstname, ship&.lastname].compact.join(' ').strip, # 3. Recipient Name
      ship&.address1.to_s.strip,                                        # 4. Address Line 1
      ship&.address2.to_s.strip,                                        # 5. Address Line 2
      ship&.company.to_s.strip,                                         # 6. Landmark
      ship&.city.to_s.strip,                                            # 7. City/Town
      state_name,                                                       # 8. State
      ship&.zipcode.to_s.strip,                                         # 9. Postal Code
      order.email.to_s.strip.presence || order.user&.email.to_s.strip.presence || "jeenienterprise1@gmail.com", # 10. Email Address
      clean_phone,                                                      # 11. Phone Number
      product_desc,                                                     # 12. Product Description
      "Grocery",                                                        # 13. Product Type
      "15",                                                             # 14. Length (in cm)
      "15",                                                             # 15. Width (in cm)
      "20",                                                             # 16. Height (in cm)
      total_weight.to_s,                                                # 17. Gross Weight (in KG)
      "INV-#{order.number}",                                            # 18. Invoice Number
      date_str,                                                         # 19. Invoice Date
      product_value.to_s,                                               # 20. Product Value
      cgst.to_s,                                                        # 21. CGST Value
      sgst.to_s,                                                        # 22. SGST Value
      igst.to_s,                                                        # 23. IGST Value
      cod_flag,                                                         # 24. CollectOnDelivery
      "STANDARD",                                                       # 25. Shipping Service
      date_str,                                                         # 26. Pickup Date
      "17:00",                                                          # 27. Pickup Time
      "",                                                               # 28. Desired delivery date
      "Jeevitha EnterpriseS",                                           # 29. Shipper Name
      "Goragunte Palya",                                                # 30. Ship From Address 1
      "Bangalore",                                                      # 31. Ship From Address 2
      "Bangalore",                                                      # 32. Ship From Address 3
      "Bangalore",                                                      # 33. Ship From City
      "KARNATAKA",                                                      # 34. Ship From State
      "560022",                                                         # 35. Ship From Postal Code
      "jeenionline1166@gmail.com",                                      # 36. Ship From Email
      "6364888412",                                                     # 37. Ship From Phone
      "Goragunte Palya",                                                # 38. Return To Address 1
      "Bangalore",                                                      # 39. Return To Address 2
      "Bangalore",                                                      # 40. Return To Address 3
      "Bangalore",                                                      # 41. Return To City
      "KARNATAKA",                                                      # 42. Return To State
      "560022",                                                         # 43. Return To Postal Code
      "jeenionline1166@gmail.com",                                      # 44. Return To Email
      "6364888412",                                                     # 45. Return To Phone
      mrp.to_s                                                          # 46. MRP
    ]
  end

  def build_product_details(order)
    items = order.line_items
    desc_parts = []
    total_weight = 0.0

    items.each do |item|
      raw_name = item.variant&.product&.name.to_s
      clean_name = raw_name.split('|').first.to_s.strip
      
      # Item description formatting
      if item.quantity > 1
        desc_parts << "#{clean_name} x #{item.quantity}"
      else
        desc_parts << clean_name
      end

      # Weight calculation
      item_w = item.variant&.weight.to_f
      if item_w > 0
        total_weight += item_w * item.quantity
      else
        # Default weight rules if variant weight is unconfigured
        base_w = if clean_name.match?(/coffee|vej|veg/i)
                   0.3
                 else
                   1.0
                 end
        total_weight += base_w * item.quantity
      end
    end

    full_desc = desc_parts.join(" + ")
    full_desc = "Jeeni Products" if full_desc.blank?

    [full_desc, total_weight.round(1)]
  end
end
