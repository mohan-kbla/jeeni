class Review < ApplicationRecord
  belongs_to :product, class_name: 'Spree::Product'
  belongs_to :user, class_name: 'Spree::User', optional: true

  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }
  validates :title, presence: true
  validates :body, presence: true

  # Default scope to only show approved/published reviews if status is used
  scope :approved, -> { where(status: ['approved', nil]) }
end
