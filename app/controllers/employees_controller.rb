class EmployeesController < ApplicationController
  before_action :set_employee, only: [ :show, :edit, :update, :destroy, :move_higher, :move_lower ]

  def index
    @employees = venue.employees.ordered.includes(employee_skills: { skill: :skill_category })
    @skills = Skill.for_venue(venue).includes(:skill_category).order("skill_categories.sort_order, skills.sort_order")
  end

  def reorder
    saved = ListOrder.apply(venue.employees.ordered, params[:ids], :sort_order)
    head saved ? :no_content : :unprocessable_entity
  end

  def show
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
    @categories = skill_tree
  end

  def update
    if @employee.update(employee_params)
      redirect_to @employee
    else
      @categories = skill_tree
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
      params.require(:employee).permit(:first_name, :last_name, :preferred_name, :mobile, :email, :notes, :active)
    end

    def skill_tree
      venue.skill_categories.ordered.includes(:skills)
    end
end
