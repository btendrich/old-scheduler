class BossesController < ApplicationController
  def create
    boss = venue.bosses.new(mobile: params[:mobile])
    if boss.save
      redirect_to setup_path
    else
      redirect_to setup_path, alert: boss.errors.full_messages.to_sentence
    end
  end

  def destroy
    venue.bosses.find(params[:id]).destroy!
    redirect_to setup_path
  end
end
