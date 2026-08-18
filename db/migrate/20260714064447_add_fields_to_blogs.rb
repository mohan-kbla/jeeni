class AddFieldsToBlogs < ActiveRecord::Migration[7.1]
  def change
    add_column :blogs, :author, :string
    add_column :blogs, :meta_title, :string
    add_column :blogs, :meta_description, :text
    add_column :blogs, :status, :string
    add_column :blogs, :content, :text
  end
end
