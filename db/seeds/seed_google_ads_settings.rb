# Seed script for Google Tag and Google Ads Conversion settings
CroSetting.set('google_tag_id', 'GT-55KXGQZ')
CroSetting.set('google_ads_conversion_id', 'AW-17269273792')
CroSetting.set('google_ads_conversion_label', '6PGNCJfsvOwcEMDpK0pA')

puts "Updated CroSettings:"
puts "google_tag_id: #{CroSetting.get('google_tag_id')}"
puts "google_ads_conversion_id: #{CroSetting.get('google_ads_conversion_id')}"
puts "google_ads_conversion_label: #{CroSetting.get('google_ads_conversion_label')}"
