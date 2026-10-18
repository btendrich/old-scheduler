module Messaging
  class FakeGateway
    attr_reader :deliveries

    def initialize
      @deliveries = []
    end

    def deliver(to:, body:)
      deliveries << { to: to, body: body }
    end
  end
end
