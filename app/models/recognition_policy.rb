class RecognitionPolicy < ApplicationRecord
  STATUSES = %w[not_calibrated approved retired].freeze
  belongs_to :embedding_profile
  belongs_to :approved_by, class_name: "User", optional: true
  validates :status, inclusion: { in: STATUSES }
  validates :threshold, numericality: { greater_than_or_equal_to: -1, less_than_or_equal_to: 1 }, allow_nil: true
  validates :decision_margin, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }, allow_nil: true
  validates :evaluation_report_sha256, format: { with: /\A[0-9a-f]{64}\z/ }, allow_blank: true
  validate :complete_provenance_if_approved
  validate :protect_approved_policy, on: :update

  private

  def protect_approved_policy
    return unless status_in_database == "approved"
    %w[embedding_profile_id threshold decision_margin evaluation_manifest_ref evaluation_report_sha256 approved_by_id approved_at].each do |field|
      errors.add(field, "is immutable after approval") if will_save_change_to_attribute?(field)
    end
    errors.add(:status, "can only be retired") if will_save_change_to_status? && status != "retired"
  end

  def complete_provenance_if_approved
    return unless status == "approved"
    %i[threshold evaluation_manifest_ref evaluation_report_sha256 approved_by approved_at].each do |field|
      errors.add(field, "required for an approved policy") if public_send(field).blank?
    end
  end
end
