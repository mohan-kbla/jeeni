class Blog < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  # Associations
  has_many :comments, dependent: :destroy

  # Validations
  validates :title, presence: true, length: { minimum: 5 }
  validates :body, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, presence: true

  # Scopes
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(published_at: :desc, created_at: :desc) }

  # Callbacks
  before_save :set_published_at, if: :will_save_change_to_published?

  # Helper methods for tags
  def tag_list
    tags.to_s.split(',').map(&:strip).reject(&:empty?)
  end

  def tag_list=(names)
    self.tags = names.is_a?(Array) ? names.join(', ') : names
  end

  private

  def set_published_at
    if published?
      self.published_at ||= Time.current
    else
      self.published_at = nil
    end
  end
end
