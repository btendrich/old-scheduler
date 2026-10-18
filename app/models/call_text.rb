class CallText
  def self.confirmation(call)
    "#{call.schedule_phrase}. Reply YES to confirm or NO if you can't."
  end

  def self.reminder(call)
    "#{call.schedule_phrase}. Reminder: reply YES to confirm or NO if you can't."
  end

  def self.boss_warning(assignment)
    call = assignment.call_slot.call
    "#{assignment.employee.preferred_name} can't make #{call.departure_phrase}, #{assignment.call_slot.position_label.name}."
  end

  def self.booking(call)
    "You're confirmed for #{call.schedule_phrase}. Reply NO if you can't make it.\n#{call.calendar_url}"
  end

  def self.removed(call)
    "You're off #{call.departure_phrase}."
  end

  def self.offer(call)
    "#{call.schedule_phrase}. Reply YES or NO."
  end

  def self.emergency_offer(call, spots:)
    spot = spots == 1 ? "spot" : "spots"
    "#{call.schedule_phrase}. First-response fill: #{spots} #{spot} still open. The first YES replies get them. Reply YES or NO."
  end

  def self.filled(call)
    "#{call.show.name} is filled."
  end

  def self.choice(calls)
    lines = calls.each_with_index.map { |call, index| "#{index + 1}. #{call.schedule_phrase}" }
    [ "Which call should you come off? Reply with a number.", *lines ].join("\n")
  end
end
