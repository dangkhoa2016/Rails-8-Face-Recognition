# Rails 8 Face Recognition — UI/UX and Operations

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](UI_UX_AND_OPERATIONS.vi.md)

This document describes the implemented application screens, routes, authorization and background processes. CI tests the Rails application with PostgreSQL/pgvector and a headless browser. Actual Modal, Cloudflare R2 and transactional SMTP workflows require deployment-specific qualification.

## 1. Interface map and access control

| Screen | Route | Permission |
|---|---|---|
| Home, About, Privacy, Terms | /, /about, /privacy, /terms | Public |
| Sign-in/out, registration, email verification, reset password | /sign_in, /session, /registration, /verify_email, /forgot_password, /reset_password | Public/session |
| Sample gallery/detail | /samples, /samples/:id | Member/Admin |
| Authorized image stream | /private/images/:id | Object-level |
| Private submissions | /submissions, /submissions/new, /submissions/:id | Owner |
| Recognition requests and history | /recognition, /recognition/new, /recognition/:id | Request owner |
| Test-data reset | /data_resets | Member/admin scopes |
| Admin dashboard | /admin | Admin |
| Identity and image registry | /admin/identities, /admin/face_images | Admin |
| Dataset imports | /admin/dataset_imports | Admin |
| Inference services and embedding models | /admin/inference_services, /admin/embedding_models | Admin |
| Profiles and policies | /admin/embedding_profiles, /admin/recognition_policies | Admin |
| Unknown tests | /admin/unknown_tests | Admin |
| User management and audit logs | /admin/users, /admin/audit_events | Admin |

Writes use CSRF-protected POST/PATCH/DELETE actions. Controller checks enforce object ownership even when IDs are guessed. Devise/Warden sessions plus PostgreSQL throttling guard the application. Email verification precedes access.

## 2. UI/UX behavior

- Tailwind CSS 4, responsive grids/sidebar, accessible labels, status badges, error and empty states.
- English/Vietnamese selector with signed preferences and Light/Dark/System theme.
- Stimulus-controlled mobile navigation with updated aria-expanded state and skip-to-content link.
- Turbo forms and periodic job-state refresh on active views.
- Recognition outcomes use Matched, Unknown, Indeterminate, Failed and Processing states only when scientifically qualified.
- Cosine similarity is not a calibrated probability.

## 3. Operating workflow

1. Prepare Ruby, PostgreSQL/pgvector, environment secrets and the first admin account; start Rails + Solid Queue.
2. Import an authorized snapshot: exactly 935 1024×1024 PNGs, 120 Core and 67 Additional identities with 5 slots and SHA-256 checks.
3. Configure private R2 reference/submission buckets; independently verify store, read, deletion and TTL.
4. Allowlist the exact Modal HTTPS hostname and configure server-only bearer secret; check /v1/models.
5. Register Qwen/WeMM capabilities and pinned revisions. Create or reuse an embedding profile keyed by model, revision, dimension, preprocessing and instruction.
6. Preflight one SOURCE vector, then enqueue only missing SOURCE vectors. Activation needs 120/120 embeddings.
7. Evaluate independently in the inference repository, register the report hash/threshold, approve the policy and activate that exact profile.
8. Members browse samples or submit authorized images; recognition compares against the fixed Core SOURCE gallery. Own results/uploads remain private and expire.
9. Switching 1024D → 4096D → 1024D reuses the prior 1024D embeddings without new GPU calls.

### Dataset directory setup (server operator)

The dataset Source URL in Rails Admin is **provenance only**. The importer does not download from it. A trusted operator must download the authorized CompactFaces snapshot onto the same machine/container as Rails, **outside the Git repository**, and provide its absolute directory via `DATASET_IMPORT_ROOT` to both Rails/Puma and Solid Queue.

```sh
hf download dangkhoa2016/compactfaces-synthetic-face-dataset --repo-type dataset --local-dir /content/krw-workspace/compactfaces-dataset
test -f /content/krw-workspace/compactfaces-dataset/data/train/metadata.csv
find /content/krw-workspace/compactfaces-dataset/data/train/images -type f -name '*.png' | wc -l
# Expected output: 935
```

Start the application **and background jobs** with this environment variable, e.g. from the Rails project directory:

```sh
DATASET_IMPORT_ROOT=/content/krw-workspace/compactfaces-dataset bin/dev
```

If Puma and Solid Queue have separate process managers, configure the same environment variable in **both** and restart them; a shell export does not update already-running processes. `.env.example` is a template only: Rails does not load it automatically. Reload the dataset-import detail page to inspect the configured path and metadata presence, then select **Verify and import**. Metadata presence is a lightweight preflight, **not** verification of 935 image bytes, SHA-256 or image consistency. The published metadata calls Additional rows `ADDITIONAL_OPTIONAL`; Rails normalizes this to the internal `additional` collection when verifying.

The original dataset and model licenses still apply; the import reads only from the operator-selected server directory and does not trigger model inference.

## 4. Main services and jobs

| Component | Responsibility |
|---|---|
| DatasetImports::VerifiedSnapshot | Verify the manifest and ingest images |
| ImageUploads::Validate / Submissions::Create | Validate private uploads, consent, TTL |
| Embeddings::Client / Embeddings::Ensure | Validate HTTPS response and reuse immutable embeddings |
| Embeddings::Schedule / EmbeddingGenerationJob | Enqueue only missing vectors and handle leases |
| ProfilePreflightJob | Pin configuration from representative SOURCE |
| Recognition::Decide / RecognizeFaceJob | Match within approved active profile and policy |
| PurgeExpiredSubmissionsJob | Remove expired transient data via Solid Queue |

## 5. Security and integration limitations

Keep credentials in server secrets. Use PostgreSQL rate limits, enforced roles, audit logging, no public Active Storage routes and no direct user access to reference embeddings. Model inference, 935-image import, R2 transport, external email delivery and full production threat modeling remain separate qualification tasks. See [Deployment](deployment.md), [Security](../.github/SECURITY.md) and [License boundaries](model-data-licenses.md).
