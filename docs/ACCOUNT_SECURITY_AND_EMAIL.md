# Accounts, localization, themes, test-data resets and email

🌐 **English** | [Tiếng Việt](ACCOUNT_SECURITY_AND_EMAIL.vi.md)

## Included functionality

The application supports English and Vietnamese (`en`, `vi`), selected from the header and stored in a signed cookie. Signed-in users also persist `users.preferred_locale`. Rails I18n uses `config/locales/en.yml`, `vi.yml` and `ui.vi.yml`; existing English UI text is used as the fallback where a translation is not available. Human translation review and browser accessibility testing are required before public release.

Light, Dark and System themes use `html[data-theme]`, CSS `color-scheme` and `light-dark()`. The System option follows OS preferences. Signed cookies remember the chosen mode; Stimulus enhances the settings forms but is not required for initial theme rendering.

## Test-data reset scopes

Authenticated `GET /data_resets` and CSRF-protected `POST /data_resets` support these narrowly scoped asynchronous resets:

| Scope | Authorized user | Deletions | Exact confirmation |
|---|---|---|---|
| `mine` | Member or admin | Own transient uploads and recognition history at cutoff | `RESET MY DATA` |
| `all_test_activity` | Admin only | All transient submissions and test recognition attempts at cutoff | `RESET ALL TEST DATA` |
| `probe_cache` | Admin only | Query-only sample probe embeddings and requests | `RESET PROBE CACHE` |

**None** of these deletes Core identities, SOURCE enrollments, reference assets, models/profiles, evaluation policies or enrollment vectors. Reset requests have snapshots (`cutoff_at`), job status and audit records. Query-cache resets may cause additional paid inference calls on subsequent requests. Real R2 deletion and job retries need integration testing.

## Registration and account security

Self-registration is only enabled when an email delivery method is available. The server always sets the role to `member`, requires explicit Terms/Privacy consent, emails a signed 24-hour verification link, and rejects login until verification is completed. A GET verification link shows a confirmation form instead of activating the account in response to mail-scanner GETs.

The password reset link lasts 30 minutes. Setting a new password rotates the session nonce, revoking previous browser sessions. Passwords require at least 12 characters; public registration, forgot-password and resend-verification endpoints return generic answers to limit account enumeration. Admins may lock/unlock users, promote/demote and revoke sessions, but cannot disable their own privileged account or the last active verified administrator. Admin edits and audit events are transactional.

Authentication uses **Devise 5.0.4 / Warden** for credential verification and sessions, while the existing signed-token email verification/password recovery flows remain under application controllers. Database-backed rate limits use HMAC-hashed email and IP buckets and PostgreSQL row locks, not process-local counters. Login caps: 30 attempts per IP, 8 per email and 5 per IP+email per 15 minutes (HTTP 429 beyond the cap). Registration, resend, password reset, uploads, recognition requests and resets have separate caps; consult `app/services/auth/rate_limiter.rb` for exact limits.

## Transactional email via SMTP

Development defaults to `EMAIL_PROVIDER=file` and writes messages to `tmp/mails` without sending mail. Tests use ActionMailer `:test`. In production, registration stays disabled until SMTP credentials, `EMAIL_FROM` and `APP_HOST` are configured.

```dotenv
PUBLIC_REGISTRATION_ENABLED=true
APP_HOST=faces.example.com
EMAIL_PROVIDER=resend
EMAIL_FROM=Rails 8 Face Recognition <no-reply@faces.example.com>
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USERNAME=resend
EMAIL_SMTP_PASSWORD=<server-side-secret>
EMAIL_HELO_DOMAIN=faces.example.com
```

Supported selections: `resend` → `smtp.resend.com`, username `resend`; `brevo` → `smtp-relay.brevo.com`, use SMTP login + SMTP key (not REST key); `postmark` → `smtp.postmarkapp.com`, Server API token or Message Stream credentials; `sendpulse` → manually set `EMAIL_SMTP_HOST`, login and password exactly as your SendPulse SMTP dashboard lists; `smtp` → custom SMTP configuration. Port 587 uses STARTTLS; 465 uses implicit TLS. Verify sender domain, SPF/DKIM/DMARC and bounce handling before opening signup.

Provider references: [Resend](https://resend.com/changelog/smtp-service), [Brevo](https://help.brevo.com/hc/en-us/articles/7924908994450-Send-transactional-emails-using-Brevo-SMTP), [Postmark](https://postmarkapp.com/support/article/1112-smtp-settings), [SendPulse](https://sendpulse.com/knowledge-base/smtp/setup-smtp-server).

## Security and acceptance notes

Do not store or expose SMTP credentials in Git, HTML or logs. Use trusted reverse-proxy IP configuration, TLS, CSRF/session protections, WAF/bot prevention, delivery observability, secret rotation and regular authentication-throttle cleanup for public operation. Limits based only on IP/email do not eliminate distributed credential-stuffing attacks.

GitHub CI has passed Rails/PostgreSQL/pgvector migrations, Ruby integration tests and Chrome browser system tests. A live SMTP provider, R2 and Modal have **not** been qualified. To validate:

```sh
bundle install
bin/rails db:prepare
bin/rails test
bin/dev
```

Exercise bilingual views, light/dark/system, signed link expiration, abuse lockouts, last-admin protection, revocation across sessions, and both member/admin resets while confirming every Core enrollment and cached reference vector remains intact.
