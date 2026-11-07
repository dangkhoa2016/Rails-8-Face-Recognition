Rails.application.config.filter_parameters += [
  :password, :password_confirmation, :token, :secret, :authorization, :email, :session_nonce,
  :image_base64, :embedding, :vector, :auth_secret_reference,
  :original_sha256, :input_sha256, :access_key_id, :secret_access_key
]
