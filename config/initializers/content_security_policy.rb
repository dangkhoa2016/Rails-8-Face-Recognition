Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.script_src :self
  policy.style_src :self
  policy.img_src :self, :data
  policy.font_src :self
  policy.object_src :none
  policy.base_uri :self
  policy.frame_ancestors :none
end

# Importmap includes a generated inline script tag. A per-request nonce allows
# it without enabling unsafe-inline for arbitrary scripts.
Rails.application.config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
