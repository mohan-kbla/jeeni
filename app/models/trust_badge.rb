class TrustBadge < ApplicationRecord
  has_one_attached :image

  validates :name, presence: true
  validates :icon, presence: true

  scope :active, -> { where(active: true) }

  # Supported default icons
  ICONS = {
    "shield" => "🔒 Secure Payment",
    "truck" => "⚡ Fast Delivery",
    "badge" => "⭐ Genuine Product",
    "headset" => "💬 Customer Support",
    "cart" => "📝 Easy Ordering"
  }.freeze
end
