class AdminCustom::DailyCompanyUpdatesController < ApplicationController
  before_action :authorize_admin!
  before_action :check_read_only!, only: [:create, :update, :destroy, :activate, :deactivate]
  before_action :set_update, only: [:edit, :update, :destroy, :activate, :deactivate]
  layout "admin_custom"

  def index
    @updates = DailyCompanyUpdate.all.order(created_at: :desc)
    @new_update = DailyCompanyUpdate.new
    @active_update = DailyCompanyUpdate.find_by(active: true)
  end

  def create
    @update = DailyCompanyUpdate.new(update_params)
    if params[:save_and_activate].present?
      @update.active = true
    end
    if @update.save
      redirect_to admin_custom_daily_company_updates_path, notice: "Daily Update uploaded successfully."
    else
      @updates = DailyCompanyUpdate.all.order(created_at: :desc)
      @active_update = DailyCompanyUpdate.find_by(active: true)
      @new_update = @update
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @update.update(update_params)
      redirect_to admin_custom_daily_company_updates_path, notice: "Daily Update updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @update.destroy
    redirect_to admin_custom_daily_company_updates_path, notice: "Daily Update deleted successfully."
  end

  def activate
    if @update.update(active: true)
      redirect_to admin_custom_daily_company_updates_path, notice: "Daily Update is now ACTIVE."
    else
      redirect_to admin_custom_daily_company_updates_path, alert: "Failed to activate Daily Update: #{@update.errors.full_messages.to_sentence}"
    end
  end

  def deactivate
    if @update.update(active: false)
      redirect_to admin_custom_daily_company_updates_path, notice: "Daily Update has been deactivated."
    else
      redirect_to admin_custom_daily_company_updates_path, alert: "Failed to deactivate Daily Update."
    end
  end

  private

  def set_update
    @update = DailyCompanyUpdate.find(params[:id])
  end

  def update_params
    params.require(:daily_company_update).permit(:title, :media_type, :active, :media)
  end

  def check_read_only!
    if spree_current_user.respond_to?(:read_only_orders?) && spree_current_user.read_only_orders?
      redirect_to admin_custom_daily_company_updates_path, alert: "Read-only users are not authorized to modify updates."
    end
  end
end
