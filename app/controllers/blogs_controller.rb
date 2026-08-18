class BlogsController < ApplicationController
  def index
    # Load all published blog posts
    @blogs = Blog.published.recent
    
    # Filter by category if requested
    if params[:category].present?
      @blogs = @blogs.where(category: params[:category])
    end
    
    # Filter by tag if requested
    if params[:tag].present?
      @blogs = @blogs.where("tags LIKE ?", "%#{params[:tag]}%")
    end
    
    # Paginate results (5 posts per page)
    @blogs = @blogs.page(params[:page]).per(5)
    
    # Load sidebar data (categories and unique tags)
    @categories = Blog.published.pluck(:category).uniq
    @all_tags = Blog.published.pluck(:tags).compact.flat_map { |t| t.split(',').map(&:strip) }.uniq
  end

  def show
    # Load post by slug
    @blog = Blog.friendly.find(params[:id])
    
    # Load only approved comments, newest first
    @comments = @blog.comments.approved.recent
    
    # Initialize a new comment for the form
    @comment = Comment.new
  end
end
