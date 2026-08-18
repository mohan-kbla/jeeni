india = Spree::Country.find_by(iso: "IN")
zone = Spree::Zone.find_by(name: "Global Zone")
if zone && india
  unless zone.zone_members.exists?(zoneable: india)
    zone.zone_members.create!(zoneable: india)
    puts "Added India to Global Zone."
  end
end
