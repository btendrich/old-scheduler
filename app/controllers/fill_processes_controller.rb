class FillProcessesController < ApplicationController
  def create
    call = Call.for_venue(venue).find(params[:call_id])
    process = call.fill_processes.new(process_params)
    slot_ids = Array(params[:call_slot_ids]).reject(&:blank?)
    if slot_ids.empty?
      redirect_to call, alert: "Choose at least one slot."
      return
    end

    FillProcess.transaction do
      process.save!
      slot_ids.each do |id|
        process.slots.create!(call_slot: call.call_slots.find(id))
      end
    end
    redirect_to call
  rescue ActiveRecord::RecordInvalid => error
    redirect_to call, alert: error.record.errors.full_messages.to_sentence
  end

  def start
    process = venue_process
    process.start!
    redirect_to process.call
  end

  def emergency_step
    process = venue_process
    process.run_emergency_step!
    redirect_to process.call
  end

  def add_skill
    process = venue_process
    skill = Skill.for_venue(venue).find(params[:skill_id])
    process.add_with_skill(skill, minimum_level: params[:minimum_level].to_i.clamp(1, 5))
    redirect_to process.call
  end

  def add_template
    process = venue_process
    template = venue.template_lists.find(params[:template_list_id])
    process.add_template(template)
    redirect_to process.call
  end

  private
    def venue_process
      FillProcess.for_venue(venue).find(params[:id])
    end

    def process_params
      params.require(:fill_process).permit(
        :offer_timeout_minutes, :custom_window, :window_start, :window_end, :mode, :step_size, :step_minutes
      )
    end
end
