class EmployeeSkillsController < ApplicationController
  before_action :set_employee

  def create
    employee_skill = @employee.employee_skills.new(employee_skill_params)
    if employee_skill.save
      redirect_to edit_employee_path(@employee)
    else
      redirect_to edit_employee_path(@employee), alert: employee_skill.errors.full_messages.to_sentence
    end
  end

  def update
    employee_skill = @employee.employee_skills.find(params[:id])
    if employee_skill.update(params.require(:employee_skill).permit(:level, :note))
      redirect_to edit_employee_path(@employee)
    else
      redirect_to edit_employee_path(@employee), alert: employee_skill.errors.full_messages.to_sentence
    end
  end

  def destroy
    @employee.employee_skills.find(params[:id]).destroy!
    redirect_to edit_employee_path(@employee)
  end

  private
    def set_employee
      @employee = venue.employees.find(params[:employee_id])
    end

    def employee_skill_params
      params.require(:employee_skill).permit(:skill_id, :level, :note)
    end
end
