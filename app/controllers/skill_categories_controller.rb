class SkillCategoriesController < ApplicationController
  before_action :set_category, only: [ :edit, :update, :destroy ]

  def index
    @categories = venue.skill_categories.ordered.includes(:skills)
    @category = SkillCategory.new
  end

  def create
    category = venue.skill_categories.new(category_params)
    category.save
    redirect_to skill_categories_path, alert: category.errors.full_messages.to_sentence.presence
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to skill_categories_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to skill_categories_path, alert: @category.errors.full_messages.to_sentence.presence
  end

  private
    def set_category
      @category = venue.skill_categories.find(params[:id])
    end

    def category_params
      params.require(:skill_category).permit(:name)
    end
end
