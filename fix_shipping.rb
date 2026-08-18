india = Spree::Country.find_by(iso: "IN")

puts "India ID: #{india&.id}"
puts "Zones:"
Spree::Zone.all.each do |zone|
  puts "Zone #{zone.id}: #{zone.name}, Members: #{zone.zone_members.map { |m| "#{m.zoneable_type} #{m.zoneable_id}" }.join(', ')}"
end

puts "Shipping Methods:"
Spree::ShippingMethod.all.each do |sm|
  puts "Method #{sm.id}: #{sm.name}, Zones: #{sm.zones.map(&:id).join(', ')}"
end
