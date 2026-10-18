module ApplicationHelper
  def venue_time(time)
    time.strftime("%a %-m/%-d %-I:%M %p")
  end
end
