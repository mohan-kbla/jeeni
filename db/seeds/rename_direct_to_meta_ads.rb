# db/seeds/rename_direct_to_meta_ads.rb
orders_updated = Spree::Order.where(booking_source: 'Direct').update_all(booking_source: 'Meta Ads')
attributions_updated = VisitorAttribution.where(booking_source: 'Direct').update_all(booking_source: 'Meta Ads')

puts "Updated #{orders_updated} Spree::Order records from 'Direct' to 'Meta Ads'."
puts "Updated #{attributions_updated} VisitorAttribution records from 'Direct' to 'Meta Ads'."
