class AdminCustom::BlogsController < ApplicationController
  before_action :authorize_admin!
  before_action :set_blog, only: [:show, :edit, :update, :destroy]
  layout "admin_custom"

  def index
    @blogs = Blog.recent.page(params[:page]).per(10)
  end

  def show
    @comments = @blog.comments.recent
  end

  def new
    @blog = Blog.new
  end

  def create
    @blog = Blog.new(blog_params)
    if @blog.save
      flash[:notice] = "Blog post created successfully."
      redirect_to admin_custom_blog_path(@blog)
    else
      flash.now[:alert] = "Error creating blog post: #{@blog.errors.full_messages.join(', ')}"
      render :new
    end
  end

  def edit
  end

  def update
    if @blog.update(blog_params)
      flash[:notice] = "Blog post updated successfully."
      redirect_to admin_custom_blog_path(@blog)
    else
      flash.now[:alert] = "Error updating blog post: #{@blog.errors.full_messages.join(', ')}"
      render :edit
    end
  end

  def destroy
    @blog.destroy
    flash[:notice] = "Blog post deleted successfully."
    redirect_to admin_custom_blogs_path
  end

  private

  def set_blog
    @blog = Blog.friendly.find(params[:id])
  end

  def blog_params
    params.require(:blog).permit(:title, :body, :category, :tag_list, :published, :author, :status, :meta_title, :meta_description, :content)
  end
end
