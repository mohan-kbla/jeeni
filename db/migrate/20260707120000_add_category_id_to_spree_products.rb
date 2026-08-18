class AddCategoryIdToSpreeProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :spree_products, :category_id, :integer
    add_index :spree_products, :category_id
  end
end
