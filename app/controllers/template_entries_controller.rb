class TemplateEntriesController < ApplicationController
  def create
    list = venue.template_lists.find(params[:template_list_id])
    employee = venue.employees.find(params[:employee_id])
    list.add_employee(employee)
    redirect_to template_lists_path
  end

  def destroy
    entry = venue_entry
    entry.destroy!
    redirect_to template_lists_path
  end

  def move_higher
    entry = venue_entry
    entry.move_higher
    redirect_to template_lists_path
  end

  def move_lower
    entry = venue_entry
    entry.move_lower
    redirect_to template_lists_path
  end

  private
    def venue_entry
      TemplateEntry.joins(template_list: :venue).where(venues: { id: venue.id }).find(params[:id])
    end
end
