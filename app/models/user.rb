class User < ApplicationRecord
  devise :database_authenticatable, :validatable, :timeoutable
  ROLES = %w[admin member].freeze
  LOCALES = %w[en vi].freeze

  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :preferred_locale, inclusion: { in: LOCALES }
  normalizes :email, with: ->(value) { value.strip.downcase }
  before_validation :set_session_nonce, on: :create

  generates_token_for :email_verification, expires_in: 24.hours do
    [email, email_verified_at&.iso8601]
  end
  generates_token_for :password_reset, expires_in: 30.minutes do
    [encrypted_password, session_nonce]
  end

  has_many :owned_face_images, class_name: "FaceImage", foreign_key: :owner_user_id, dependent: :restrict_with_exception
  has_many :recognition_attempts, dependent: :restrict_with_exception
  has_many :data_resets, foreign_key: :actor_id, dependent: :restrict_with_exception

  # Devise authentication is deliberately gated by email ownership and suspension.
  # Warden must not restore disabled or unverified accounts.
  def active_for_authentication?
    super && verified? && enabled?
  end

  def inactive_message
    return :unconfirmed unless verified?
    return :locked unless enabled?

    super
  end

  def admin?
    role == "admin"
  end

  def verified?
    email_verified_at.present?
  end

  def enabled?
    disabled_at.nil?
  end

  def authenticate_session?(nonce)
    enabled? && verified? && nonce.present? && session_nonce.present? &&
      ActiveSupport::SecurityUtils.secure_compare(session_nonce, nonce.to_s)
  end

  def rotate_sessions!
    update!(session_nonce: SecureRandom.hex(32))
  end

  private

  def set_session_nonce
    self.session_nonce ||= SecureRandom.hex(32)
  end
end
