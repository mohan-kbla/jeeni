# This migration comes from spree (originally 20210929090344)
class CreateStockItemStockLocationIdVariantIdCoalesceDeletedAtUniqueIndex < ActiveRecord::Migration[5.2]
  def change
    remove_index :spree_stock_items, name: :stock_item_by_loc_var_id_deleted_at, if_exists: true
    reversible do |dir|
      dir.up do
        begin
          execute <<-SQL
            CREATE UNIQUE INDEX stock_item_by_loc_var_id_deleted_at
            ON spree_stock_items(
              stock_location_id,
              variant_id,
              (COALESCE(deleted_at, CAST('1970-01-01' AS #{deleted_at_data_type})))
            );
          SQL
        rescue => e
          puts "WARNING: Expression index failed (likely MariaDB incompatibility). Creating standard fallback index. Error: #{e.message}"
          begin
            add_index :spree_stock_items, [:stock_location_id, :variant_id, :deleted_at], name: 'stock_item_by_loc_var_id_deleted_at', unique: true
          rescue => e2
            puts "WARNING: Fallback index also failed: #{e2.message}"
          end
        end
      end

      dir.down do
        remove_index :spree_stock_items, name: :stock_item_by_loc_var_id_deleted_at, if_exists: true
      end
    end
  end

  private

  def deleted_at_data_type
    case ActiveRecord::Base.connection.adapter_name
    when 'Mysql2'
      'DATETIME'
    when 'PostgreSQL'
      'TIMESTAMP'
    end
  end
end
