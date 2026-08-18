class ContactMailer < ApplicationMailer

  def contact_email(name, email, mobile, message)
    @name = name
    @email = email
    @mobile = mobile
    @message = message

    mail(
      to: 'contactus@jeenimilletmix.in',
      reply_to: @email,
      subject: "New Contact Us Inquiry from #{@name}"
    )
  end
end
