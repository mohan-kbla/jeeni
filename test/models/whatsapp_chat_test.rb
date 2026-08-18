require "test_helper"

class WhatsappChatTest < ActiveSupport::TestCase
  test "sets default state and metadata on initialization" do
    chat = WhatsappChat.new(phone_number: "+123456789")
    assert_equal "idle", chat.state
    assert_equal({}, chat.metadata)
  end

  test "validates state inclusion" do
    chat = WhatsappChat.new(phone_number: "+123456789", state: "invalid_state")
    assert_not chat.valid?
    assert_includes chat.errors[:state], "is not included in the list"

    chat.state = "selecting_product"
    assert chat.valid?
  end

  test "validates uniqueness of phone_number" do
    WhatsappChat.create!(phone_number: "+123456789")
    duplicate = WhatsappChat.new(phone_number: "+123456789")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:phone_number], "has already been taken"
  end

  test "updates metadata correctly" do
    chat = WhatsappChat.create!(phone_number: "+123456789")
    chat.update_metadata("name", "Alice")
    assert_equal "Alice", chat.get_metadata("name")

    chat.update_metadata("age", 30)
    assert_equal 30, chat.get_metadata("age")

    chat.clear_metadata!
    assert_equal({}, chat.metadata)
  end
end
