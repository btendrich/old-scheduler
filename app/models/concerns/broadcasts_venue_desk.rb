# Every desk record that can name a venue refreshes the open desk. New models
# get this from ApplicationRecord once they implement #venue.
module BroadcastsVenueDesk
  extend ActiveSupport::Concern

  included do
    after_commit :broadcast_venue_desk
  end

  class_methods do
    def skip_venue_desk!
      @skip_venue_desk = true
    end

    def skip_venue_desk?
      @skip_venue_desk == true
    end
  end

  private
    def broadcast_venue_desk
      return if self.class.skip_venue_desk?
      return unless (record = venue_for_desk)
      return if record == self

      record.touch
    end

    def venue_for_desk
      return unless respond_to?(:venue)

      venue
    end
end
