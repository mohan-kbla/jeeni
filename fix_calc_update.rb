Spree::Calculator::FlatRate.all.each do |c|
  c.preferred_currency = "INR"
  c.save!
  puts "Updated calculator #{c.id} currency to INR"
end
