class AdminCustom::InventoryController < ApplicationController
  before_action :authorize_admin!
  layout "admin_custom"

  def index
    # Load stock items, eager-loading product/variant data
    @stock_items = Spree::StockItem.includes(variant: [:product, :option_values])
                                   .order("spree_stock_items.count_on_hand ASC")
                                   .page(params[:page]).per(15)
  end

  def update
    stock_item = Spree::StockItem.find(params[:id])
    new_qty = params[:count_on_hand].to_i

    # Use Spree's native stock_item method to update inventory levels safely
    stock_item.set_count_on_hand(new_qty)
    
    flash[:notice] = "Inventory for #{stock_item.variant.product.name} (#{stock_item.variant.sku}) updated to #{new_qty}."
    redirect_to admin_custom_inventory_index_path
  rescue => e
    flash[:alert] = "Error updating inventory: #{e.message}"
    redirect_to admin_custom_inventory_index_path
  end
end
