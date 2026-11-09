class HomeController < ApplicationController
  skip_before_action :require_authentication

  def index
    @identity_count = Identity.active.count
    @sample_count = FaceImage.sample_probes.count
    @active_profile = ApplicationSetting.first&.active_recognition_profile
    @policy = ApplicationSetting.first&.active_recognition_policy
  end

  def about; end
  def privacy; end
  def terms; end
end
