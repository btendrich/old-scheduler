class LiveController < ApplicationController
  def show
    render json: { revision: venue.live_revision }
  end
end
