# Bookings that still stand. A released assignment is neither past work nor a future call.
# A call counts as worked once it has ended, and as coming up until it starts.
class WorkRecord
  WINDOWS = [ 3, 6, 12 ].freeze

  def self.for(employees, now: Time.current)
    list = Array(employees)
    return {} if list.empty?

    grouped = Assignment.current
      .where(employee_id: list.map(&:id))
      .includes(call_slot: { call: [ :show, :location ] })
      .group_by(&:employee_id)

    list.to_h { |employee| [ employee.id, new(grouped.fetch(employee.id, []), now: now) ] }
  end

  def initialize(assignments, now: Time.current)
    @calls = assignments.filter_map { |assignment| assignment.call_slot.call }.uniq(&:id)
    @now = now
  end

  def last_worked
    finished.max_by { |call| [ call.ends_at, call.id ] }
  end

  def in_progress
    @calls.select { |call| call.starts_at <= @now && call.ends_at > @now }.sort_by { |call| [ call.starts_at, call.id ] }
  end

  def upcoming
    @calls.select { |call| call.starts_at > @now }.sort_by { |call| [ call.starts_at, call.id ] }
  end

  def next_call
    upcoming.first
  end

  def later_count
    [ upcoming.size - 1, 0 ].max
  end

  def counts
    WINDOWS.index_with { |months| finished.count { |call| call.ends_at >= @now - months.months } }
  end

  private
    def finished
      @calls.select { |call| call.ends_at <= @now }
    end
end
