# db/seeds/check_dilip_pass.rb
u = Spree::User.find_by(email: 'dilipsira222@gmail.com')
if u
  puts "Valid Password@123: #{u.valid_password?('Password@123')}"
  unless u.valid_password?('Password@123')
    u.password = 'Password@123'
    u.password_confirmation = 'Password@123'
    u.save!(validate: false)
    puts "Password updated to Password@123"
  end
else
  puts "User not found"
end
