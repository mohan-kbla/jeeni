class AddYoutubeLinkToSpreeProducts < ActiveRecord::Migration[7.1]
  def change
    add_column :spree_products, :youtube_link, :string
  end
end
