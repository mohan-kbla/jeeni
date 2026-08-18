class BackfillCategoryIdOnSpreeProducts < ActiveRecord::Migration[7.1]
  def up
    # Backfill category_id for products based on their associated taxons' taxonomy
    Spree::Product.find_each do |product|
      next if product.category_id.present?
      
      # Find the first associated taxon and use its taxonomy_id as the category_id
      taxon = product.taxons.first
      if taxon && taxon.taxonomy_id.present?
        product.update_columns(category_id: taxon.taxonomy_id)
      end
    end
  end

  def down
    # No-op or optional reset to nil
  end
end
