class CreateProductGalleries < ActiveRecord::Migration[7.1]
  def change
    create_table :product_galleries do |t|
      t.references :product, null: false, foreign_key: { to_table: :spree_products }
      t.string :youtube_link

      t.timestamps
    end
  end
end
