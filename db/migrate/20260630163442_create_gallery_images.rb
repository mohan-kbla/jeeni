class CreateGalleryImages < ActiveRecord::Migration[7.1]
  def change
    create_table :gallery_images do |t|
      t.references :product_gallery, null: false, foreign_key: true
      t.integer :position
      t.boolean :is_featured

      t.timestamps
    end
  end
end
