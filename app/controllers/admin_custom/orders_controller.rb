class AdminCustom::OrdersController < ApplicationController
  before_action :authorize_admin!
  before_action :set_order, only: [:show, :update, :update_status]
  layout "admin_custom"

  def index
    # Load all completed orders, paginated
    @orders = Spree::Order.complete.includes(:user)
    @products = Spree::Product.all.order(:name)

    # Filter by product if specified
    if params[:product_id].present?
      @orders = @orders.joins(line_items: :variant).where(spree_variants: { product_id: params[:product_id] }).distinct
    end

    # Filter by customer name if specified
    if params[:customer_name].present?
      name_query = "%#{params[:customer_name].strip}%"
      @orders = @orders.left_outer_joins(:ship_address)
                       .where("LOWER(spree_addresses.firstname) LIKE LOWER(?) OR LOWER(spree_addresses.lastname) LIKE LOWER(?) OR LOWER(CONCAT(spree_addresses.firstname, ' ', spree_addresses.lastname)) LIKE LOWER(?)", name_query, name_query, name_query)
    end

    # Filter by phone number if specified
    if params[:phone_number].present?
      phone_query = "%#{params[:phone_number].strip}%"
      @orders = @orders.left_outer_joins(:ship_address)
                       .where("spree_addresses.phone LIKE ?", phone_query)
    end

    # Filter by Order Number if specified
    if params[:order_number].present?
      order_num_query = "%#{params[:order_number].strip.upcase}%"
      @orders = @orders.where("UPPER(spree_orders.number) LIKE ?", order_num_query)
    end

    # Filter by Payment Method / Status if specified
    if params[:payment_filter].present?
      case params[:payment_filter]
      when 'paid', 'razorpay'
        @orders = @orders.joins(payments: :payment_method)
                         .where("spree_payment_methods.name LIKE '%Razorpay%' OR spree_orders.payment_state = 'paid'")
                         .distinct
      when 'cod'
        @orders = @orders.joins(payments: :payment_method)
                         .where("spree_payment_methods.name LIKE '%Cash%' OR spree_payment_methods.name LIKE '%Check%' OR spree_payment_methods.name LIKE '%COD%'")
                         .distinct
      end
    end

    if params[:date_filter] == "today"
      @orders = @orders.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
    elsif params[:date_filter] == "yesterday"
      yesterday = 1.day.ago
      @orders = @orders.where(created_at: yesterday.beginning_of_day..yesterday.end_of_day)
    elsif params[:date_filter] == "custom"
      if params[:from_date].present? || params[:to_date].present?
        from_time = if params[:from_date].present?
                      Time.zone.parse(params[:from_date]) rescue Time.zone.at(0)
                    else
                      Time.zone.at(0)
                    end
        to_time = if params[:to_date].present?
                    parsed_to = Time.zone.parse(params[:to_date]) rescue Time.current.end_of_day
                    if params[:to_date].length <= 10
                      parsed_to.end_of_day
                    else
                      parsed_to
                    end
                  else
                    Time.current.end_of_day
                  end
        @orders = @orders.where(created_at: from_time..to_time)
      end
    end

    @orders = @orders.order(completed_at: :desc).page(params[:page]).per(15)
  end

  def export_report
    from_date_str = params[:from_date].presence
    to_date_str = params[:to_date].presence

    if params[:date_filter] == 'today'
      from_date_str = Time.current.to_date.to_s
      to_date_str = Time.current.to_date.to_s
    elsif params[:date_filter] == 'yesterday'
      from_date_str = 1.day.ago.to_date.to_s
      to_date_str = 1.day.ago.to_date.to_s
    end

    permit_params = params.permit(:date_filter, :from_date, :to_date, :product_id, :customer_name, :phone_number, :order_number, :payment_filter)

    if from_date_str.blank? || to_date_str.blank?
      flash[:alert] = "Please select both From Date and To Date to extract the report."
      redirect_to admin_custom_orders_path(permit_params)
      return
    end

    exporter = OrdersReportExporter.new(from_date_str, to_date_str, order_number: params[:order_number], payment_filter: params[:payment_filter])

    unless exporter.valid_range?
      flash[:alert] = "Invalid date range. To Date cannot be earlier than From Date."
      redirect_to admin_custom_orders_path(permit_params)
      return
    end

    if exporter.orders.empty?
      flash[:alert] = "No orders found for the selected date range (#{from_date_str[0..9]} to #{to_date_str[0..9]})."
      redirect_to admin_custom_orders_path(permit_params)
      return
    end

    ods_data = exporter.generate_ods
    if ods_data.present?
      filename = "jeeni_orders_report_#{from_date_str[0..9]}_to_#{to_date_str[0..9]}.ods"
      send_data ods_data,
                filename: filename,
                type: 'application/vnd.oasis.opendocument.spreadsheet',
                disposition: 'attachment'
    else
      flash[:alert] = "Failed to generate report file."
      redirect_to admin_custom_orders_path(params.permit(:date_filter, :from_date, :to_date, :product_id, :customer_name, :phone_number))
    end
  end

  def update_status
    if params[:state].present?
      if @order.update_column(:state, params[:state])
        render json: { success: true, new_state: @order.state }
      else
        render json: { success: false, error: @order.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    else
      render json: { success: false, error: "No state parameter provided." }, status: :bad_request
    end
  rescue => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def show
    # Renders order details panel
  end

  def update
    # Handle payment capture sub-action
    if params[:payment_id].present? && params[:payment_action] == "capture"
      payment = @order.payments.find(params[:payment_id])
      if payment.can_capture?
        payment.capture!
        flash[:notice] = "Payment captured and marked as Paid."
      else
        flash[:alert] = "This payment cannot be captured."
      end
    # Handle shipment ship sub-action
    elsif params[:shipment_id].present? && params[:shipment_action] == "ship"
      shipment = @order.shipments.find(params[:shipment_id])
      if shipment.can_ship?
        shipment.ship!
        OrderMailer.shipment_email(@order).deliver_later
        flash[:notice] = "Shipment marked as Shipped and tracking initiated."
      else
        flash[:alert] = "This shipment cannot be shipped (check stock or payment status)."
      end
    # Handle order and address updates
    elsif params[:order].present?
      order_params = params.require(:order).permit(
        :email, :state,
        bill_address_attributes: [:firstname, :lastname, :address1, :address2, :city, :state_name, :zipcode, :phone],
        ship_address_attributes: [:firstname, :lastname, :address1, :address2, :city, :state_name, :zipcode, :phone]
      )
      
      ActiveRecord::Base.transaction do
        if order_params[:bill_address_attributes].present?
          if @order.bill_address
            @order.bill_address.update!(order_params[:bill_address_attributes])
          else
            country = @order.store&.default_country || Spree::Country.find_by(iso: 'IN') || Spree::Country.first
            @order.create_bill_address!(order_params[:bill_address_attributes].merge(country: country))
          end
        end

        if order_params[:ship_address_attributes].present?
          if @order.ship_address
            @order.ship_address.update!(order_params[:ship_address_attributes])
          else
            country = @order.store&.default_country || Spree::Country.find_by(iso: 'IN') || Spree::Country.first
            @order.create_ship_address!(order_params[:ship_address_attributes].merge(country: country))
          end
        end

        @order.update!(email: order_params[:email]) if order_params[:email].present?
        @order.update_column(:state, order_params[:state]) if order_params[:state].present?
      end
      flash[:notice] = "Order details updated successfully."
    end
    
    redirect_to admin_custom_order_path(@order.number)
  rescue => e
    flash[:alert] = "Error processing action: #{e.message}"
    redirect_to admin_custom_order_path(@order.number)
  end

  private

  def set_order
    @order = Spree::Order.complete.find_by!(number: params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Order not found."
    redirect_to admin_custom_orders_path
  end
end
