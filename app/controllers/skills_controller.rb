class SkillsController < ApplicationController
  before_action :set_category, only: [ :create ]
  before_action :set_skill, only: [ :edit, :update, :destroy ]

  def create
    skill = @category.skills.new(skill_params)
    skill.save
    redirect_to skill_categories_path, alert: skill.errors.full_messages.to_sentence.presence
  end

  def edit
  end

  def update
    if @skill.update(skill_params)
      redirect_to skill_categories_path
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @skill.destroy
    redirect_to skill_categories_path, alert: @skill.errors.full_messages.to_sentence.presence
  end

  private
    def set_category
      @category = venue.skill_categories.find(params[:skill_category_id])
    end

    def set_skill
      @skill = Skill.for_venue(venue).find(params[:id])
    end

    def skill_params
      params.require(:skill).permit(:name)
    end
end
