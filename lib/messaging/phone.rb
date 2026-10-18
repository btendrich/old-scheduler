module Messaging
  # US numbers. Stored mobiles keep their punctuation; Twilio speaks E.164.
  module Phone
    def self.e164(number)
      digits = national(number)
      return unless digits.length == 10

      "+1#{digits}"
    end

    def self.same?(left, right)
      national(left).present? && national(left) == national(right)
    end

    def self.national(number)
      digits = number.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("1") if digits.length == 11 && digits.start_with?("1")
      digits
    end
  end
end
