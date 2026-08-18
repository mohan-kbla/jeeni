class CreateVisitorAttributionsAndAddToOrders < ActiveRecord::Migration[7.1]
  def change
    drop_table :visitor_attributions, if_exists: true

    create_table :visitor_attributions do |t|
      t.string :visitor_id, null: false
      t.string :booking_source
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.text :referrer
      t.text :landing_page
      t.text :current_url
      t.string :device_type
      t.string :browser
      t.string :operating_system
      t.string :ip_address
      t.string :country
      t.string :state
      t.string :city

      t.timestamps
    end

    add_index :visitor_attributions, :visitor_id, unique: true
    add_index :visitor_attributions, :created_at

    # Add attribution columns to spree_orders
    change_table :spree_orders, bulk: true do |t|
      t.string :booking_source
      t.string :utm_source
      t.string :utm_medium
      t.string :utm_campaign
      t.string :utm_term
      t.string :utm_content
      t.text :referrer
      t.text :landing_page
      t.datetime :first_visit_at
      t.string :device_type
      t.string :browser
      t.string :operating_system
      t.string :ip_address
      t.string :attribution_country
      t.string :attribution_state
      t.string :attribution_city
    end
  end
end
