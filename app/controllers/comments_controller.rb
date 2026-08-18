class CommentsController < ApplicationController
  before_action :authenticate_spree_user!

  def create
    @blog = Blog.friendly.find(params[:blog_id])
    @comment = @blog.comments.build(comment_params)
    @comment.user = spree_current_user
    @comment.status = "pending" # Force pending status for moderation

    if @comment.save
      flash[:notice] = "Thank you! Your comment has been submitted and is awaiting moderation."
    else
      flash[:alert] = "Error saving comment: #{@comment.errors.full_messages.join(', ')}"
    end
    
    redirect_to blog_path(@blog)
  end

  private

  def comment_params
    params.require(:comment).permit(:body)
  end
end
