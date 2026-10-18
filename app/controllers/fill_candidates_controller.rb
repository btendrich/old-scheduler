class FillCandidatesController < ApplicationController
  def create
    process = venue_process
    employee = venue.employees.find(params[:employee_id])
    if process.add_employee(employee).nil? && process.candidates.exists?(employee: employee)
      redirect_to process.call, alert: "#{employee.preferred_name} is already on the list."
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
