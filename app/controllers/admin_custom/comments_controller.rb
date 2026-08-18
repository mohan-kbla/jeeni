class AdminCustom::CommentsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_comment, only: [:approve, :reject, :destroy]
  layout "admin_custom"

  def index
    # Load all comments, newest first, paginated
    @comments = Comment.recent
    
    # Filter by status if requested
    if params[:status].present?
      @comments = @comments.where(status: params[:status])
    end
    
    @comments = @comments.page(params[:page]).per(15)
  end

  def approve
    if @comment.approve!
      flash[:notice] = "Comment approved successfully."
    else
      flash[:alert] = "Error approving comment."
    end
    redirect_back fallback_location: admin_custom_comments_path
  end

  def reject
    if @comment.reject!
      flash[:notice] = "Comment rejected successfully."
    else
      flash[:alert] = "Error rejecting comment."
    end
    redirect_back fallback_location: admin_custom_comments_path
  end

  def destroy
    @comment.destroy
    flash[:notice] = "Comment deleted permanently."
    redirect_back fallback_location: admin_custom_comments_path
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end
end
