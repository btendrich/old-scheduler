class CallsController < ApplicationController
  before_action :set_show, only: [ :new, :create ]
  before_action :set_call, only: [ :show, :edit, :update, :destroy ]

  def show
    @fill_processes = @call.fill_processes.ordered.includes(
      :events, candidates: :employee, questions: :employee,
      slots: { call_slot: [ :position_label, { current_assignment: [ :employee, :open_question ] } ] }
    )
    @templates = venue.template_lists.ordered.includes(entries: :employee)
    @skills = Skill.for_venue(venue).includes(:skill_category).order("skill_categories.sort_order, skills.sort_order")
    @employees = venue.employees.ordered.includes(employee_skills: :skill)
    @pool = CallAvailability.build_all(@employees, @call)
    @linkable_slots = @call.show.calls.chronological.where.not(id: @call.id).includes(:call_type, :location, call_slots: [ :position_label, :outbound_link, :inbound_link ]).flat_map { |other|
      other.call_slots.reject(&:linked?).map { |slot| [ "#{other.desk_label} · #{slot.label_name}", slot.id ] }
    }
  end

  def new
    morning = Time.zone.tomorrow.change(hour: 9, min: 0)
    @call = @show.calls.new(starts_at: morning, ends_at: morning.change(hour: 17))
    @linkable_calls = @show.calls.chronological
  end

  def create
    @call = @show.calls.new(call_params)
    @linkable_calls = @show.calls.chronological
    source = link_source_call
    Call.transaction do
      @call.save!
      if source
        @call.inherit_slots_from!(source)
      else
        slot_count.times { @call.call_slots.create! }
      end
    end
    redirect_to @call
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
    @show = @call.show
    @linkable_calls = @show.calls.chronological.where.not(id: @call.id)
  end

  def update
    @show = @call.show
    if @call.update(call_params)
      redirect_to @call
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    show = @call.show
    @call.destroy!
    redirect_to show
  end

  private
    def set_show
      @show = Show.for_venue(venue).find(params[:show_id])
    end

    def set_call
      @call = Call.for_venue(venue).includes(
        :location, :call_type, show: :client,
        call_slots: [
          :position_label,
          { fill_slot: :fill_process },
          { outbound_link: { partner_slot: [ :position_label, { call: [ :call_type, :location ] } ] } },
          { inbound_link: { call_slot: [ :position_label, { call: [ :call_type, :location ] } ] } },
          { current_assignment: [ :employee, :open_question, :questions, :boss_notices ], assignments: [ :employee, :audit_logs ] }
        ]
      ).find(params[:id])
    end

    def call_params
      params.require(:call).permit(:location_id, :call_type_id, :starts_at, :ends_at)
    end

    def link_source_call
      id = params[:link_call_id].presence
      return if id.blank?

      @show.calls.find(id)
    end

    def slot_count
      requested = params[:slot_count].to_i
      return 0 if requested < 1

      [ requested, 20 ].min
    end
end
