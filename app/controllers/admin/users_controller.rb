module Admin
  class UsersController < BaseController
    OPERATIONS = %w[suspend activate promote demote revoke_sessions].freeze

    def index
      @users = User.order(created_at: :desc).limit(200)
    end

    def update
      user = User.find(params[:id])
      operation = params[:operation].to_s
      return head :unprocessable_entity unless OPERATIONS.include?(operation)

      if user.id == current_user.id && %w[suspend demote].include?(operation)
        return redirect_to admin_users_path, alert: t("users.self_protection")
      end

      # The singleton setting acts as a cross-process mutex for all admin-role
      # changes. The user edit and audit event commit in the same transaction.
      ApplicationSetting.current.with_lock do
        user.with_lock do
          case operation
          when "suspend"
            refuse_last_admin_change!(user) if user.admin? && user.enabled? && user.verified?
            user.update!(disabled_at: Time.current, session_nonce: SecureRandom.hex(32))
          when "activate"
            user.update!(disabled_at: nil)
          when "promote"
            raise ArgumentError, "verification required" unless user.verified? && user.enabled?
            user.update!(role: "admin", session_nonce: SecureRandom.hex(32))
          when "demote"
            refuse_last_admin_change!(user) if user.admin? && user.enabled? && user.verified?
            user.update!(role: "member", session_nonce: SecureRandom.hex(32))
          when "revoke_sessions"
            user.rotate_sessions!
          end
          audit!("user.#{operation}", user)
        end
      end
      redirect_to admin_users_path, notice: t("users.updated")
    rescue ArgumentError
      redirect_to admin_users_path, alert: t("users.operation_denied")
    end

    private

    def refuse_last_admin_change!(_user)
      active_admins = User.where(role: "admin", disabled_at: nil).where.not(email_verified_at: nil)
      raise ArgumentError, "last admin" if active_admins.count <= 1
    end
  end
end
