require "test_helper"

class ContactMailerTest < ActionMailer::TestCase
  test "contact_email" do
    mail = ContactMailer.contact_email("Test User", "test@example.com", "9876543210", "Hello there!")
    assert_equal "New Contact Us Inquiry from Test User", mail.subject
    assert_equal ["contactus@jeenimilletmix.in"], mail.to
    assert_match "Test User", mail.body.encoded
  end
end
