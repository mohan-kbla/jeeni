require "net/http"
require "uri"
require "json"

module Whatsapp
  class CloudApiClient
    class << self
      def send_text(to, text)
        post_request(to, {
          type: "text",
          text: { body: text }
        })
      end

      def send_buttons(to, text, buttons_data)
        # buttons_data: array of hashes: [{ id: "button_id", title: "Button Label" }]
        buttons = buttons_data.map do |btn|
          {
            type: "reply",
            reply: { id: btn[:id], title: btn[:title] }
          }
        end

        post_request(to, {
          type: "interactive",
          interactive: {
            type: "button",
            body: { text: text },
            action: { buttons: buttons }
          }
        })
      end

      def send_list(to, text, button_text, sections_data)
        # sections_data: array of hashes: [{ title: "Sec Title", rows: [{ id: "row_id", title: "Row Title", description: "Desc" }] }]
        post_request(to, {
          type: "interactive",
          interactive: {
            type: "list",
            body: { text: text },
            action: {
              button: button_text,
              sections: sections_data
            }
          }
        })
      end

      def send_template(to, template_name, language_code = "en", components = [])
        post_request(to, {
          type: "template",
          template: {
            name: template_name,
            language: { code: language_code },
            components: components
          }
        })
      end

      def mark_as_read(message_id)
        post_raw_payload({
          messaging_product: "whatsapp",
          status: "read",
          message_id: message_id
        })
      end

      private

      def post_request(to, message_payload)
        payload = {
          messaging_product: "whatsapp",
          recipient_type: "individual",
          to: to
        }.merge(message_payload)

        post_raw_payload(payload)
      end

      def post_raw_payload(payload)
        access_token = ENV["WHATSAPP_CLOUD_API_TOKEN"]
        phone_number_id = ENV["WHATSAPP_CLOUD_PHONE_NUMBER_ID"]
        api_version = ENV.fetch("WHATSAPP_CLOUD_API_VERSION", "v20.0")

        if access_token.blank? || phone_number_id.blank?
          log_mock_payload(payload)
          return mock_success_response(payload)
        end

        uri = URI.parse("https://graph.facebook.com/#{api_version}/#{phone_number_id}/messages")
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request["Authorization"] = "Bearer #{access_token}"
        request.body = JSON.dump(payload)

        req_options = { use_ssl: uri.scheme == "https" }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        unless response.code.to_i == 200
          # Safe logging: do not print access_token
          Rails.logger.error("WhatsApp Cloud API Error: Status #{response.code} - #{response.body}")
        end

        response
      rescue => e
        Rails.logger.error("WhatsApp Cloud API Request Exception: #{e.message}")
        nil
      end

      def log_mock_payload(payload)
        log_file = Rails.root.join("log", "whatsapp_cloud_mock.log")
        message = "[#{Time.current.iso8601}] PAYLOAD: #{payload.to_json}\n#{'-' * 40}\n"
        File.open(log_file, "a") { |f| f.write(message) }
        Rails.logger.info("WhatsApp Cloud Mock Sent: #{payload.to_json}")
      end

      def mock_success_response(payload)
        # Mock response structure for compatibility
        to = payload[:to] || "unknown"
        message_id = "wamid.mock_cloud_#{SecureRandom.hex(8)}"
        Struct.new(:code, :body).new("200", {
          messaging_product: "whatsapp",
          contacts: [{ input: to, wa_id: to }],
          messages: [{ id: message_id }]
        }.to_json)
      end
    end
  end
end
