class HomeController < ApplicationController
  def show
    calls = Call.for_venue(venue)
      .where("calls.ends_at > ?", Time.current)
      .chronological
      .includes(:location, :show, :fill_processes, call_slots: :current_assignment)
    @days = calls.group_by { |call| call.starts_at.in_time_zone.to_date }
  end
end
