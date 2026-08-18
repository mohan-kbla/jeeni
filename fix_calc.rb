Spree::Calculator::FlatRate.all.each do |c|
  puts "Calculator #{c.id}, amount: #{c.preferred_amount}, currency: #{c.preferred_currency.inspect}"
end
