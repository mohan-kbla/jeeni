class AddCustomFieldsToSpreeProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :spree_products, :state, :string
    add_index :spree_products, :state
    add_column :spree_products, :district, :string
    add_index :spree_products, :district
    add_column :spree_products, :featured, :boolean, default: false, null: false
    add_index :spree_products, :featured
    add_column :spree_products, :active, :boolean, default: true, null: false
    add_index :spree_products, :active
  end
end
