class FillCandidatesController < ApplicationController
  def create
    process = venue_process
    ids = Array(params[:employee_ids]).map(&:presence).compact
    ids = [ params[:employee_id] ] if ids.empty? && params[:employee_id].present?
    employees = venue.employees.where(id: ids).index_by { |employee| employee.id.to_s }
    added = ids.count { |id| (employee = employees[id.to_s]) && process.add_employee(employee) }
    if added.zero? && ids.one? && employees[ids.first.to_s]
      redirect_to process.call, alert: "#{employees[ids.first.to_s].name} is already on the list."
    elsif ids.empty?
      redirect_to process.call, alert: "Choose at least one person."
    else
      redirect_to process.call
    end
  end

  def destroy
    candidate = venue_candidate
    call = candidate.fill_process.call
    if candidate.state == "pending"
      candidate.destroy!
    else
      return redirect_to call, alert: "That person has already been asked."
    end
    redirect_to call
  end

  def selected
    process = venue_process
    chosen = process.candidates.where(id: Array(params[:ids])).includes(:employee)
    staying = chosen.reject { |candidate| candidate.state == "pending" }
    chosen.select { |candidate| candidate.state == "pending" }.each(&:destroy!)
    if staying.any?
      names = staying.map { |candidate| candidate.employee.name }.to_sentence
      verb = staying.one? ? "has" : "have"
      redirect_to process.call, alert: "#{names} #{verb} already been asked."
    else
      redirect_to process.call
    end
  end

  def reorder
    saved = ListOrder.apply(venue_process.candidates.ordered, params[:ids], :position)
    head saved ? :no_content : :unprocessable_entity
  end

  def move_higher
    candidate = venue_candidate
    candidate.move_higher
    redirect_to candidate.fill_process.call
  end

  def move_lower
    candidate = venue_candidate
    candidate.move_lower
    redirect_to candidate.fill_process.call
  end

  private
    def venue_process
      FillProcess.for_venue(venue).find(params[:fill_process_id])
    end

    def venue_candidate
      FillCandidate.joins(fill_process: { call: { show: :client } })
        .where(clients: { venue_id: venue.id })
        .find(params[:id])
    end
end
