# Architecture and feature coverage

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](architecture.vi.md)

```text
Browser (Tailwind / ERB / Turbo / Stimulus)
  -> Rails 8 + Devise/Warden + admin/member authorization
      -> PostgreSQL + pgvector (Core SOURCE is the only enrollment gallery)
      -> Active Storage -> two private Cloudflare R2 buckets
      -> Solid Queue (preflight, missing embeddings, recognition, import, cleanup)
          -> authenticated Modal embedding API (Qwen / WeMM)
```

## Implemented components
- Public: landing, about, privacy, terms, sign-in.
- Member: gallery, samples, private uploads/deletion, recognition requests/status/results/history.
- Admin: dashboard, dataset imports, identity/image registry, service/model registry, immutable embedding profiles, policies, unknown probes and audit history.
- Services: metadata/manifest checks, image validation, permission-checked private blobs, hostname-allowlisted inference, validated responses, preflight, missing-only generation.
- Background: Solid Queue and recurring cleanup. Real network/storage behavior needs separate deployed integration tests.

## Profile identity and reuse
A model + revision + dimension + preprocessing + instruction combination has a deterministic fingerprint. An embedding is unique per (image, profile). Returning to a complete profile never deletes vectors or needs another inference request. Database constraints and triggers protect immutability.

## Evaluation isolation
The independent benchmark notebook lives in the external inference repository. Rails stores only reviewed policy metadata, report reference/hash and a threshold. A 120/120 SOURCE gallery and approved policy are required before Matched/Unknown decisions. Cosine similarity is not a probability.

## Validation boundary
CI verifies Rails/PostgreSQL, Brakeman, RuboCop, browser flows and Tailwind. It does not replace real 935-image import, R2, Modal, SMTP, privacy/legal review, or production acceptance.
