class AdminAuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User"
  validates :action, :subject_type, :subject_id, presence: true
end
