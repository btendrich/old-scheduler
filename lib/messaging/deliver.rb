module Messaging
  class Deliver
    def initialize(gateway: Messaging.gateway)
      @gateway = gateway
    end

    def call(employee:, body:)
      message = employee.messages.create!(
        direction: "outbound",
        body: body,
        mobile: employee.mobile,
        sent_at: Time.current
      )
      @gateway.deliver(to: message.mobile, body: message.body)
      message
    end
  end
end
