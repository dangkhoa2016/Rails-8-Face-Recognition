# Security Policy

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](SECURITY.vi.md)

## Supported scope
Security review covers the current development branch and future published releases. No production security guarantee is implied by passing CI.

## Private vulnerability reporting
Email **Đăng Khoa <i.am@dangkhoa.dev>** with a concise description, reproduction steps, and affected revision. **Do not publish** credentials, private images, SMTP tokens, authentication bypasses, or user records in public Issues.

## Security boundaries
- Devise/Warden authentication plus database-backed rate limiting.
- Verified email before access; suspended users and revoked sessions are denied.
- Administrator-only profile/policy changes, audited privileged actions.
- Private submissions with TTL and authorized image streaming.
- Endpoint hostname allowlist, TLS, and server-side bearer tokens.
- Approved profile + calibrated policy required before any recognition outcome.

Security findings should distinguish unit-test evidence from live production deployment.
