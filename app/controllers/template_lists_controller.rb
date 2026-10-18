class TemplateListsController < ApplicationController
  def index
    @lists = venue.template_lists.ordered.includes(entries: :employee)
    @list = venue.template_lists.new
  end

  def create
    list = venue.template_lists.new(list_params)
    if list.save
      redirect_to template_lists_path
    else
      redirect_to template_lists_path, alert: list.errors.full_messages.to_sentence
    end
  end

  def destroy
    venue.template_lists.find(params[:id]).destroy!
    redirect_to template_lists_path
  end

  private
    def list_params
      params.require(:template_list).permit(:name)
    end
end
