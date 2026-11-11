# Rails 8 Face Recognition

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

[![Rails CI](https://github.com/dangkhoa2016/Rails-8-Face-Recognition/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dangkhoa2016/Rails-8-Face-Recognition/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Ruby](https://img.shields.io/badge/Ruby-3.3-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)
![Tailwind](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?logo=tailwindcss&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-pgvector-4169E1?logo=postgresql&logoColor=white)
![Authentication](https://img.shields.io/badge/Auth-Devise%205.0.4-7C3AED)
[![Source license: MIT](https://img.shields.io/badge/Source%20License-MIT-yellow.svg)](LICENSE)

**Rails 8 Face Recognition** is a bilingual Rails application for experimental **1:N face identification on the CompactFaces synthetic-face dataset**. It uses PostgreSQL/pgvector for immutable embedding profiles, Tailwind CSS 4/Hotwire for the interface, Devise/Warden for authentication, private Cloudflare R2 storage, Solid Queue jobs, and a separately operated Modal inference API.

**Important:** this is research software; it is **not** a production-qualified biometric identification service. Similarity scores are **not probabilities**, and no live Modal/R2/SMTP acceptance is implied by passing GitHub CI.

## Why it exists

The project makes model comparison reproducible without mixing vectors from different checkpoints, dimensions, preprocessing rules or model instructions. A profile is uniquely keyed by these settings. Switching 1024D → 4096D → 1024D reuses saved 1024D vectors, instead of silently calling the GPU again.

It also keeps an **independent recognition-quality benchmark** outside Rails, in [Multimodal-Embeddings-AI-Inference](https://github.com/dangkhoa2016/Multimodal-Embeddings-AI-Inference). Rails can only recognize faces after a complete SOURCE gallery and a reviewed, profile-specific threshold policy exist.

## Capabilities

| Area | What the application provides |
|---|---|
| Dataset | 120 Core identities × 5 images + 67 Additional identities × 5 = **935** synthetic images |
| Enrollment | Exactly 120 Core **SOURCE** images per active profile; P1/P2/E1/E2 are probes |
| Models | External Qwen3-VL-Embedding-8B and WeMM-Embedding-9B via authenticated Modal API |
| Vectors | Variable-length pgvector; multiple pinned dimensions coexist and are not overwritten |
| Recognition | Exact cosine search within the active model profile; Unknown requires approved calibration |
| Accounts | Devise 5.0.4/Warden, verified email, revocable sessions and PostgreSQL-backed login throttling |
| Member UI | Gallery, private upload, recognition request/results/history, own-data reset |
| Admin UI | Dataset import, identities, models, services, profiles, policies, user management and audits |
| UI/UX | English/Vietnamese, Light/Dark/System, responsive Tailwind 4, Turbo and Stimulus |
| Delivery | Action Mailer SMTP: Resend, Brevo, Postmark, SendPulse and custom SMTP |
| Jobs | Solid Queue for import, inference, recognition, data reset and retention cleanup |

## Architecture

```text
Browser / Tailwind 4 / Hotwire
  -> Rails 8.1 + Devise/Warden + PostgreSQL throttling
      -> PostgreSQL 17 + pgvector (isolated profiles and vectors)
      -> Private Active Storage / Cloudflare R2
      -> Solid Queue -> authenticated Modal embedding endpoints
```

Neither face photos nor bearer tokens are sent to public tracking services. Browser image access is mediated by controller-level authorization. See [Architecture](docs/architecture.md).

## Get started locally

Required: Ruby 3.3, Bundler, PostgreSQL with the pgvector extension, and network access to install gems and Tailwind.

```sh
bundle install
cp .env.example .env
# Set DATABASE_URL and environment secrets via your local env loader.
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

Set ADMIN_EMAIL and ADMIN_PASSWORD **only for first-run seeding**. Existing admin passwords are never replaced. The development server runs Rails, Tailwind watch and Solid Queue. Production must configure TLS, strong Rails secrets, trusted proxies and private object storage.

## Identity and account security

Devise supplies password authentication and Warden session handling. Custom, carefully scoped account controllers retain signed **24-hour email verification**, **30-minute password recovery**, admin session revocation and public registration with explicit consent. The existing PostgreSQL rate limiter provides per-IP, per-email and pair limits, returning HTTP 429 for abuse. Only verified, enabled accounts may sign in.

Members cannot enumerate each other's uploads. Admin promotion, suspension and session revocation are auditable; the last active verified admin is protected. Test-data reset never deletes enrollment vectors. See [Accounts, security and email](docs/ACCOUNT_SECURITY_AND_EMAIL.md).

## Evaluation boundaries

An administrator stages and verifies the 935-image snapshot, registers models and dimensions, performs preflight, and generates only missing 120 SOURCE embeddings. A profile becomes eligible for activation only with **120/120** SOURCE coverage and an approved calibration report/threshold. Independent benchmarking must establish suitability for each profile.

External model weights and synthetic images are governed by their **own licenses**. The source-code MIT license does not relicense them; see [Model and dataset licenses](docs/model-data-licenses.md).

## Validation

GitHub CI runs PostgreSQL/pgvector migrations, Rails regression tests, real headless-browser system tests, Brakeman, RuboCop, Tailwind compilation and bilingual-doc integrity checks. The previously verified baseline was **49 tests / 227 assertions, 0 failures**, including 4 Chrome browser tests. This is source-level CI evidence, not live inference accuracy evidence.

```sh
bin/rails test
bin/rails test:system
bundle exec brakeman --no-pager
bundle exec rubocop
bin/rails tailwindcss:build
ruby scripts/check_bilingual_docs.rb
```

## Documentation and support

Start with [Documentation index](docs/index.md) for bilingual architecture, deployment, UI/operations, troubleshooting, security, and data/model licensing.

- [UI/UX and operations](docs/UI_UX_AND_OPERATIONS.md)
- [Deployment and external acceptance](docs/deployment.md)
- [Contributing](.github/CONTRIBUTING.md)
- [Security policy](.github/SECURITY.md)
- [Support](.github/SUPPORT.md)

## License and attribution

Source code: **MIT**, © 2026 **Đăng Khoa <i.am@dangkhoa.dev>** — [LICENSE](LICENSE).

CompactFaces dataset and external Qwen/WeMM weights have separate upstream terms. Do not present this project as an official upstream model release or a validated high-stakes face identification system.
