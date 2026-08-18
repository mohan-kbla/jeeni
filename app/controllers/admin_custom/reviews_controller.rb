class AdminCustom::ReviewsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_review, only: [:approve, :reject, :destroy]
  layout "admin_custom"

  def index
    @reviews = Review.all.order(created_at: :desc).page(params[:page]).per(15)
  end

  def approve
    @review.update(status: 'approved')
    redirect_to admin_custom_reviews_path, notice: "Review approved successfully."
  end

  def reject
    @review.update(status: 'rejected')
    redirect_to admin_custom_reviews_path, notice: "Review rejected/hidden successfully."
  end

  def destroy
    @review.destroy
    redirect_to admin_custom_reviews_path, notice: "Review deleted successfully."
  end

  private

  def set_review
    @review = Review.find(params[:id])
  end
end
