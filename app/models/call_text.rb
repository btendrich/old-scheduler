class CallText
  def self.confirmation(call, also: [])
    "#{schedule_list([ call, *also ])}. Reply YES to confirm or NO if you can't."
  end

  def self.reminder(call)
    "#{call.schedule_phrase}. Reminder: reply YES to confirm or NO if you can't."
  end

  def self.boss_warning(assignment)
    call = assignment.call_slot.call
    "#{assignment.employee.name} can't make #{call.departure_phrase}, #{assignment.call_slot.label_name}."
  end

  def self.booking(call, also: [])
    calls = [ call, *also ].compact.uniq
    phrase = schedule_list(calls)
    "You're confirmed for #{phrase}. Reply NO if you can't make it.\n#{calls.first.calendar_url}"
  end

  def self.removed(call)
    "You're off #{call.departure_phrase}."
  end

  def self.offer(call, also: [])
    "#{schedule_list([ call, *also ])}. Reply YES or NO."
  end

  def self.emergency_offer(call, spots:, also: [])
    spot = spots == 1 ? "spot" : "spots"
    "#{schedule_list([ call, *also ])}. First-response fill: #{spots} #{spot} still open. The first YES replies get them. Reply YES or NO."
  end

  def self.schedule_list(calls)
    calls.compact.uniq.map(&:schedule_phrase).to_sentence
  end
  private_class_method :schedule_list

  def self.filled(call)
    "#{call.show.name} is filled."
  end

  def self.choice(calls)
    lines = calls.each_with_index.map { |call, index| "#{index + 1}. #{call.schedule_phrase}" }
    [ "Which call should you come off? Reply with a number.", *lines ].join("\n")
  end

  # The current question, restated, so a reply still answers the one already asked.
  def self.queued_notice(question, more)
    noun = "question".pluralize(more)
    waiting = "There #{more == 1 ? "is" : "are"} #{more} more #{noun} waiting."
    "#{waiting} #{body_for(question)}"
  end

  def self.body_for(question)
    case question.kind
    when "manual_confirmation"
      confirmation(question.call, also: question.assignment&.package_partner_calls || [])
    when "evening_reminder" then reminder(question.call)
    when "fill_offer"
      process = question.fill_process
      also = process ? process.package_partner_calls : []
      if process&.emergency?
        emergency_offer(question.call, spots: process.open_owned_slots.size, also: also)
      else
        offer(question.call, also: also)
      end
    when "choice" then choice(question.options.map(&:call))
    end
  end
end
