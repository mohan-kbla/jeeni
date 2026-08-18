class CreateVisits < ActiveRecord::Migration[7.1]
  def change
    create_table :visits do |t|
      t.string :ip_address
      t.string :user_agent
      t.string :path

      t.timestamps
    end
    add_index :visits, :created_at
  end
end
