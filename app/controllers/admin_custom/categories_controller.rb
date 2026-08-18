class AdminCustom::CategoriesController < ApplicationController
  before_action :authorize_admin!
  before_action :set_taxonomy, only: [:edit, :update, :destroy]
  layout "admin_custom"

  def index
    # Load all Spree taxonomies
    @taxonomies = Spree::Taxonomy.all.order(:name)
  end

  def new
    @taxonomy = Spree::Taxonomy.new
  end

  def create
    @taxonomy = Spree::Taxonomy.new(taxonomy_params)
    @taxonomy.store = defined?(current_store) && current_store ? current_store : Spree::Store.default
    if @taxonomy.save
      flash[:notice] = "Category created successfully."
      redirect_to admin_custom_categories_path
    else
      flash.now[:alert] = "Error creating category: #{@taxonomy.errors.full_messages.join(', ')}"
      render :new
    end
  end

  def edit
  end

  def update
    if @taxonomy.update(taxonomy_params)
      flash[:notice] = "Category updated successfully."
      redirect_to admin_custom_categories_path
    else
      flash.now[:alert] = "Error updating category: #{@taxonomy.errors.full_messages.join(', ')}"
      render :edit
    end
  end

  def destroy
    @taxonomy.destroy
    flash[:notice] = "Category deleted successfully."
    redirect_to admin_custom_categories_path
  end

  private

  def set_taxonomy
    @taxonomy = Spree::Taxonomy.find(params[:id])
  end

  def taxonomy_params
    params.require(:taxonomy).permit(:name)
  end
end
