class Call < ApplicationRecord
  belongs_to :show
  belongs_to :location
  belongs_to :call_type
  has_many :fill_processes, -> { order(:number, :id) }, dependent: :destroy
  has_many :call_slots, -> { order(:sort_order, :id) }, dependent: :destroy
  has_many :questions, dependent: :destroy
  has_many :audit_logs, dependent: :nullify

  def outcome_logs
    audit_logs.outcomes.chronological
  end

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

  # Short label for desk pickers (link source, partner chip).
  def desk_label
    "#{call_type.name} · #{clock_range}"
  end

  def departure_phrase
    "#{show.name}, #{in_venue_zone(starts_at).strftime("%a %-m/%-d %-I:%M %p")}"
  end

  def filled_slot_count
    call_slots.count { |slot| slot.current_assignment.present? }
  end

  Progress = Data.define(:slots, :confirmed, :awaiting, :on_fill) do
    def confirmed_percent
      return 0 if slots.zero?

      ((confirmed * 100.0) / slots).round
    end
  end

  def progress
    slots = call_slots.to_a
    Progress.new(
      slots: slots.size,
      confirmed: slots.count { |slot| slot.current_assignment&.confirmed? },
      awaiting: slots.count { |slot| slot.current_assignment&.pending_question? },
      on_fill: slots.count(&:fill_slot)
    )
  end

  def needs_review?
    call_slots.any? { |slot| slot.current_assignment&.needs_review? }
  end

  def needs_more_names?
    fill_processes.any? { |process| process.status == "needs_more_names" }
  end

  # Copy another call's slot labels in order and link each new slot to its source.
  def inherit_slots_from!(source)
    source.call_slots.order(:sort_order, :id).each do |source_slot|
      slot = call_slots.create!(position_label: source_slot.position_label)
      slot.link_to!(source_slot)
    end
  end

  # Replies and fills the desk should look at before treating the call as settled.
  def review_items
    items = call_slots.flat_map { |slot| slot.current_assignment&.review_item || [] }
    items << "A fill needs more names" if needs_more_names?
    items
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
