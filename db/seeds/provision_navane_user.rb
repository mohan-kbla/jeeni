# Provision user account for navaneshivaraju@gmail.com with Orders Manager role
role = Spree::Role.find_or_create_by!(name: "orders_manager")

user = Spree::User.find_or_initialize_by(email: "navaneshivaraju@gmail.com")
user.first_name = "Navane" if user.first_name.blank?
user.last_name = "Shivaraju" if user.last_name.blank?

if user.new_record?
  user.password = "Password@123"
  user.password_confirmation = "Password@123"
end

user.save!(validate: false)

unless user.has_spree_role?("orders_manager")
  user.spree_roles << role
end

puts "SUCCESS: Provisioned user #{user.email} (ID: #{user.id}) with role '#{role.name}'."
