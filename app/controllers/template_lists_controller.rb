class TemplateListsController < ApplicationController
  def index
    @lists = venue.template_lists.ordered
    @selected = selected_list
    @draft = venue.template_lists.new
    @categories = venue.skill_categories.ordered.includes(:skills)
    @employees = venue.employees.ordered.includes(employee_skills: { skill: :skill_category })
    @roster = @employees.index_by(&:id)
    @work = WorkRecord.for(@employees)
    @members = @selected&.entries&.includes(:employee) || []
    taken = @members.map(&:employee_id)
    @available = @employees.reject { |employee| taken.include?(employee.id) }
  end

  def create
    list = venue.template_lists.new(list_params)
    if list.save
      redirect_to template_lists_path(list: list.id)
    else
      redirect_to template_lists_path, alert: list.errors.full_messages.to_sentence
    end
  end

  def update
    list = venue.template_lists.find(params[:id])
    list.make_default! if ActiveModel::Type::Boolean.new.cast(params.dig(:template_list, :default))
    redirect_to template_lists_path(list: list.id)
  end

  def destroy
    venue.template_lists.find(params[:id]).destroy!
    redirect_to template_lists_path
  end

  private
    def list_params
      params.require(:template_list).permit(:name)
    end

    def selected_list
      lists = venue.template_lists.ordered
      return lists.find(params[:list]) if params[:list].present?

      lists.find_by(default: true) || lists.first
    end
end
