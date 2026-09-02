class AdminCustom::UsersController < ApplicationController
  before_action :authorize_admin!
  before_action :set_user, only: [:update]
  layout "admin_custom"

  def index
    # Load Spree users who are administrators, orders managers, or read-only staff
    @users = Spree::User.joins(:spree_roles).where(spree_roles: { name: ["admin", "orders_manager", "read_only_orders"] }).distinct.order(created_at: :desc).page(params[:page]).per(15)
  end

  def create
    user_params = params.require(:user).permit(:email, :password, :first_name, :last_name, :role_name)
    email = user_params[:email].to_s.strip.downcase
    password = user_params[:password].presence || "Password@123"
    role_name = user_params[:role_name].presence || "orders_manager"
    first_name = user_params[:first_name].presence || email.split('@').first.titleize
    last_name = user_params[:last_name].presence || "Staff"

    user = Spree::User.find_or_initialize_by(email: email)
    user.first_name = first_name
    user.last_name = last_name
    user.password = password
    user.password_confirmation = password if user.new_record?

    if user.save
      target_role = Spree::Role.find_or_create_by!(name: role_name)
      user.spree_roles << target_role unless user.has_spree_role?(role_name)
      flash[:notice] = "User #{user.email} created/updated with role '#{role_name.titleize}'."
    else
      flash[:alert] = "Failed to create user: #{user.errors.full_messages.to_sentence}"
    end

    redirect_to admin_custom_users_path
  rescue => e
    flash[:alert] = "Error creating user: #{e.message}"
    redirect_to admin_custom_users_path
  end

  def update
    if @user == spree_current_user
      flash[:alert] = "Safety lock: You cannot revoke your own administrator role."
    else
      target_role_name = params[:role_name]
      if target_role_name.present?
        ["admin", "orders_manager", "read_only_orders"].each do |r|
          r_obj = Spree::Role.find_by(name: r)
          @user.spree_roles.delete(r_obj) if r_obj
        end
        assigned = Spree::Role.find_or_create_by!(name: target_role_name)
        @user.spree_roles << assigned
        flash[:notice] = "User #{@user.email} role updated to #{target_role_name.titleize}."
      elsif @user.has_spree_role?("admin")
        admin_role = Spree::Role.find_by(name: "admin")
        @user.spree_roles.delete(admin_role)
        flash[:notice] = "User #{@user.email} demoted to Customer."
      else
        admin_role = Spree::Role.find_or_create_by!(name: "admin")
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
