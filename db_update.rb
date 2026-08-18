india = Spree::Country.find_by(iso: "IN")
if india
  Spree::Config[:default_country_id] = india.id
  puts "Set default country to India."
else
  puts "India not found!"
end

us = Spree::Country.find_by(iso: "US")
if us
  # Removing US
  us.states.destroy_all
  us.destroy
  puts "Deleted US and its states."
end
