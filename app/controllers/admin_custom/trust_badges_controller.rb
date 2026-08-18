class AdminCustom::TrustBadgesController < ApplicationController
  before_action :authorize_admin!
  before_action :set_badge, only: [:edit, :update, :destroy]
  layout "admin_custom"

  def index
    @badges = TrustBadge.all.order(created_at: :desc)
  end

  def new
    @badge = TrustBadge.new
  end

  def create
    @badge = TrustBadge.new(badge_params)
    if @badge.save
      redirect_to admin_custom_trust_badges_path, notice: "Trust Badge created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @badge.update(badge_params)
      redirect_to admin_custom_trust_badges_path, notice: "Trust Badge updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @badge.destroy
    redirect_to admin_custom_trust_badges_path, notice: "Trust Badge deleted."
  end

  private

  def set_badge
    @badge = TrustBadge.find(params[:id])
  end

  def badge_params
    params.require(:trust_badge).permit(:name, :icon, :description, :active, :image)
  end
end
