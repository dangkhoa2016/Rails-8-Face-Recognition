class UserMailer < ApplicationMailer
  def verify_email(user)
    @user = user
    @url = email_verification_url(token: user.generate_token_for(:email_verification))
    I18n.with_locale(user.preferred_locale) do
      mail(to: user.email, subject: I18n.t("mail.verify_subject"))
    end
  end

  def password_reset(user)
    @user = user
    @url = edit_password_reset_url(token: user.generate_token_for(:password_reset))
    I18n.with_locale(user.preferred_locale) do
      mail(to: user.email, subject: I18n.t("mail.reset_subject"))
    end
  end
end
