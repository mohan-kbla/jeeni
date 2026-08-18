class GalleryImage < ApplicationRecord
  belongs_to :product_gallery
  has_one_attached :file
  
  validates :file, presence: true
  validate :validate_file_format_and_size

  private

  def validate_file_format_and_size
    return if marked_for_destruction?
    return unless file.attached?

    unless file.content_type.in?(%w[image/jpeg image/png image/gif image/webp image/jpg])
      errors.add(:file, "must be a JPEG, PNG, GIF, or WEBP image")
    end

    if file.blob.byte_size > 10.megabytes
      errors.add(:file, "size must be less than 10MB")
    end
  end
end
