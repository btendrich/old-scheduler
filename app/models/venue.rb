class Venue < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :employees
  has_many :skill_categories
  has_many :clients
  has_many :locations
  has_many :call_types
  has_many :position_labels
  has_many :template_lists
  has_many :bosses, dependent: :destroy

  validates :name, presence: true
  validates :time_zone, presence: true
  validate :time_zone_is_known

  # A window whose start and end match is all day. Offers wait; replies do not.
  def send_window_open?(at = Time.current, start_at: send_window_start, finish_at: send_window_end)
    return true if start_at.blank? || finish_at.blank?
    return true if start_at.hour == finish_at.hour && start_at.min == finish_at.min

    minutes = at.in_time_zone(time_zone).hour * 60 + at.in_time_zone(time_zone).min
    start_min = start_at.hour * 60 + start_at.min
    finish_min = finish_at.hour * 60 + finish_at.min
    if start_min < finish_min
      minutes >= start_min && minutes < finish_min
    else
      minutes >= start_min || minutes < finish_min
    end
  end

  def schedule_next_reminder(from = Time.current)
    at = following_reminder_at(from)
    update!(next_reminder_at: at)
    EveningReminderJob.set(wait_until: at).perform_later(id)
  end

  def following_reminder_at(from = Time.current)
    zone = Time.find_zone(time_zone)
    local = from.in_time_zone(zone)
    clock = reminder_time.utc
    candidate = zone.local(local.year, local.month, local.day, clock.hour, clock.min)
    candidate > from ? candidate : candidate + 1.day
  end

  def next_send_window_open(from = Time.current, start_at: send_window_start, finish_at: send_window_end)
    return from if send_window_open?(from, start_at: start_at, finish_at: finish_at)

    zone = Time.find_zone(time_zone)
    local = from.in_time_zone(zone)
    start_today = zone.local(local.year, local.month, local.day, start_at.hour, start_at.min)
    start_today > from ? start_today : start_today + 1.day
  end

  private
    def time_zone_is_known
      return if time_zone.blank?

      errors.add(:time_zone, "is not a known zone") unless ActiveSupport::TimeZone[time_zone]
    end
end
