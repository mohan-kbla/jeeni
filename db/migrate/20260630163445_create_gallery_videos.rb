class CreateGalleryVideos < ActiveRecord::Migration[7.1]
  def change
    create_table :gallery_videos do |t|
      t.references :product_gallery, null: false, foreign_key: true
      t.integer :position
      t.string :external_url

      t.timestamps
    end
  end
end
