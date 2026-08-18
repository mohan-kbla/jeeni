module Webhooks
  class WhatsappController < ApplicationController
    skip_before_action :verify_authenticity_token

    def verify
      verify_token = ENV.fetch("WHATSAPP_VERIFY_TOKEN", "mock_verify_token")

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

            messages.each do |message|
              next unless message["type"] == "text"

              from = message["from"]
              body = message.dig("text", "body")

              if from.present? && body.present?
                Whatsapp::ProcessorService.call(from, body)
              end
            end
          end
        end
      end

      head :ok
    rescue => e
      Rails.logger.error("WhatsApp Webhook Exception: #{e.message}\n#{e.backtrace.join("\n")}")
      head :ok
    end
  end
end
