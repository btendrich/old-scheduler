class TemplateEntriesController < ApplicationController
  def create
    list = venue.template_lists.find(params[:template_list_id])
    ids = Array(params[:employee_ids].presence || params[:employee_id]).compact_blank
    ids.each { |id| list.add_employee(venue.employees.find(id)) }
    redirect_to template_lists_path(list: list.id)
  end

  def selected
    list = venue.template_lists.find(params[:template_list_id])
    list.entries.where(id: Array(params[:ids])).destroy_all
    redirect_to template_lists_path(list: list.id)
  end

  def destroy
    entry = venue_entry
    list = entry.template_list
    entry.destroy!
    redirect_to template_lists_path(list: list.id)
  end

  def reorder
    list = venue.template_lists.find(params[:template_list_id])
    saved = ListOrder.apply(list.entries, params[:ids], :position)
    head saved ? :no_content : :unprocessable_entity
  end

  private
    def venue_entry
      TemplateEntry.joins(template_list: :venue).where(venues: { id: venue.id }).find(params[:id])
    end
end
