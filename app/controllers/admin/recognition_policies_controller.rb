module Admin
  class RecognitionPoliciesController < BaseController
    before_action :load_policy, only: [:show, :approve, :retire]

    def index
      @policies = RecognitionPolicy.includes(embedding_profile: :embedding_model).order(created_at: :desc)
    end

    def new
      @policy = RecognitionPolicy.new(status: "not_calibrated")
      @profiles = EmbeddingProfile.includes(:embedding_model).order(created_at: :desc)
    end

    def create
      @policy = RecognitionPolicy.new(policy_params)
      @policy.status = "not_calibrated"
      @policy.save!
      audit!("recognition_policy.created", @policy)
      redirect_to admin_recognition_policy_path(@policy), notice: helpers.ui("Policy draft saved. Review provenance before approval.")
    rescue ActiveRecord::RecordInvalid
      @profiles = EmbeddingProfile.includes(:embedding_model).order(created_at: :desc)
      render :new, status: :unprocessable_entity
    end

    def show; end

    def approve
      unless @policy.status == "not_calibrated"
        return redirect_to admin_recognition_policy_path(@policy), alert: helpers.ui("Only uncalibrated policy drafts may be approved.")
      end
      @policy.update!(status: "approved", approved_by: current_user, approved_at: Time.current)
      audit!("recognition_policy.approved", @policy, details: { report_sha256: @policy.evaluation_report_sha256 })
      redirect_to admin_recognition_policy_path(@policy), notice: helpers.ui("Policy approved for this exact profile.")
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_recognition_policy_path(@policy), alert: error.record.errors.full_messages.join("; ")
    end

    def retire
      if ApplicationSetting.current.active_recognition_policy_id == @policy.id
        return redirect_to admin_recognition_policy_path(@policy), alert: helpers.ui("Deactivate recognition before retiring its active policy.")
      end
      @policy.update!(status: "retired")
      audit!("recognition_policy.retired", @policy)
      redirect_to admin_recognition_policy_path(@policy), notice: helpers.ui("Policy retired.")
    end

    private

    def load_policy
      @policy = RecognitionPolicy.includes(embedding_profile: :embedding_model).find(params[:id])
    end

    def policy_params
      params.require(:recognition_policy).permit(:embedding_profile_id, :threshold, :decision_margin,
        :evaluation_manifest_ref, :evaluation_report_sha256)
    end
  end
end
