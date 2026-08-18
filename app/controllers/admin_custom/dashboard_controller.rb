class AdminCustom::DashboardController < ApplicationController
  before_action :authorize_admin!
  layout "admin_custom"

  def index
    # Total Completed Sales Revenue
    @total_sales = Spree::Order.complete.sum(:total)
    
    # Total Number of Orders
    @orders_count = Spree::Order.complete.count
    
    # Registered Customers Count
    @users_count = Spree::User.count
    
    # Comments Pending Moderation
    @pending_comments_count = Comment.pending.count
    
    # 5 Most Recent Completed Orders
    @recent_orders = Spree::Order.complete.order(completed_at: :desc).limit(5)
  end
end
