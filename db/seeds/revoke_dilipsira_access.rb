# Script to revoke all admin and staff roles for dilipsira222@gmail.com
email = "dilipsira222@gmail.com"
user = Spree::User.find_by(email: email)

if user
  roles_to_remove = ["admin", "orders_manager", "read_only_orders"]
  roles_to_remove.each do |role_name|
    role_obj = Spree::Role.find_by(name: role_name)
    user.spree_roles.delete(role_obj) if role_obj
  end
  puts "SUCCESS: Revoked all admin/staff access for #{user.email} (ID: #{user.id}). User is now Customer."
else
  puts "INFO: User #{email} not found in database."
end
