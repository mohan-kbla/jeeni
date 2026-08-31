require "test_helper"

# Stub ActiveStorage analysis to prevent background thread database connection locks
class ActiveStorage::Blob
  def analyze
    # No-op
  end

  def analyzed?
    true
  end
end

class DailyCompanyUpdateTest < ActiveSupport::TestCase
  test "should be invalid without media" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "image")
    assert_not update.valid?
    assert_includes update.errors[:media], "must be attached"
  end

  test "should be invalid with incorrect media type" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "invalid")
    update.media.attach(io: StringIO.new("test"), filename: "test.jpg", content_type: "image/jpeg")
    assert_not update.valid?
    assert_includes update.errors[:media_type], "is not included in the list"
  end

  test "should be invalid with wrong mime type for image" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "image")
    update.media.attach(io: StringIO.new("test"), filename: "test.txt", content_type: "text/plain")
    assert_not update.valid?
    assert_includes update.errors[:media], "must be a JPEG, PNG, or WEBP image"
  end

  test "should be invalid with wrong mime type for video" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "video")
    update.media.attach(io: StringIO.new("test"), filename: "test.png", content_type: "image/png")
    assert_not update.valid?
    assert_includes update.errors[:media], "must be an MP4 or WEBM video"
  end

  test "should be invalid with image over 5MB limit" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "image")
    update.media.attach(io: StringIO.new("test"), filename: "test.png", content_type: "image/png")
    def (update.media.blob).byte_size
      6.megabytes
    end
    assert_not update.valid?
    assert_includes update.errors[:media], "file size is too large (max 5MB)"
  end

  test "should be invalid with video over 20MB limit" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "video")
    update.media.attach(io: StringIO.new("test"), filename: "test.mp4", content_type: "video/mp4")
    def (update.media.blob).byte_size
      21.megabytes
    end
    assert_not update.valid?
    assert_includes update.errors[:media], "file size is too large (max 20MB)"
  end

  test "should be valid with correct image format and size" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "image")
    update.media.attach(io: StringIO.new("test"), filename: "test.jpg", content_type: "image/jpeg")
    assert update.valid?
  end

  test "should be valid with correct video format and size" do
    update = DailyCompanyUpdate.new(title: "Test", media_type: "video")
    update.media.attach(io: StringIO.new("test"), filename: "test.mp4", content_type: "video/mp4")
    assert update.valid?
  end

  test "activating an update should automatically deactivate previous active updates" do
    # Clear existing updates
    DailyCompanyUpdate.destroy_all

    update1 = DailyCompanyUpdate.new(title: "Update 1", media_type: "image", active: true)
    update1.media.attach(io: StringIO.new("test"), filename: "test1.jpg", content_type: "image/jpeg")
    update1.save!

    assert update1.reload.active?

    update2 = DailyCompanyUpdate.new(title: "Update 2", media_type: "image", active: true)
    update2.media.attach(io: StringIO.new("test"), filename: "test2.jpg", content_type: "image/jpeg")
    update2.save!

    assert update2.reload.active?
    assert_not update1.reload.active?
  end
end
