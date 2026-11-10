class AuditLogsController < ApplicationController
  def index
    @audit_logs = venue.audit_logs.outcomes.recent.includes(:call, :fill_process)
  end
end
