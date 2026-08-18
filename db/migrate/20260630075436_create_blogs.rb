class CreateBlogs < ActiveRecord::Migration[7.1]
  def change
    create_table :blogs do |t|
      t.string :title
      t.text :body
      t.string :slug
      t.string :category
      t.string :tags
      t.boolean :published, default: false, null: false
      t.datetime :published_at

      t.timestamps
    end
    add_index :blogs, :slug, unique: true
  end
end
