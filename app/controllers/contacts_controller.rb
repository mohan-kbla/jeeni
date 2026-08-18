class ContactsController < ApplicationController
  def new
    # Render contact us page
  end

  def create
    name = params[:name]
    email = params[:email]
    mobile = params[:mobile]
    message = params[:message]

    # Send the email to jeenienterprise1@gmail.com
    begin
      ContactMailer.contact_email(name, email, mobile, message).deliver_now
    rescue => e
      Rails.logger.error("Failed to send contact email: #{e.message}")
    end

    flash[:notice] = "Thank you for getting in touch! We have received your message."
    redirect_to contact_us_path
  end
end
