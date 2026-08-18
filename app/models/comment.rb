class Comment < ApplicationRecord
  # Associations
  belongs_to :blog
  belongs_to :user, class_name: 'Spree::User', foreign_key: 'user_id'

  # Validations
  validates :body, presence: true, length: { minimum: 2, maximum: 1000 }
  validates :status, presence: true, inclusion: { in: %w[pending approved rejected] }

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :rejected, -> { where(status: 'rejected') }
  scope :recent, -> { order(created_at: :desc) }

  # Moderation methods
  def approve!
    update(status: 'approved')
  end

  def reject!
    update(status: 'rejected')
  end

  def approved?
    status == 'approved'
  end

  def pending?
    status == 'pending'
  end

  def rejected?
    status == 'rejected'
  end
end
