module ApplicationHelper
  ICONS = {
    calls: "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5",
    employees: "M15 19.128a9.38 9.38 0 0 0 2.625.372 9.337 9.337 0 0 0 4.121-.952 4.125 4.125 0 0 0-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 0 1 8.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0 1 11.964-3.07M12 6.375a3.375 3.375 0 1 1-6.75 0 3.375 3.375 0 0 1 6.75 0Zm8.25 2.25a2.625 2.625 0 1 1-5.25 0 2.625 2.625 0 0 1 5.25 0Z",
    lists: "M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 0 1 0 3.75H5.625a1.875 1.875 0 0 1 0-3.75Z",
    skills: "M9.568 3H5.25A2.25 2.25 0 0 0 3 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 0 0 5.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 0 0 9.568 3Z",
    clients: "M3.75 21h16.5M4.5 3h15M5.25 3v18m13.5-18v18M9 6.75h1.5m-1.5 3h1.5m-1.5 3h1.5m3-6H15m-1.5 3H15m-1.5 3H15M9 21v-3.375c0-.621.504-1.125 1.125-1.125h3.75c.621 0 1.125.504 1.125 1.125V21",
    setup: "M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.325.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 0 1 1.37.49l1.296 2.247a1.125 1.125 0 0 1-.26 1.431l-1.003.827c-.293.241-.438.613-.43.992a7.723 7.723 0 0 1 0 .255c-.008.378.137.75.43.991l1.004.827c.424.35.534.955.26 1.43l-1.298 2.247a1.125 1.125 0 0 1-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.47 6.47 0 0 1-.22.128c-.331.183-.581.495-.644.869l-.213 1.281c-.09.543-.56.94-1.11.94h-2.594c-.55 0-1.019-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 0 1-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 0 1-1.369-.49l-1.297-2.247a1.125 1.125 0 0 1 .26-1.431l1.004-.827c.292-.24.437-.613.43-.991a6.932 6.932 0 0 1 0-.255c.007-.38-.138-.751-.43-.992l-1.004-.827a1.125 1.125 0 0 1-.26-1.43l1.297-2.247a1.125 1.125 0 0 1 1.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.086.22-.128.332-.183.582-.495.644-.869l.214-1.28Z",
    phone: "M10.5 1.5H8.25A2.25 2.25 0 0 0 6 3.75v16.5a2.25 2.25 0 0 0 2.25 2.25h7.5A2.25 2.25 0 0 0 18 20.25V3.75a2.25 2.25 0 0 0-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3",
    logout: "M15.75 9V5.25A2.25 2.25 0 0 0 13.5 3h-6a2.25 2.25 0 0 0-2.25 2.25v13.5A2.25 2.25 0 0 0 7.5 21h6a2.25 2.25 0 0 0 2.25-2.25V15m3 0 3-3m0 0-3-3m3 3H9",
    sort: "M8.25 15 12 18.75 15.75 15m-7.5-6L12 5.25 15.75 9",
    sort_up: "m4.5 15.75 7.5-7.5 7.5 7.5",
    sort_down: "m19.5 8.25-7.5 7.5-7.5-7.5",
    play: "M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 0 1 0 1.972l-11.54 6.347a1.125 1.125 0 0 1-1.667-.986V5.653Z",
    pause: "M15.75 5.25v13.5m-7.5-13.5v13.5",
    plus: "M12 4.5v15m7.5-7.5h-15",
    check: "M4.5 12.75 10.5 18.75 19.5 5.25",
    alert: "M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z",
    trash: "m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0",
    audit: "M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18A2.25 2.25 0 0 0 20.25 16.5V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75 2.25 2.25 0 0 0-.1-.664m-5.8 0A2.251 2.251 0 0 1 5.25 6h.008a2.25 2.25 0 0 1 2.242 2.108 48.6 48.6 0 0 1 1.123.08M15.75 18H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08M8.25 6h.008",
    clock: "M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z",
    x: "M6 18 18 6M6 6l12 12"
  }.freeze

  FILL_PHASES = {
    "new" => { label: "New", icon: :plus, tone: "bg-stone-100 text-stone-700 ring-stone-200" },
    "running" => { label: "Running", icon: :play, tone: "bg-amber-50 text-amber-800 ring-amber-200" },
    "paused" => { label: "Paused", icon: :pause, tone: "bg-sky-50 text-sky-800 ring-sky-200" },
    "needs_names" => { label: "Needs names", icon: :alert, tone: "bg-red-50 text-red-800 ring-red-200" },
    "complete" => { label: "Complete", icon: :check, tone: "bg-emerald-50 text-emerald-800 ring-emerald-200" }
  }.freeze

  # Level 3 is the center. Marks step down to the left and up to the right.
  LEVEL_MARKS = {
    1 => { name: "well below normal", path: "m4.5 5.25 7.5 7.5 7.5-7.5m-15 6 7.5 7.5 7.5-7.5" },
    2 => { name: "below normal", path: "m19.5 8.25-7.5 7.5-7.5-7.5" },
    3 => { name: "normal", path: "M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z" },
    4 => { name: "above normal", path: "m4.5 15.75 7.5-7.5 7.5 7.5" },
    5 => { name: "well above normal", path: "m4.5 18.75 7.5-7.5 7.5 7.5m-15-6 7.5-7.5 7.5 7.5" }
  }.freeze

  def venue_time(time)
    time.strftime("%a %-m/%-d %-I:%M %p")
  end

  def call_summary(call)
    "#{call.show.name} · #{call.location.name} · #{venue_time(call.starts_at)}"
  end

  def employee_option_name(employee)
    employee.active? ? employee.name : "#{employee.name} (inactive)"
  end

  # The legal first name, shown beside the display name only when a preferred name replaces it.
  def employee_given_name(employee)
    return if employee.preferred_name.blank? || employee.preferred_name.casecmp?(employee.first_name)

    employee.first_name
  end

  def employee_contact(employee)
    parts = [ employee_given_name(employee), employee.mobile ]
    parts << employee.email if employee.email.present?
    parts.compact.join(" · ")
  end

  # The host element carries data-controller="employee-card". The card itself is shared across pages.
  def employee_card_template(employee, record: nil)
    record ||= WorkRecord.for([ employee ]).fetch(employee.id)
    tag.template(data: { employee_card_target: "source" }) do
      render "employees/card", employee: employee, record: record
    end
  end

  def icon(name, html_class: "size-5 shrink-0")
    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24",
      "stroke-width": "1.5",
      stroke: "currentColor",
      class: html_class,
      aria: { hidden: true }
    ) do
      tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: ICONS.fetch(name))
    end
  end

  def level_name(level)
    LEVEL_MARKS.fetch(level)[:name]
  end

  def level_icon(level)
    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24",
      "stroke-width": "1.5",
      stroke: "currentColor",
      class: "size-5",
      aria: { hidden: true }
    ) do
      tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: LEVEL_MARKS.fetch(level)[:path])
    end
  end

  def remove_icon
    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24",
      "stroke-width": "1.5",
      stroke: "currentColor",
      class: "size-4",
      aria: { hidden: true }
    ) do
      tag.path("stroke-linecap": "round", "stroke-linejoin": "round", d: "M6 18 18 6M6 6l12 12")
    end
  end

  def drag_handle
    tag.span(icon(:lists), class: "drag-handle", aria: { hidden: true })
  end

  def nav_link(name, path, icon_name, active: nil)
    on = active.nil? ? nav_current?(path) : active
    tone = on ? "bg-white/15 text-white" : "text-stone-300 hover:bg-white/10 hover:text-white"
    link_to path, class: "flex items-center gap-2 rounded-md px-3 py-2 text-sm font-medium no-underline #{tone}" do
      safe_join([ icon(icon_name), name ])
    end
  end

  def page_header(title, lede: nil, &block)
    actions = tag.div(capture(&block), class: "flex flex-wrap items-center gap-2") if block
    heading = tag.div do
      safe_join([
        tag.h1(title),
        (tag.p(lede, class: "mt-1 max-w-2xl text-sm text-stone-500") if lede.present?)
      ].compact)
    end
    tag.header(class: "mb-6 flex flex-wrap items-end justify-between gap-3") do
      safe_join([ heading, actions ].compact)
    end
  end

  # Tone is the row color. The words are the same status, for anyone who cannot use the color.
  def fill_candidate_mark(candidate, availability)
    case candidate.state
    when "asked" then [ "awaiting", "Awaiting reply" ]
    when "booked", "parked" then [ "available", "Responded available" ]
    when "declined" then [ "unavailable", "Responded unavailable" ]
    when "timed_out" then [ "timed-out", "Timed out" ]
    when "passed" then [ "passed", "Passed" ]
    else
      case availability&.status
      when :time_conflict then [ "conflict", "Time conflict" ]
      when :on_this_call then [ "conflict", "On this call" ]
      when :declined then [ "unavailable", "Responded unavailable" ]
      when :waiting_on_another_text then [ "waiting", "Waiting on another text" ]
      when :waiting_on_this_text then [ "waiting", "Waiting for a reply" ]
      else [ "queued", "In queue" ]
      end
    end
  end

  def audit_log_lines(entries, zone:)
    entries.map { |entry|
      stamp = entry.created_at.in_time_zone(zone).strftime("%a %-m/%-d %-I:%M %p")
      [ stamp, entry.kind.humanize, entry.actor_name, entry.detail ].compact.join(" · ")
    }.join("\n")
  end

  def fill_log_lines(process)
    zone = ActiveSupport::TimeZone[process.call.venue.time_zone]
    process.events.sort_by { |event| [ event.created_at, event.id ] }.map { |event|
      stamp = (event.times.to_i > 1 ? event.updated_at : event.created_at).in_time_zone(zone).strftime("%a %-m/%-d %-I:%M %p")
      detail = event.detail
      if event.times.to_i > 1
        extra = event.times - 1
        detail = [ detail, "last message repeated #{extra} #{'time'.pluralize(extra)}" ].compact.join(" · ")
      end
      [ stamp, event.kind.humanize, event.employee&.name, detail ].compact.join(" · ")
    }.join("\n")
  end

  def status_badge(label)
    tone = case label
    when "Available", "Confirmed by reply", "Confirmed by desk", "Finished", "Complete", "Booked" then "bg-emerald-50 text-emerald-800 ring-emerald-200"
    when "On this call", "Pending", "New", "Assigned", "Asked", "Released" then "bg-stone-100 text-stone-700 ring-stone-200"
    when "Open", "Unconfirmed" then "bg-red-50 text-red-800 ring-red-200"
    when "Time conflict", "Waiting on another text", "Waiting for a reply", "Filling", "Running", "Started" then "bg-amber-50 text-amber-800 ring-amber-200"
    when "Paused" then "bg-sky-50 text-sky-800 ring-sky-200"
    when "Declined", "Needs review", "Needs more names", "Needs names", "Cannot make it", "Cancelled", "Backed out" then "bg-red-50 text-red-800 ring-red-200"
    when "Timed out" then "bg-violet-50 text-violet-800 ring-violet-200"
    else "bg-stone-100 text-stone-600 ring-stone-200"
    end
    tag.span(label, class: "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset #{tone}")
  end

  def slot_list_status(assignment)
    return "Open" unless assignment
    return "Declined" if assignment.confirmation == "declined"
    return "Waiting for a reply" if assignment.pending_question?
    return "Open" if assignment.confirmation == "unconfirmed"

    assignment.confirmation_label
  end

  def slot_link_label(slot)
    partner = slot.partner_slot
    return unless partner

    "#{partner.call.call_type.name} · #{partner.label_name}"
  end

  def slot_release_label(assignment)
    return "Cancelled" if assignment.cancelled?
    return "Declined" if assignment.confirmation == "declined"

    assignment.confirmation_label
  end

  # Declines, cancels, and desk releases. An unasked name swap is destroyed, not listed.
  def slot_history?(assignment)
    return false unless assignment.released_at
    return true if assignment.cancelled?
    return true if assignment.confirmation != "unconfirmed"
    return true if assignment.booking_text_sent_at.present?

    if assignment.association(:questions).loaded?
      return true if assignment.questions.any?
    elsif assignment.questions.exists?
      return true
    end

    kinds = %w[asked booked cancelled]
    if assignment.association(:audit_logs).loaded?
      assignment.audit_logs.any? { |log| kinds.include?(log.kind) }
    else
      assignment.audit_logs.exists?(kind: kinds)
    end
  end

  def fill_phase_badge(process)
    spec = FILL_PHASES.fetch(process.phase)
    tag.span(class: "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset #{spec[:tone]}") do
      safe_join([ icon(spec[:icon], html_class: "size-3.5 shrink-0"), spec[:label] ])
    end
  end

  def slot_tone(label)
    case label
    when "Unconfirmed" then "unconfirmed"
    when "Waiting for a reply", "Filling" then "awaiting"
    when "Confirmed by reply", "Confirmed by desk", "Finished" then "confirmed"
    when "Declined", "Needs more names" then "declined"
    when "Timed out" then "timed-out"
    else "open"
    end
  end

  def fill_line_label(line)
    timed_out_line?(line) ? "Timed out" : line.status
  end

  def timed_out_line?(line)
    remainings = line.people.filter_map(&:remaining)
    remainings.any? && remainings.all? { |item| item == "Timed out" }
  end

  private
    def nav_current?(path)
      return current_page?(root_path) if path == root_path

      request.path == path || request.path.start_with?("#{path}/")
    end
end
