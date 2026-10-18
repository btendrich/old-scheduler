class Call < ApplicationRecord
  belongs_to :show
  belongs_to :location
  belongs_to :call_type
  has_many :fill_processes, dependent: :destroy
  has_many :call_slots, -> { order(:sort_order, :id) }, dependent: :destroy
  has_many :questions, dependent: :destroy

  validates :starts_at, :ends_at, presence: true
  validate :ends_after_it_starts
  validate :records_share_the_show_venue

  scope :for_venue, ->(venue) { joins(show: :client).where(clients: { venue_id: venue.id }) }
  scope :chronological, -> { order(:starts_at, :id) }

  def venue
    show&.client&.venue
  end

  def venue_id
    venue&.id
  end

  # Touching endpoints are not an overlap. A call that ends when the next one starts is free.
  def overlaps?(other)
    starts_at < other.ends_at && ends_at > other.starts_at
  end

  # Show, clock, and place. The slot label stays off anything a person is texted.
  def schedule_phrase
    "#{show.name}, #{clock_range}, #{location.name}"
  end

  def departure_phrase
    "#{show.name}, #{in_venue_zone(starts_at).strftime("%a %-m/%-d %-I:%M %p")}"
  end

  def calendar_url
    Rails.application.routes.url_helpers.calendar_url(
      signed_id(purpose: :calendar),
      **Rails.application.config.action_mailer.default_url_options
    )
  end

  # The phone keeps whatever it saved. A later time change does not push a new copy.
  def to_ics
    start_at = in_venue_zone(starts_at)
    finish_at = in_venue_zone(ends_at)
    zone = start_at.time_zone.tzinfo.name
    offset = start_at.strftime("%z")
    [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Scheduler//Call//EN",
      "BEGIN:VTIMEZONE",
      "TZID:#{zone}",
      "BEGIN:STANDARD",
      "DTSTART:#{ics_stamp(start_at)}",
      "TZOFFSETFROM:#{offset}",
      "TZOFFSETTO:#{offset}",
      "TZNAME:#{start_at.strftime("%Z")}",
      "END:STANDARD",
      "END:VTIMEZONE",
      "BEGIN:VEVENT",
      "UID:call-#{id}@scheduler",
      "DTSTAMP:#{Time.current.utc.strftime("%Y%m%dT%H%M%SZ")}",
      "DTSTART;TZID=#{zone}:#{ics_stamp(start_at)}",
      "DTEND;TZID=#{zone}:#{ics_stamp(finish_at)}",
      "SUMMARY:#{ics_text(show.name)}",
      "LOCATION:#{ics_text(location.name)}",
      "END:VEVENT",
      "END:VCALENDAR"
    ].join("\r\n") + "\r\n"
  end

  private
    def clock_range
      start_at = in_venue_zone(starts_at)
      end_at = in_venue_zone(ends_at)
      start_text = start_at.strftime("%a %-m/%-d %-I:%M %p")
      end_text = if start_at.to_date == end_at.to_date
        end_at.strftime("%-I:%M %p")
      else
        end_at.strftime("%a %-m/%-d %-I:%M %p")
      end
      "#{start_text}–#{end_text}"
    end

    def in_venue_zone(time)
      time.in_time_zone(Time.find_zone(show.client.venue.time_zone))
    end

    def ics_stamp(time)
      time.strftime("%Y%m%dT%H%M%S")
    end

    def ics_text(value)
      value.to_s.gsub("\\", "\\\\\\\\").gsub(",", "\\,").gsub(";", "\\;").gsub("\n", "\\n")
    end

    def ends_after_it_starts
      return if starts_at.blank? || ends_at.blank?
      return if ends_at > starts_at

      errors.add(:ends_at, "must be after the start")
    end

    def records_share_the_show_venue
      return if show.blank?

      errors.add(:location, "is from another venue") if location && location.venue_id != venue_id
      errors.add(:call_type, "is from another venue") if call_type && call_type.venue_id != venue_id
    end
end
