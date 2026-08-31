class DailyCompanyUpdate < ApplicationRecord
  has_one_attached :media

  validates :media_type, presence: true, inclusion: { in: %w[image video] }
  validates :title, length: { maximum: 255 }
  validate :media_presence
  validate :media_format_and_size

  # Callback to ensure only one record is active at a time
  before_save :ensure_single_active, if: :active_changed_to_true?

  scope :active, -> { where(active: true) }

  private

  def active_changed_to_true?
    active? && (active_was == false || new_record?)
  end

  def ensure_single_active
    DailyCompanyUpdate.where.not(id: id).update_all(active: false)
  end

  def media_presence
    unless media.attached?
      errors.add(:media, "must be attached")
    end
  end

  def media_format_and_size
    return unless media.attached?

    # Size limit: 20MB for video, 5MB for image
    max_size = media_type == 'video' ? 20.megabytes : 5.megabytes
    if media.blob.byte_size > max_size
      size_mb = (max_size / 1.megabyte).to_i
      errors.add(:media, "file size is too large (max #{size_mb}MB)")
    end

    # Content type validation
    if media_type == 'image'
      acceptable_types = %w[image/jpeg image/jpg image/png image/webp]
      unless acceptable_types.include?(media.blob.content_type)
        errors.add(:media, "must be a JPEG, PNG, or WEBP image")
      end
    elsif media_type == 'video'
      acceptable_types = %w[video/mp4 video/webm]
      unless acceptable_types.include?(media.blob.content_type)
        errors.add(:media, "must be an MP4 or WEBM video")
      end
    end
  end
end
