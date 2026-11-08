class Identity < ApplicationRecord
  has_many :face_images, dependent: :restrict_with_exception
  scope :active, -> { where(active: true) }
  validates :external_identity_key, presence: true, uniqueness: true, format: { with: /\ACORE:[A-Za-z0-9_.:-]+\z/ }
  validates :display_name, presence: true
end
