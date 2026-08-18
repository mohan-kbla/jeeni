class AddIsFeaturedToGalleryVideos < ActiveRecord::Migration[7.1]
  def change
    add_column :gallery_videos, :is_featured, :boolean, default: false
  end
end
