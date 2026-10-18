class ClientsController < ApplicationController
  before_action :set_client, only: [ :show, :edit, :update, :destroy ]

  def index
    @clients = venue.clients.order(:name).includes(:shows)
  end

  def show
    @shows = @client.shows.order(:name).includes(:calls)
  end

  def new
    @client = venue.clients.new
  end

  def create
    @client = venue.clients.new(client_params)
    if @client.save
      redirect_to @client
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @client.destroy!
    redirect_to clients_path
  end

  private
    def set_client
      @client = venue.clients.find(params[:id])
    end

    def client_params
      params.require(:client).permit(:name)
    end
end
