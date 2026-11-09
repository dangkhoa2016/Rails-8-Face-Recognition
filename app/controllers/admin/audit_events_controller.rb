module Admin
  class AuditEventsController < BaseController
    def index
      @events = AdminAuditEvent.includes(:actor).order(created_at: :desc).limit(200)
    end
  end
end
