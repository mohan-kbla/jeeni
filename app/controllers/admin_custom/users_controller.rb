class AdminCustom::UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :set_user, only: [:update]
  layout "admin_custom"

  def index
    # Load Spree users who are administrators or read-only staff (like accounts@jeenimilletmix.in)
    @users = Spree::User.joins(:spree_roles).where(spree_roles: { name: ["admin", "read_only_orders"] }).distinct.order(created_at: :desc).page(params[:page]).per(15)
  end

  def update
    admin_role = Spree::Role.find_or_create_by!(name: "admin")
    
    # Don't allow the current admin to demote themselves (safety lock)
    if @user == spree_current_user
      flash[:alert] = "Safety lock: You cannot revoke your own administrator role."
    else
      if @user.has_spree_role?("admin")
        @user.spree_roles.delete(admin_role)
        flash[:notice] = "User #{@user.email} demoted to Customer."
      else
        @user.spree_roles << admin_role
        flash[:notice] = "User #{@user.email} promoted to Administrator."
      end
    end
    
    redirect_to admin_custom_users_path
  rescue => e
    flash[:alert] = "Error updating user roles: #{e.message}"
    redirect_to admin_custom_users_path
  end

  private

  def set_user
    @user = Spree::User.find(params[:id])
  end
end
