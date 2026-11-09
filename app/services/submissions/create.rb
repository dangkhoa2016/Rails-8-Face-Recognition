require "stringio"

module Submissions
  class Create
    class InvalidUpload < StandardError; end

    def self.call(user:, upload:, consent:, admin_unknown:, provenance_note: nil)
      unless consent.to_s == "1"
        raise InvalidUpload, "Confirm that you have the rights and necessary consent to process this image."
      end
      if admin_unknown && !user.admin?
        raise InvalidUpload, "Only admins can submit an asserted unknown test."
      end
      if user.owned_face_images.where(role: "submission").where("expires_at > ?", Time.current).count >= 100
        raise InvalidUpload, "Active upload quota reached (100 images). Delete an old submission first."
      end
      file = ImageUploads::Validate.call(upload)
      image = FaceImage.new(owner_user: user, collection: admin_unknown ? "admin" : "user",
        role: "submission", original_sha256: file.sha256, inference_input_sha256: file.sha256,
        storage_policy: "transient", expires_at: 24.hours.from_now,
        ground_truth_label: ("asserted_unknown" if admin_unknown), provenance_note: provenance_note.to_s.presence)
      image.image.attach(io: StringIO.new(file.bytes), filename: "authorized-image-#{file.sha256.first(12)}#{file.extension}",
        content_type: file.content_type, identify: false)
      image.save!
      image
    rescue ImageUploads::Validate::InvalidImage, ActiveRecord::RecordInvalid => error
      raise InvalidUpload, error.message
    end
  end
end
