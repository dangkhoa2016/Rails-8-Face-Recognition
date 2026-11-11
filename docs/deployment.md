# Deployment and operational acceptance

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](deployment.vi.md)

## Prerequisites
Ruby 3.3, Bundler, Rails 8.1, PostgreSQL with pgvector, TLS termination and a secret manager. Production storage needs two **private** Cloudflare R2 buckets with least-privilege credentials.

## Local development
1. Run `bundle install`.
2. Run `bin/rails db:prepare` (see the PostgreSQL setup requirements below).
3. Set ADMIN_EMAIL and ADMIN_PASSWORD securely, then run `bin/rails db:seed`.
4. Run `bin/dev` to start Rails, Tailwind and Solid Queue.

The first admin is created only when both variables are set. Existing passwords are never overwritten. Do not commit a real .env.

## Database and jobs
- Configure DATABASE_URL with a PostgreSQL server supporting the vector extension.
- Verify immutable-vector triggers after migrations.
- Start Solid Queue worker/scheduler (`bin/jobs`) with the same secrets as Rails.
- Monitor job leases/retries, cleanup, and backup recovery before accepting user uploads.

### PostgreSQL schema and migrations

**Why `db/structure.sql` instead of `db/schema.rb`?** This application uses PostgreSQL functions and triggers to protect immutable face embeddings, image and profile identities, and approved recognition policies. Rails' Ruby schema dumper does not reproduce these custom objects. The PostgreSQL SQL snapshot preserves the functions, triggers, vector extension, constraints, indexes, and foreign keys. Using pgvector **alone** does not require SQL schema format; the custom triggers are the deciding factor.

`db/structure.sql` is **a schema snapshot, not a data backup**: it does not include user records, face images, or embedding values. It complements the migration files rather than replacing them. Never edit generated `db/structure.sql` or `db/schema.rb` by hand.

#### Create and run migrations

For example, to add a description column to `identities`:

```bash
bin/rails generate migration AddDescriptionToIdentities description:text
bin/rails db:migrate
bin/rails db:migrate:status
git diff -- db/structure.sql
```

The generator creates a new `db/migrate/*.rb` file. `db:migrate` executes pending migrations, records their versions in `schema_migrations`, and regenerates **`db/structure.sql`** through `pg_dump`. Include both the migration file and the updated SQL snapshot in the same reviewed Git change; do not add a competing `db/schema.rb`.

For a PostgreSQL-specific trigger or function, use SQL in a Rails migration (typically `execute`) and write explicit `up` and `down` methods when it can be reversed. Drop a trigger before dropping the function it calls. Review the regenerated SQL to ensure the function and trigger are present, not only the affected table.

#### Rollbacks, bootstrapping, and access rights

```bash
# Execute against the intended development/test database.
bin/rails db:rollback STEP=1
bin/rails db:migrate
bin/rails db:prepare
```

- `db:rollback` runs the previous migration's reverse operation. Custom SQL often needs a carefully implemented `down`; an irreversible migration should fail explicitly.
- `db:migrate` runs migrations not yet applied to the connected database.
- `db:prepare` initializes a database when needed, loads the SQL snapshot using `psql` on a fresh database, and applies pending migrations. **Do not run destructive schema load, reset, or drop tasks against a database containing real data.**

The SQL snapshot contains `CREATE EXTENSION IF NOT EXISTS vector`. If the application's PostgreSQL role lacks permission to create extensions, a PostgreSQL administrator must enable pgvector **in each target database**, before Rails attempts `db:prepare`:

```sql
-- Connect to the intended database as a PostgreSQL administrator.
CREATE EXTENSION IF NOT EXISTS vector;
```

The Rails role still needs normal privileges to create or change the application's schema objects. It should **not** be given PostgreSQL superuser privileges just to run Rails migrations.

`config/application.rb` already configures:

```ruby
config.active_record.schema_format = :sql
# Applied during Rails initialization to schema exports:
ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ["--no-comments"]
```

These lines are shown for explanation, **not** to be added again. `--no-comments` prevents generated `COMMENT ON EXTENSION vector` statements from requiring ownership of the administrator-installed extension. The host running Rails also needs `pg_dump` and `psql` compatible with its PostgreSQL server. pgvector itself must be installed on the server.

#### Validate after a migration or restore

```bash
bin/rails db:migrate:status
bin/rails db:schema:dump
bin/rails test test/services/database_structure_test.rb
```

Inspect the **intended development/test database** with SQL when necessary:

```sql
SELECT extname FROM pg_extension WHERE extname = 'vector';

SELECT tgname FROM pg_trigger
WHERE NOT tgisinternal
ORDER BY tgname;

SELECT version FROM schema_migrations ORDER BY version;
```

The current application defines **six custom PostgreSQL triggers**. `test/services/database_structure_test.rb` checks these triggers and the vector extension. For full restoration confidence, run `db:prepare` and `db:migrate` on a **disposable empty database**, not one with real data.

| Symptom | Cause and remedy |
|---|---|
| `permission denied to create extension "vector"` | Ask the PostgreSQL administrator to enable pgvector in the **target database** before Rails loads the SQL snapshot. |
| `must be owner of extension vector` | An older dump includes `COMMENT ON EXTENSION vector`; confirm `--no-comments` is enabled and regenerate `db/structure.sql`. |
| Missing or incompatible `pg_dump` / `psql` | Install PostgreSQL client tools compatible with the database server. |
| Tables exist but custom triggers are missing | The database may have been loaded from `db/schema.rb`; test restoration from the SQL snapshot in a fresh disposable database, and assess live databases separately. |
| `ActiveRecord::IrreversibleMigration` | Review and implement a safe reverse operation if possible; do not modify the SQL snapshot manually. |

## Email signup
Choose EMAIL_PROVIDER (resend, brevo, postmark, sendpulse, smtp), plus EMAIL_FROM, APP_HOST and EMAIL_SMTP_* secrets. Verify sender domain, SPF/DKIM/DMARC, delivery and password recovery before public signup.

## Inference and dataset
- Stage an authorized CompactFaces snapshot on the server, never accept arbitrary import URLs from members.
- Validate all 935 images and checksums; only Core SOURCE faces can be enrolled.
- Restrict INFERENCE_ALLOWED_HOSTS to exact HTTPS hosts; keep bearer token server-side.
- Verify pinned revision, preprocessing, dimension, config hash, quota and cost against live Modal.
- Require independent threshold calibration and policy approval before recognition.

## Acceptance checks
Run Rails tests, browser system tests, Brakeman, RuboCop, Tailwind build and bilingual documentation checks as documented in [Contributing](../.github/CONTRIBUTING.md).

Passing GitHub CI is not live proof of Modal/R2/SMTP behavior, regulatory readiness, or disaster recovery.
