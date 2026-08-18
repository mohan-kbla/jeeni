class CreateCroTables < ActiveRecord::Migration[7.1]
  def change
    # 1. Create trust_badges table
    unless table_exists?(:trust_badges)
      create_table :trust_badges do |t|
        t.string :name
        t.string :icon
        t.text :description
        t.boolean :active, default: true, null: false
        t.timestamps
      end
    end

    # 2. Create testimonials table
    unless table_exists?(:testimonials)
      create_table :testimonials do |t|
        t.string :author_name
        t.integer :rating, default: 5
        t.text :content
        t.string :video_url
        t.boolean :is_success_story, default: false, null: false
        t.boolean :active, default: true, null: false
        t.integer :product_id
        t.timestamps
      end
      add_index :testimonials, :product_id
    end

    # 3. Create faqs table
    unless table_exists?(:faqs)
      create_table :faqs do |t|
        t.string :question
        t.text :answer
        t.integer :product_id
        t.integer :position, default: 0
        t.boolean :active, default: true, null: false
        t.timestamps
      end
      add_index :faqs, :product_id
    end

    # 4. Create cro_settings table
    unless table_exists?(:cro_settings)
      create_table :cro_settings do |t|
        t.string :key, null: false
        t.text :value
        t.timestamps
      end
      add_index :cro_settings, :key, unique: true
    end

    # 5. Add custom layout columns to spree_products
    unless column_exists?(:spree_products, :benefits)
      add_column :spree_products, :benefits, :text
    end
    unless column_exists?(:spree_products, :ingredients)
      add_column :spree_products, :ingredients, :text
    end
    unless column_exists?(:spree_products, :how_to_use)
      add_column :spree_products, :how_to_use, :text
    end
    unless column_exists?(:spree_products, :discount_info)
      add_column :spree_products, :discount_info, :string
    end
  end
end
