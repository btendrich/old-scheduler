class EmployeesController < ApplicationController
  before_action :set_employee, only: [ :show, :edit, :update, :destroy, :move_higher, :move_lower ]

  def index
    @employees = venue.employees.ordered.includes(employee_skills: { skill: :skill_category })
  end

  def show
    @employee_skill = @employee.employee_skills.new(level: 3)
    @skills = available_skills
  end

  def new
    @employee = venue.employees.new(active: true)
  end

  def create
    @employee = venue.employees.new(employee_params)
    if @employee.save
      redirect_to @employee
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @employee.update(employee_params)
      redirect_to @employee
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @employee.destroy
      redirect_to employees_path
    else
      redirect_to @employee, alert: @employee.errors.full_messages.to_sentence
    end
  end

  def move_higher
    @employee.move_higher
    redirect_to employees_path
  end

  def move_lower
    @employee.move_lower
    redirect_to employees_path
  end

  private
    def set_employee
      @employee = venue.employees.includes(employee_skills: { skill: :skill_category }).find(params[:id])
    end

    def employee_params
      params.require(:employee).permit(:preferred_name, :legal_name, :mobile, :email, :notes, :active)
    end

    def available_skills
      taken = @employee.skill_ids
      venue.skill_categories.ordered.includes(:skills).flat_map(&:skills).reject { |skill| taken.include?(skill.id) }
    end
end
