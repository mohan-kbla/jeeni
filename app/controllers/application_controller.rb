class ApplicationController < ActionController::Base
  # Include Spree's helper modules for storefront context
  include Spree::Core::ControllerHelpers::Common
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Store
  include Spree::Core::ControllerHelpers::Currency
  include Spree::Core::ControllerHelpers::Locale
  include Spree::Core::ControllerHelpers::Search

  helper_method :current_order, :spree_current_user, :current_store, :current_currency, :current_locale

  before_action :check_ad_traffic
  before_action :track_visit
  before_action :associate_attribution_to_order
  before_action :set_visitor_session_thread
  before_action :restrict_read_only_staff_from_storefront!

  helper_method :is_ad_traffic?, :karnataka_visitor?, :current_visitor_address

  def is_ad_traffic?
    session[:is_ad_traffic] == true
  end

  def current_visitor_address
    order = current_order
    return order.ship_address if order&.ship_address.present?
    return order.bill_address if order&.bill_address.present?
    return spree_current_user.ship_address if spree_current_user&.ship_address.present?
    return spree_current_user.bill_address if spree_current_user&.bill_address.present?
    nil
  end

  def karnataka_visitor?
    PricingService.is_karnataka?(current_visitor_address, session)
  end

  private

  def check_ad_traffic
    if params[:utm_source].to_s.downcase.include?('facebook') || 
       params[:utm_source].to_s.downcase.include?('meta') || 
       params[:ad] == 'true' || 
       params[:ref] == 'fb'
      session[:is_ad_traffic] = true
    end
  end

  def set_visitor_session_thread
    Thread.current[:visitor_session] = session
  end

  protected

  # Filter to restrict access to custom admin controllers
  def authorize_admin!
    unless spree_current_user && (spree_current_user.has_spree_role?("admin") || spree_current_user.has_spree_role?("read_only_orders"))
      flash[:alert] = "You are not authorized to access this page."
      redirect_to root_path and return
    end

    # Enforce strict server-side authorization for read-only staff users
    if spree_current_user.respond_to?(:read_only_orders?) && spree_current_user.read_only_orders?
      is_orders_controller = (controller_name == "orders" && params[:controller] == "admin_custom/orders")
      is_reports_controller = (controller_name == "reports" && params[:controller] == "admin_custom/reports")
      is_read_action = %w[index show export].include?(action_name)

      if (is_orders_controller || is_reports_controller) && is_read_action
        # Allowed access to view orders and reports
        return
      elsif is_orders_controller && !is_read_action
        # Block write/mutation attempts on orders
        respond_to do |format|
          format.html {
            flash[:alert] = "403 Access Denied: Read-only accounts cannot modify orders."
            redirect_to admin_custom_orders_path, status: :forbidden
          }
          format.json {
            render json: { success: false, error: "403 Forbidden: Read-only accounts cannot modify orders." }, status: :forbidden
          }
        end
        return
      else
        # Block access to all other non-authorized admin pages
        respond_to do |format|
          format.html {
            flash[:alert] = "403 Access Denied: You only have access to the Orders and Reports pages."
            redirect_to admin_custom_orders_path, status: :forbidden
          }
          format.json {
            render json: { success: false, error: "403 Access Denied: You only have access to the Orders and Reports pages." }, status: :forbidden
          }
        end
        return
      end
    end
  end


  private

  def track_visit
    # Skip tracking for non-GET requests, custom admin panel, and api/js requests
    return unless request.get?
    return if request.path.start_with?("/admin_custom") || request.format.json? || request.format.js?
    
    # Exclude common search bots and invalid traffic
    user_agent = request.user_agent.to_s.downcase
    is_bot = user_agent.blank? || user_agent.match?(/(googlebot|bingbot|yahoo|baidu|yandex|crawler|spider|robot|bot|slurp|crawl)/)
    return if is_bot

    # Set visitor_id cookie if not present
    visitor_id = cookies[:visitor_id]
    if visitor_id.blank?
      visitor_id = SecureRandom.uuid
      cookies.permanent[:visitor_id] = { value: visitor_id, httponly: true }
    end

    # Check that visitor_attributions table exists before writing
    if ActiveRecord::Base.connection.table_exists?(:visitor_attributions)
      begin
        attribution = VisitorAttribution.find_by(visitor_id: visitor_id)
        if attribution.nil?
          ua_details = VisitorAttribution.parse_user_agent(request.user_agent)
          
          attribution = VisitorAttribution.new(
            visitor_id: visitor_id,
            utm_source: params[:utm_source],
            utm_medium: params[:utm_medium],
            utm_campaign: params[:utm_campaign],
            utm_term: params[:utm_term],
            utm_content: params[:utm_content],
            referrer: request.referer,
            landing_page: request.original_url,
            current_url: request.original_url,
            ip_address: request.remote_ip,
            device_type: ua_details[:device_type],
            browser: ua_details[:browser],
            operating_system: ua_details[:operating_system],
            country: "India",
            state: "Karnataka",
            city: "Bengaluru",
            booking_source: VisitorAttribution.classify(params[:utm_source], params[:utm_medium], params[:utm_campaign], request.referer, request.original_url)
          )

          if attribution.save
            ip_to_geocode = request.remote_ip
            Thread.new do
              ActiveRecord::Base.connection_pool.with_connection do
                geo = VisitorAttribution.geolocate_ip(ip_to_geocode)
                rec = VisitorAttribution.find_by(visitor_id: visitor_id)
                if rec
                  rec.update_columns(
                    country: geo[:country],
                    state: geo[:state],
                    city: geo[:city]
                  )
                end
              end
            end rescue nil
          end
        end
      rescue => e
        Rails.logger.error "Failed to save visitor attribution: #{e.message}"
      end
    end

    # Check that visits table exists before writing (defensive check during migrations/assets compile)
    return unless ActiveRecord::Base.connection.table_exists?(:visits)

    # Log at most once per user session per hour to keep data clean
    session_key = "visit_tracked_#{Time.current.strftime('%Y%m%d%H')}"
    return if session[session_key]

    begin
      Visit.create!(
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        path: request.path
      )
      session[session_key] = true
    rescue => e
      Rails.logger.error "Failed to track visit: #{e.message}"
    end
  end

  def associate_attribution_to_order
    # If the user has a visitor_id cookie, and there is a current order
    # that does not yet have a booking_source set, copy the attribution details.
    visitor_id = cookies[:visitor_id]
    return if visitor_id.blank?

    order = current_order
    return if order.nil?

    # Track visitor_id in order public_metadata (always ensure it's saved)
    current_meta = order.public_metadata || {}
    if current_meta['visitor_id'] != visitor_id
      new_meta = current_meta.merge('visitor_id' => visitor_id)
      order.update_columns(public_metadata: new_meta)
    end

    return if order.booking_source.present?

    # Find the visitor attribution record
    return unless ActiveRecord::Base.connection.table_exists?(:visitor_attributions)
    attribution = VisitorAttribution.find_by(visitor_id: visitor_id)
    return if attribution.nil?

    # Copy fields to the order
    order.update_columns(
      booking_source: attribution.booking_source || "Other",
      utm_source: attribution.utm_source,
      utm_medium: attribution.utm_medium,
      utm_campaign: attribution.utm_campaign,
      utm_term: attribution.utm_term,
      utm_content: attribution.utm_content,
      referrer: attribution.referrer,
      landing_page: attribution.landing_page,
      first_visit_at: attribution.created_at,
      device_type: attribution.device_type,
      browser: attribution.browser,
      operating_system: attribution.operating_system,
      ip_address: attribution.ip_address,
      attribution_country: attribution.country,
      attribution_state: attribution.state,
      attribution_city: attribution.city
    )
  end

  def restrict_read_only_staff_from_storefront!
    # If the user is logged in as a read-only staff user
    if spree_current_user && spree_current_user.respond_to?(:read_only_orders?) && spree_current_user.read_only_orders?
      # Allow access ONLY to admin_custom controllers and session destroy/logout action
      is_admin_custom = params[:controller].to_s.start_with?("admin_custom/")
      is_logout = (params[:controller] == "spree/user_sessions" && params[:action] == "destroy") || request.path.include?("logout")

      unless is_admin_custom || is_logout
        flash[:alert] = "Access Denied: Read-only accounts cannot access the storefront shop."
        redirect_to "/admin_custom/orders" and return
      end
    end
  end
end
