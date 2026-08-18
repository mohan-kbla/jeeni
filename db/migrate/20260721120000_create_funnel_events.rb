class CreateFunnelEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :funnel_events do |t|
      t.string :visitor_id
      t.string :event_name, null: false
      t.integer :product_id
      t.integer :order_id
      t.string :user_agent
      t.string :path

      t.timestamps
    end

    add_index :funnel_events, :visitor_id
    add_index :funnel_events, :event_name
    add_index :funnel_events, :created_at
    add_index :funnel_events, [:event_name, :created_at]
  end
end
