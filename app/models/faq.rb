class Faq < ApplicationRecord
  belongs_to :product, class_name: 'Spree::Product', optional: true

  validates :question, presence: true
  validates :answer, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :asc) }
end
