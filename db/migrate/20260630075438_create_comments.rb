class CreateComments < ActiveRecord::Migration[7.1]
  def change
    create_table :comments do |t|
      t.references :blog, null: false, foreign_key: true
      t.bigint :user_id, null: false
      t.text :body, null: false
      t.string :status, default: 'pending', null: false

      t.timestamps
    end
    add_index :comments, :user_id
    add_index :comments, :status
    add_foreign_key :comments, :spree_users, column: :user_id
  end
end
