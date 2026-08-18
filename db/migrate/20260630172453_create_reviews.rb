class CreateReviews < ActiveRecord::Migration[7.1]
  def change
    create_table :reviews do |t|
      t.integer :product_id
      t.integer :user_id
      t.integer :rating
      t.string :title
      t.text :body
      t.string :status

      t.timestamps
    end
  end
end
