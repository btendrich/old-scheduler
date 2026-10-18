class ShowsController < ApplicationController
  before_action :set_client, only: [ :new, :create ]
  before_action :set_show, only: [ :show, :edit, :update, :destroy ]

  def show
    @calls = @show.calls.chronological.includes(:location, :call_type, :call_slots)
  end

  def new
    @show = @client.shows.new
  end

  def create
    @show = @client.shows.new(show_params)
    if @show.save
      redirect_to @show
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @show.update(show_params)
      redirect_to @show
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    client = @show.client
    @show.destroy!
    redirect_to client
  end

  private
    def set_client
      @client = venue.clients.find(params[:client_id])
    end

    def set_show
      @show = Show.for_venue(venue).find(params[:id])
    end

    def show_params
      params.require(:show).permit(:name)
    end
end
