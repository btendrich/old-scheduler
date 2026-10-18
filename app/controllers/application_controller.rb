class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  around_action :use_venue_time_zone

  helper_method :venue

  private
    def venue
      Current.user&.venue
    end

    def use_venue_time_zone(&block)
      zone = Current.user&.venue&.time_zone
      zone.present? ? Time.use_zone(zone, &block) : yield
    end
end
