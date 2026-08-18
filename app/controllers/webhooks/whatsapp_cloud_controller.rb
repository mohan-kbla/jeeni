module Webhooks
  class WhatsappCloudController < ApplicationController
    skip_before_action :verify_authenticity_token

    def verify
      verify_token = ENV.fetch("WHATSAPP_CLOUD_VERIFY_TOKEN", "mock_cloud_verify_token")

      if params["hub.mode"] == "subscribe" && params["hub.verify_token"] == verify_token
        render plain: params["hub.challenge"]
      else
        render plain: "Forbidden", status: :forbidden
      end
    end

    def receive
      entry = params["entry"]
      if entry.is_a?(Array)
        entry.each do |e|
          changes = e["changes"]
          next unless changes.is_a?(Array)

          changes.each do |change|
            value = change["value"]
            next unless value.is_a?(Hash) || value.is_a?(ActionController::Parameters)

            messages = value["messages"]
            next unless messages.is_a?(Array)

            # Get profile name if available
            contacts = value["contacts"]
            profile_name = nil
            if contacts.is_a?(Array) && contacts.any?
              profile_name = contacts.first.dig("profile", "name")
            end

            messages.each do |message|
              message_id = message["id"]
              next if message_id.blank?

              # Idempotency check: prevent duplicate processing of the same message ID
              # We use a transaction/find_or_create to ensure atomicity
              processed = false
              begin
                msg_record = WhatsappMessage.new(
                  message_id: message_id,
                  wa_id: message["from"],
                  message_type: message["type"],
                  payload: message.to_json
                )
                if msg_record.save
                  processed = true
                else
                  # Already exists or validation failed
                  Rails.logger.info("WhatsApp Cloud Webhook: Message ID #{message_id} already processed. Skipping.")
                end
              rescue ActiveRecord::RecordNotUnique
                Rails.logger.info("WhatsApp Cloud Webhook: Message ID #{message_id} (not unique exception) already processed. Skipping.")
              end

              next unless processed

              # Mark message as read (optional, good practice)
              Whatsapp::CloudApiClient.mark_as_read(message_id)

              from = message["from"]
              body = nil
              selected_button_id = nil

              case message["type"]
              when "text"
                body = message.dig("text", "body")
              when "interactive"
                interactive = message["interactive"]
                if interactive.is_a?(Hash) || interactive.is_a?(ActionController::Parameters)
                  type = interactive["type"]
                  if type == "button_reply"
                    selected_button_id = interactive.dig("button_reply", "id")
                    body = interactive.dig("button_reply", "title")
                  elsif type == "list_reply"
                    selected_button_id = interactive.dig("list_reply", "id")
                    body = interactive.dig("list_reply", "title")
                  end
                end
              end

              if from.present? && (body.present? || selected_button_id.present?)
                # Process conversation synchronously
                Whatsapp::CloudConversationEngine.call(
                  from,                 # wa_id
                  from,                 # phone_number
                  profile_name || from, # customer_name (fallback to phone if profile name missing)
                  body,                 # message_body
                  selected_button_id    # selected_button_id
                )
              end

              # Update the message record with processed timestamp
              msg_record.update!(processed_at: Time.current) if msg_record.persisted?
            end
          end
        end
      end

      head :ok
    rescue => e
      Rails.logger.error("WhatsApp Cloud Webhook Exception: #{e.message}\n#{e.backtrace.join("\n")}")
      head :ok
    end
  end
end
