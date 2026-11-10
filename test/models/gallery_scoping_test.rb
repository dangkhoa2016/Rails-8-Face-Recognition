require "test_helper"

class GalleryScopingTest < ActiveSupport::TestCase
  def setup
    @identity = Identity.create!(external_identity_key: "CORE:test", display_name: "Core Identity test")
    @sha = "f" * 64
  end

  test "only active Core SOURCE enrollment appears in gallery" do
    enrolled = FaceImage.create!(identity: @identity, dataset_identity_key: "CORE:test", collection: "core",
      slot: "SOURCE", role: "enrollment", original_sha256: @sha, storage_policy: "reference")
    FaceImage.create!(identity: @identity, dataset_identity_key: "CORE:test", collection: "core",
      slot: "P1", role: "sample_probe", original_sha256: @sha, storage_policy: "reference")
    FaceImage.create!(collection: "additional", dataset_identity_key: "ADDITIONAL:test", slot: "SOURCE",
      role: "sample_probe", original_sha256: @sha, storage_policy: "reference")
    assert_equal [enrolled.id], FaceImage.enrollment_core.pluck(:id)
    @identity.update!(active: false)
    assert_empty FaceImage.enrollment_core
  end

  test "additional image cannot enroll" do
    image = FaceImage.new(identity: @identity, collection: "additional", slot: "SOURCE",
      role: "enrollment", original_sha256: @sha, storage_policy: "reference")
    assert_not image.valid?
  end
end
