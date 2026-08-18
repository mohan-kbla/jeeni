class GalleryVideo < ApplicationRecord
  belongs_to :product_gallery
  has_one_attached :file
  
  validate :file_or_external_url_present
  validate :validate_file_format_and_size

  def youtube_embed_url
    return nil if external_url.blank?

    if external_url.include?('youtube.com/watch?v=')
      video_id = external_url.split('v=')[1].split('&')[0]
      "https://www.youtube.com/embed/#{video_id}"
    elsif external_url.include?('youtu.be/')
      video_id = external_url.split('youtu.be/')[1].split('?')[0]
      "https://www.youtube.com/embed/#{video_id}"
    else
      external_url
    end
  end

  private

  def file_or_external_url_present
    return if marked_for_destruction?
    unless file.attached? || external_url.present?
      errors.add(:base, "Must have an uploaded video or an external URL")
    end
  end

  def validate_file_format_and_size
    return if marked_for_destruction?
    return unless file.attached?

    unless file.content_type.start_with?('video/')
      errors.add(:file, "must be a valid video file")
    end

    if file.blob.byte_size > 500.megabytes
      errors.add(:file, "size must be less than 500MB")
    end
  end
end
