# db/seeds/check_cro_settings.rb
puts "google_tag_id: #{CroSetting.get('google_tag_id')}"
puts "google_ads_conversion_id: #{CroSetting.get('google_ads_conversion_id')}"
puts "google_ads_conversion_label: #{CroSetting.get('google_ads_conversion_label')}"
puts "gtm_container_id: #{CroSetting.get('gtm_container_id')}"
puts "meta_pixel_id: #{CroSetting.get('meta_pixel_id')}"
puts "\nAll CroSetting keys & values:"
CroSetting.all.each do |cs|
  puts "  #{cs.key} => #{cs.value}"
end
