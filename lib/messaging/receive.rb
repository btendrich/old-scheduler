module Messaging
  class Receive
    def call(employee:, body:)
      ApplicationRecord.transaction do
        message = employee.messages.create!(
          direction: "inbound",
          body: body,
          mobile: employee.mobile,
          sent_at: Time.current
        )
        Reply.apply(message)
        message
      end
    end
  end
end
