class Testimonial < ApplicationRecord
  belongs_to :product, class_name: 'Spree::Product', optional: true
  has_one_attached :image

  validates :author_name, presence: true
  validates :content, presence: true
  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }

  scope :active, -> { where(active: true) }
  scope :success_stories, -> { where(is_success_story: true) }
end
