require "net/http"
require "uri"
require "json"

module Whatsapp
  class Client
    class << self
      def send_message(to, body)
        access_token = ENV["WHATSAPP_ACCESS_TOKEN"]
        phone_number_id = ENV["WHATSAPP_PHONE_NUMBER_ID"]

        if access_token.blank? || phone_number_id.blank?
          # Mock behavior when credentials are not configured
          log_mock_message(to, body)
          return mock_success_response(to, body)
        end

        uri = URI.parse("https://graph.facebook.com/v20.0/#{phone_number_id}/messages")
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request["Authorization"] = "Bearer #{access_token}"
        request.body = JSON.dump({
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: to,
          type: "text",
          text: {
            preview_url: false,
            body: body
          }
        })

        req_options = {
          use_ssl: uri.scheme == "https"
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        unless response.code.to_i == 200
          Rails.logger.error("WhatsApp API Error: #{response.code} - #{response.body}")
        end

        response
      rescue => e
        Rails.logger.error("WhatsApp Send Message Exception: #{e.message}")
        nil
      end

      private

      def log_mock_message(to, body)
        log_file = Rails.root.join("log", "whatsapp_mock.log")
        message = "[#{Time.current.iso8601}] TO: #{to}\nBODY: #{body}\n#{'-' * 40}\n"
        File.open(log_file, "a") { |f| f.write(message) }
        Rails.logger.info("WhatsApp Mock Sent: TO: #{to}, BODY: #{body}")
      end

      def mock_success_response(to, body)
        # Mock response structure for compatibility
        Struct.new(:code, :body).new("200", {
          messaging_product: "whatsapp",
          contacts: [{ input: to, wa_id: to }],
          messages: [{ id: "wamid.mock_message_id_#{SecureRandom.hex(8)}" }]
        }.to_json)
      end
    end
  end
end
