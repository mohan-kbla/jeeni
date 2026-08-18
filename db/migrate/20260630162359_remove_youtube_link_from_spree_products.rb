class RemoveYoutubeLinkFromSpreeProducts < ActiveRecord::Migration[7.1]
  def change
    remove_column :spree_products, :youtube_link, :string
  end
end
