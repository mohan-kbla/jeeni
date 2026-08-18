class ProductGallery < ApplicationRecord
  belongs_to :product, class_name: 'Spree::Product'

  has_many :gallery_images, -> { order(position: :asc) }, dependent: :destroy
  has_many :gallery_videos, -> { order(position: :asc) }, dependent: :destroy

  accepts_nested_attributes_for :gallery_images, allow_destroy: true
  accepts_nested_attributes_for :gallery_videos, allow_destroy: true

  def new_images
    @new_images
  end

  def new_images=(files)
    @new_images = files
    if files.present? && files.any?(&:present?)
      self.updated_at = Time.current if persisted?
    end
  end

  def new_videos
    @new_videos
  end

  def new_videos=(files)
    @new_videos = files
    if files.present? && files.any?(&:present?)
      self.updated_at = Time.current if persisted?
    end
  end

  def featured_image_id
    @featured_image_id
  end

  def featured_image_id=(val)
    @featured_image_id = val
    if val.present?
      self.updated_at = Time.current if persisted?
    end
  end

  def featured_video_id
    @featured_video_id
  end

  def featured_video_id=(val)
    @featured_video_id = val
    if val.present?
      self.updated_at = Time.current if persisted?
    end
  end

  before_save :build_new_media
  before_save :set_featured_image
  before_save :set_featured_video

  private

  def build_new_media
    if new_images.present?
      new_images.each do |file|
        next if file.blank?
        self.gallery_images.build(file: file)
      end
    end

    if new_videos.present?
      new_videos.each do |file|
        next if file.blank?
        self.gallery_videos.build(file: file)
      end
    end

    if youtube_link.present?
      self.gallery_videos.build(external_url: youtube_link)
      self.youtube_link = nil
    end
  end

  def set_featured_image
    # 1. If a valid, non-destroyed featured image is selected, use it.
    target = nil
    if featured_image_id.present?
      target = self.gallery_images.find { |gi| gi.id.to_s == featured_image_id.to_s }
      target = nil if target&.marked_for_destruction?
    end

    # 2. Otherwise, fall back to the first available image that is not marked for destruction.
    if target.nil?
      target = self.gallery_images.reject(&:marked_for_destruction?).first
    end

    # 3. Apply the featured flags.
    if target
      self.gallery_images.where.not(id: target.id).update_all(is_featured: false)
      target.is_featured = true
      target.save if target.persisted?
    else
      self.gallery_images.update_all(is_featured: false)
    end
  end

  def set_featured_video
    # 1. If a valid, non-destroyed featured video is selected, use it.
    target = nil
    if featured_video_id.present?
      target = self.gallery_videos.find { |gv| gv.id.to_s == featured_video_id.to_s }
      target = nil if target&.marked_for_destruction?
    end

    # 2. Otherwise, fall back to the first available video that is not marked for destruction.
    if target.nil?
      target = self.gallery_videos.reject(&:marked_for_destruction?).first
    end

    # 3. Apply the featured flags.
    if target
      self.gallery_videos.where.not(id: target.id).update_all(is_featured: false)
      target.is_featured = true
      target.save if target.persisted?
    else
      self.gallery_videos.update_all(is_featured: false)
    end
  end
end
