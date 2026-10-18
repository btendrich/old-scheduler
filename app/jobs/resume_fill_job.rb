class ResumeFillJob < ApplicationJob
  def perform(fill_process_id)
    FillProcess.find_by(id: fill_process_id)&.advance
  end
end
