class CallsController < ApplicationController
  before_action :set_show, only: [ :new, :create ]
  before_action :set_call, only: [ :show, :edit, :update, :destroy ]

  def show
    @fill_processes = @call.fill_processes.includes(:events, candidates: :employee, slots: { call_slot: :position_label })
    @templates = venue.template_lists.ordered
    @skills = Skill.for_venue(venue).includes(:skill_category).order("skill_categories.sort_order, skills.sort_order")
  end

  def new
    morning = Time.zone.tomorrow.change(hour: 9, min: 0)
    @call = @show.calls.new(starts_at: morning, ends_at: morning.change(hour: 17))
  end

  def create
    @call = @show.calls.new(call_params)
    if @call.save
      redirect_to @call
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @show = @call.show
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
        :location, :call_type, :show,
        call_slots: [ :position_label, :fill_slot, { current_assignment: [ :employee, :open_question, :questions, :boss_notices ], assignments: :employee } ]
      ).find(params[:id])
    end

    def call_params
      params.require(:call).permit(:location_id, :call_type_id, :starts_at, :ends_at)
    end
end
