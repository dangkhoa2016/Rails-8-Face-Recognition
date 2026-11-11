# Contributing

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](CONTRIBUTING.vi.md)

Thanks for improving Rails 8 Face Recognition. This is research software using synthetic identities, not a production-qualified biometric service.

## Development expectations
- Keep commits focused and reviewable (prefer less than ~600 changed lines).
- Add or revise English and Vietnamese documentation together; provide a language-switch link.
- Do not change Core SOURCE enrollment rules, reuse invariants, or profile immutability without tests.
- Do not expose user uploads, passwords, inference tokens, environment files, or R2 credentials.
- Add regression tests for account security, tenancy, and vector provenance.

## Local checks
```sh
bundle install
bin/rails db:prepare
bin/rails test
bin/rails test:system
bundle exec brakeman --no-pager
bundle exec rubocop
bin/rails tailwindcss:build
ruby scripts/check_bilingual_docs.rb
git diff --check
```

PostgreSQL with pgvector is required. GPU/R2/SMTP live acceptance requires separately configured services; passing CI is not evidence of live endpoint quality.

## Submitting changes
Include the expected behavior, evidence, security impact, data migration implications, and exact code revision. Do not attach private face images or secrets.
