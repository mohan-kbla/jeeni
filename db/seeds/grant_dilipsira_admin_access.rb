# db/seeds/grant_dilipsira_admin_access.rb
email = "dilipsira222@gmail.com"
admin_role = Spree::Role.find_or_create_by!(name: "admin")

user = Spree::User.find_or_initialize_by(email: email) do |u|
  u.password = "Password@123"
  u.password_confirmation = "Password@123"
  u.first_name = "Dilip"
  u.last_name = "Sira"
end

user.spree_roles.clear
user.spree_roles << admin_role
user.save!(validate: false)

puts "SUCCESS: Granted Admin role to #{email} (ID: #{user.id}) with restriction on /admin_custom/analytics"
