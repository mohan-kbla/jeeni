# Seed CRO configuration settings
CroSetting.set('whatsapp_number', '917624931166')
CroSetting.set('landing_page_banner', '🔥 Special Offer: Get 10% Off and Free Shipping on all Health Blends!')

# Create default Trust Badges
TrustBadge.destroy_all
TrustBadge.create!([
  { name: 'Secure checkout', icon: '🔒 SSL Encrypted', description: 'Your transaction is safe and secure.', active: true },
  { name: 'Fast Delivery', icon: '⚡ Speed', description: 'Dispatched within 24 hours.', active: true },
  { name: '100% Quality', icon: '⭐ Guarantee', description: 'Satisfaction guaranteed or refund.', active: true }
])

# Create global FAQs
Faq.where(product_id: nil).destroy_all
Faq.create!([
  { question: 'What payment methods do you support?', answer: 'We support all major Credit/Debit Cards, UPI, NetBanking, and Cash on Delivery (COD).', position: 1, active: true },
  { question: 'How long does delivery take?', answer: 'Orders are shipped within 24 hours. Delivery typically takes 2-4 business days.', position: 2, active: true }
])

# Add detailed fields to existing products (Fuzzy name matching for production & local fallback)
products = Spree::Product.all
products.each do |product|
  name_down = product.name.to_s.downcase

  if name_down.include?("sugaramla")
    product.update!(
      discount_info: "10% OFF TODAY",
      benefits: "Supports healthy blood sugar levels\nRich in Vitamin C and antioxidants\nImproves digestion and immunity\nPure & wholesome, no added sugar",
      ingredients: "Wholesome Grown Sugar Amla Extract\nTraditional herbs\nFiber rich base",
      how_to_use: "Take 1-2 spoons daily with warm water or milk\nBest taken in the morning on an empty stomach\nRegular usage for 3 months is recommended for best results"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Who can consume Jeeni Sugaramla?', answer: 'It is ideal for adults looking to support healthy sugar levels and improve general immunity.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Dr. Ramesh Kumar', rating: 5, content: 'Excellent quality and wholesome results. My patients have reported great improvement in energy levels.', active: true, is_success_story: true }
    ])

  elsif name_down.include?("slim")
    product.update!(
      discount_info: "METABOLISM BOOST DEAL",
      benefits: "Boosts metabolism and energy levels\nHelps control appetite and cravings\nSupports healthy weight management\nRich in dietary fiber and essential minerals",
      ingredients: "Sprouted Millets\nGreen Tea Extract\nTraditional herbs blend",
      how_to_use: "Mix 2 tablespoons in a glass of water/buttermilk\nBoil for 3-5 minutes, stirring continuously\nDrink warm as a meal replacement or morning beverage"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Does it contain any artificial additives?', answer: 'No, Jeeni Slim is completely free from artificial colors, preservatives, or synthetic additives.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Priya Sharma', rating: 5, content: 'Lost 4 kgs in a month combined with healthy eating. Tastes clean and keeps me full for hours.', active: true, is_success_story: true }
    ])

  elsif name_down.include?("traditional mix") || name_down.include?("health mix")
    product.update!(
      discount_info: "BUY 2 GET 10% OFF",
      benefits: "Contains 25+ traditional millets, grains, and nuts\nComplete nutritional drink for all age groups\nRich in proteins, calcium, and dietary fiber\nBoosts daily energy and keeps you active",
      ingredients: "Ragi, Bajra, Jowar, Wheat, Barley, Green Gram, Almonds, Cashews, Cardamom",
      how_to_use: "Add 2 tablespoons of mix to 1 cup of milk or water\nStir well to remove lumps\nCook on medium heat for 5 minutes, add jaggery or salt to taste"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Can children consume this mix?', answer: 'Yes! It is highly nutritious and suitable for children above 1 year of age.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Anjali Hegde', rating: 5, content: 'My whole family drinks Jeeni Health Mix every morning. It is super healthy and easy to prepare.', active: true, is_success_story: true }
    ])

  elsif name_down.include?("women")
    product.update!(
      discount_info: "WOMEN'S SPECIAL",
      benefits: "Specially formulated for women's daily health\nRich in iron, calcium, and folic acid\nSupports bone strength and hormonal balance\nProvides sustained energy throughout the day",
      ingredients: "Sprouted Millets, Soya, Almonds, Fenugreek, Moringa extract",
      how_to_use: "Mix 2 spoons in a glass of warm milk\nStir well and consume as a breakfast supplement"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Does it help with bone health?', answer: 'Yes, it is fortified with pure calcium sources that help maintain bone density.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Savitha Rao', rating: 5, content: 'Great source of daily iron. I feel much less tired during the day since I started using it.', active: true, is_success_story: true }
    ])

  # --- Fallbacks for local default Spree sample products ---
  elsif name_down.include?("leather jacket")
    product.update!(
      discount_info: "15% OFF TODAY",
      benefits: "100% Genuine Full-grain Leather\nHeavy-duty YKK Zippers\nWater-resistant treatment\nPremium quilted satin lining",
      ingredients: "Premium Cowhide Leather\nSatin Lining\nYKK Metal Hardware",
      how_to_use: "Avoid washing in machine\nUse a specialized leather cleaner/conditioner once a year\nStore on a wide padded hanger"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Is it genuine leather?', answer: 'Yes, this jacket is made from 100% genuine full-grain cowhide leather.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'John Doe', rating: 5, content: 'Absolutely beautiful jacket! Extremely soft leather, heavy-duty zippers, and fits like a glove.', active: true, is_success_story: true }
    ])

  elsif name_down.include?("dress")
    product.update!(
      discount_info: "BUY 1 GET 1 FREE",
      benefits: "Breathable organic cotton blend\nEasy relaxed fit for hot days\nFlowy mid-length design\nMachine washable, fade-resistant",
      ingredients: "70% Organic Cotton\n30% Linen Blend",
      how_to_use: "Machine wash cold with like colors\nTumble dry low\nWarm iron if needed"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Is the material see-through?', answer: 'No, the dress features a double-lined lightweight cotton-linen fabric that is opaque but highly breathable.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Emma Watson', rating: 5, content: 'Perfect summer dress! Lightweight, fits perfectly, and keeps me cool all day. Got so many compliments!', active: true, is_success_story: true }
    ])

  elsif name_down.include?("watch")
    product.update!(
      discount_info: "SAVE ₹1,500 TODAY",
      benefits: "Always-on AMOLED display\nAdvanced heart rate & sleep tracking\n7-day battery life on a single charge\nIP68 swim-proof water resistance",
      ingredients: "Aluminum Alloy Case\nGorilla Glass DX+ Screen\nHypoallergenic Silicone Strap",
      how_to_use: "Download the companion application from Google Play Store or iOS App Store\nPair the watch using Bluetooth\nWear snug but comfortable"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'Is it compatible with iOS?', answer: 'Yes, it is fully compatible with both iOS (version 12.0+) and Android (version 7.0+) smartphones.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Robert Downey Jr.', rating: 5, content: 'Excellent battery life! Easily lasts a week. The screen is gorgeous and bright.', active: true, is_success_story: true }
    ])

  elsif name_down.include?("headphones")
    product.update!(
      discount_info: "FREE LEATHER CASE",
      benefits: "Hybrid Active Noise Cancelling (ANC)\n40-hour playtime with ANC off\nHigh-res wireless audio certified\nUltra-soft memory foam earcups",
      ingredients: "Premium ABS polymer case\nMemory foam leatherette ear cushions\nCustom dynamic drivers",
      how_to_use: "Turn on using the power button (hold for 3 seconds)\nTurn ANC on/off with a single press of the ANC button\nFoldable design makes it easy to store in the included travel case"
    )
    product.faqs.destroy_all
    product.faqs.create!([
      { question: 'How good is the noise cancellation?', answer: 'It filters out up to 92% of low-frequency ambient sounds like engine or traffic noise.', position: 1, active: true }
    ])
    product.testimonials.destroy_all
    product.testimonials.create!([
      { author_name: 'Scarlett Johansson', rating: 5, content: 'The active noise cancellation is top notch. Super comfortable for long flights.', active: true, is_success_story: true }
    ])
  end
end

puts "CRO Seeds loaded successfully!"
