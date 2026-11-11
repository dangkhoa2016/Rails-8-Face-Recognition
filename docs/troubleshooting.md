# Troubleshooting

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](troubleshooting.vi.md)

## PostgreSQL migrations fail
Check DATABASE_URL, database permissions and the vector extension. Test migrations on a disposable development database, never delete production data just to clear an error.

## Devise sign-in fails
Confirm the email is verified and the account enabled. Devise session timeout and PostgreSQL rate limiting are separate controls; an HTTP 429 is not a wrong-password error. Revoked sessions must remain invalid.

## Email verification not arriving
Check EMAIL_PROVIDER, verified sender, SMTP credentials, running Solid Queue workers and delivery logs. Development file delivery writes to tmp/mails without sending external email.

## Embedding profile never becomes ready
Inspect 120 SOURCE coverage, pinned revision/dimension/config hash, preflight, and approved policy. Re-selecting an old profile should reuse its cached vectors.

## Image upload fails
Check file signature/MIME, byte/pixel limits, consent, private storage permissions and TTL. Images should be accessed via authorization-checked Rails routes rather than public bucket URLs.

## CI succeeds but Modal fails
CI is offline/mocked. Use an authorized live smoke test to validate HTTPS, DNS/IP allowlist, bearer key, model revision, API rate limits and quota.

For sensitive incidents, follow [Security](../.github/SECURITY.md).
