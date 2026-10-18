module Messaging
  class DeliveryError < StandardError; end

  class TwilioGateway
    def self.configured?
      account_sid.present? && auth_token.present? && from_number.present?
    end

    def self.account_sid
      ENV["TWILIO_ACCOUNT_SID"].presence || Rails.application.credentials.dig(:twilio, :account_sid)
    end

    def self.auth_token
      ENV["TWILIO_AUTH_TOKEN"].presence || Rails.application.credentials.dig(:twilio, :auth_token)
    end

    def self.from_number
      ENV["TWILIO_FROM_NUMBER"].presence || Rails.application.credentials.dig(:twilio, :from_number)
    end

    # Twilio signs the exact URL plus the POST fields, sorted by name.
    def self.signature(url, params, token)
      payload = url.to_s + params.map { |key, value| [ key.to_s, value.to_s ] }.sort.map(&:join).join
      Base64.strict_encode64(OpenSSL::HMAC.digest("SHA1", token.to_s, payload))
    end

    def self.valid_signature?(url, params, header)
      return false if auth_token.blank? || header.blank?

      expected = signature(url, params, auth_token)
      return false unless expected.bytesize == header.bytesize

      ActiveSupport::SecurityUtils.secure_compare(expected, header)
    end

    def initialize(transport: nil)
      @transport = transport
    end

    def deliver(to:, body:)
      raise DeliveryError, "Twilio is not configured" unless self.class.configured?

      destination = Phone.e164(to)
      raise DeliveryError, "That mobile number is not a US number" if destination.blank?

      request = Net::HTTP::Post.new(path)
      request.basic_auth(self.class.account_sid, self.class.auth_token)
      request.form_data = { "From" => Phone.e164(self.class.from_number), "To" => destination, "Body" => body }
      response = transport(request)
      return if response.is_a?(Net::HTTPSuccess)

      raise DeliveryError, "Twilio returned #{response.code}"
    end

    private
      def path
        "/2010-04-01/Accounts/#{self.class.account_sid}/Messages.json"
      end

      def transport(request)
        return @transport.call(request) if @transport

        uri = URI("https://api.twilio.com#{request.path}")
        Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
          http.request(request)
        end
      end
  end
end
