class CallAvailability
  LABELS = {
    on_this_call: "On this call",
    declined: "Declined",
    time_conflict: "Time conflict",
    waiting_on_another_text: "Waiting on another text",
    waiting_on_this_text: "Waiting for a reply",
    available: "Available"
  }.freeze

  def self.build_all(employees, call)
    employees = employees.to_a
    ids = employees.map(&:id)
    currents = Assignment.current.where(employee_id: ids).includes(call_slot: :call).group_by(&:employee_id)
    on_call = Assignment.joins(:call_slot)
      .where(employee_id: ids, call_slots: { call_id: call.id })
      .order(created_at: :desc, id: :desc)
      .group_by(&:employee_id)
    waiting_ids = Question.open.where(employee_id: ids).where("questions.call_id IS DISTINCT FROM ?", call.id).distinct.pluck(:employee_id).to_set
    waiting_here_ids = Question.open.where(employee_id: ids, call_id: call.id).distinct.pluck(:employee_id).to_set
    declined_ids = Question.where(employee_id: ids, call_id: call.id, close_reason: "no").distinct.pluck(:employee_id).to_set

    employees.map do |employee|
      new(
        employee,
        call,
        currents: currents.fetch(employee.id, []),
        on_call: on_call.fetch(employee.id, []),
        waiting: waiting_ids.include?(employee.id),
        waiting_here: waiting_here_ids.include?(employee.id),
        fill_declined: declined_ids.include?(employee.id)
      )
    end
  end

  def initialize(employee, call, currents: nil, on_call: nil, waiting: nil, waiting_here: nil, fill_declined: nil)
    @employee = employee
    @call = call
    @currents = currents
    @on_call = on_call
    @waiting = waiting
    @waiting_here = waiting_here
    @fill_declined = fill_declined
  end

  attr_reader :employee

  def status
    return :on_this_call if on_this_call?
    return :declined if declined_this_call?
    return :time_conflict if time_conflict?
    return :waiting_on_another_text if waiting_on_another_text?
    return :waiting_on_this_text if waiting_on_this_text?

    :available
  end

  def label
    LABELS.fetch(status)
  end

  def option_label
    name = employee.name
    name = "#{name} (inactive)" unless employee.active?
    "#{name} - #{label}"
  end

  def placeable?
    !on_this_call?
  end

  def on_this_call?
    latest = latest_on_this_call
    latest.present? && latest.released_at.nil?
  end

  def declined_this_call?
    latest = latest_on_this_call
    if latest.present?
      latest.released_at.present? && latest.confirmation == "declined"
    else
      fill_no?
    end
  end

  def time_conflict?
    current_assignments.any? do |assignment|
      other = assignment.call_slot.call
      other.id != @call.id && other.overlaps?(@call)
    end
  end

  def waiting_on_another_text?
    return @waiting unless @waiting.nil?

    Question.open.where(employee_id: employee.id).where("questions.call_id IS DISTINCT FROM ?", @call.id).exists?
  end

  def waiting_on_this_text?
    return @waiting_here unless @waiting_here.nil?

    Question.open.exists?(employee_id: employee.id, call_id: @call.id)
  end

  private
    def latest_on_this_call
      records = if @on_call.nil?
        Assignment.joins(:call_slot)
          .where(employee_id: employee.id, call_slots: { call_id: @call.id })
          .order(created_at: :desc, id: :desc)
          .to_a
      else
        @on_call
      end

      records.max_by { |assignment| [ assignment.created_at, assignment.id ] }
    end

    def fill_no?
      return @fill_declined unless @fill_declined.nil?

      Question.where(employee_id: employee.id, call_id: @call.id, close_reason: "no").exists?
    end

    def current_assignments
      return @currents unless @currents.nil?

      Assignment.current.where(employee_id: employee.id).includes(call_slot: :call).to_a
    end
end
