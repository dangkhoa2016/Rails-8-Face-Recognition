class FaceImagesController < ApplicationController
  # Authorization is performed before reading the object; never redirect to a durable blob URL.
  def show
    image = FaceImage.find(params[:id])
    allowed = if image.role == "submission"
      image.owner_user_id == current_user.id || (current_user.admin? && image.collection == "admin")
    elsif image.role == "sample_probe"
      %w[core additional].include?(image.collection) || current_user.admin?
    else
      current_user.admin?
    end
    return head :not_found unless allowed && image.image.attached?
    return head :gone if image.storage_policy == "transient" && image.expires_at <= Time.current

    response.headers["Cache-Control"] = "private, no-store, max-age=0"
    response.headers["X-Content-Type-Options"] = "nosniff"
    blob = image.image.blob
    return head :unsupported_media_type unless %w[image/png image/jpeg image/webp].include?(blob.content_type)
    send_data blob.download, type: blob.content_type, disposition: "inline"
  end
end
