class AddGuestOrderToSpreeOrders < ActiveRecord::Migration[7.1]
  def change
    add_column :spree_orders, :guest_order, :boolean, default: false
  end
end
