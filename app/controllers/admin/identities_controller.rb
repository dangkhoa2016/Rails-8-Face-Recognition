module Admin
  class IdentitiesController < BaseController
    def index
      @query = params[:q].to_s.first(100)
      @identities = Identity.order(:external_identity_key)
      @identities = @identities.where("external_identity_key ILIKE ? OR display_name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%") if @query.present?
      @total = @identities.count
      @page = [[params[:page].to_i, 1].max, 10_000].min
      @identities = @identities.limit(25).offset((@page - 1) * 25)
    end

    def show
      @identity = Identity.find(params[:id])
      @images = @identity.face_images.order(:slot)
    end

    def update
      identity = Identity.find(params[:id])
      identity.update!(active: ActiveModel::Type::Boolean.new.cast(params.require(:active)))
      audit!("identity.status_changed", identity, details: { active: identity.active })
      redirect_to admin_identity_path(identity), notice: helpers.ui("Identity status updated.")
    end
  end
end
