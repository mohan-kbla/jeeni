class CreateWhatsappChats < ActiveRecord::Migration[7.1]
  def change
    create_table :whatsapp_chats do |t|
      t.string :phone_number, null: false
      t.string :state, null: false, default: 'idle'
      t.bigint :cart_id
      t.text :metadata

      t.timestamps
    end

    add_index :whatsapp_chats, :phone_number, unique: true
  end
end
