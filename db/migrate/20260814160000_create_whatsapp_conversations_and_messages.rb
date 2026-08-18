class CreateWhatsappConversationsAndMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_conversations do |t|
      t.string :wa_id, null: false
      t.string :phone_number, null: false
      t.string :customer_name
      t.string :state, null: false, default: 'START'
      t.bigint :product_id
      t.string :product_name
      t.integer :quantity, default: 1
      t.string :city
      t.text :address
      t.string :zipcode
      t.string :selected_button
      t.text :metadata
      t.bigint :spree_order_id
      t.datetime :last_message_at

      t.timestamps
    end

    add_index :whatsapp_conversations, :wa_id, unique: true
    add_index :whatsapp_conversations, :phone_number
    add_index :whatsapp_conversations, :state

    create_table :whatsapp_messages do |t|
      t.string :message_id, null: false
      t.string :wa_id
      t.string :message_type
      t.text :payload
      t.datetime :processed_at

      t.timestamps
    end

    add_index :whatsapp_messages, :message_id, unique: true
  end
end
