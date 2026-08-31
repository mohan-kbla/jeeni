class CreateDailyCompanyUpdates < ActiveRecord::Migration[7.1]
  def change
    create_table :daily_company_updates do |t|
      t.string :title
      t.string :media_type, null: false
      t.boolean :active, default: false, null: false

      t.timestamps
    end
  end
end
