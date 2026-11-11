# Triển khai và nghiệm thu vận hành

> 🌐 Language / Ngôn ngữ: [English](deployment.md) | **Tiếng Việt**

## Yêu cầu
Ruby 3.3, Bundler, Rails 8.1, PostgreSQL có pgvector, TLS termination và secret manager. Production cần hai bucket Cloudflare R2 **riêng tư** với quyền truy cập tối thiểu.

## Development cục bộ
1. Chạy `bundle install`.
2. Chạy `bin/rails db:prepare` (xem các yêu cầu PostgreSQL bên dưới).
3. Cấp ADMIN_EMAIL và ADMIN_PASSWORD an toàn rồi chạy `bin/rails db:seed`.
4. Chạy `bin/dev` để khởi động Rails, Tailwind và Solid Queue.

Chỉ tạo admin đầu tiên khi đủ hai biến. Không ghi đè mật khẩu hiện có, không commit .env thật.

## Database và background jobs
- Cấu hình DATABASE_URL trỏ tới PostgreSQL có extension vector.
- Kiểm tra các trigger chống thay đổi vector sau migrations.
- Chạy Solid Queue worker/scheduler (`bin/jobs`) với cùng secrets như web.
- Theo dõi lease/retry, dọn dữ liệu và thử khôi phục backup trước khi nhận upload.

### PostgreSQL schema và migrations

**Vì sao dùng `db/structure.sql` thay vì `db/schema.rb`?** Dự án sử dụng PostgreSQL function và trigger để bảo vệ embedding bất biến, thông tin định danh ảnh/profile và recognition policy đã phê duyệt. Rails Ruby schema dumper không tái dựng được đầy đủ những đối tượng tùy chỉnh này. SQL snapshot giữ lại function, trigger, extension vector, constraint, index và foreign key. **Riêng việc dùng pgvector không bắt buộc SQL schema**; nguyên nhân quyết định là các trigger PostgreSQL tùy chỉnh.

`db/structure.sql` là **bản chụp cấu trúc, không phải bản sao lưu dữ liệu**: nó không chứa bản ghi user, ảnh khuôn mặt hoặc giá trị embedding. File này bổ sung cho các migration, không thay thế chúng. Không chỉnh sửa thủ công `db/structure.sql` hoặc `db/schema.rb` do Rails sinh ra.

#### Tạo và chạy migration mới

Ví dụ bổ sung cột mô tả cho bảng `identities`:

```bash
bin/rails generate migration AddDescriptionToIdentities description:text
bin/rails db:migrate
bin/rails db:migrate:status
git diff -- db/structure.sql
```

Generator tạo file `db/migrate/*.rb` mới. `db:migrate` chạy các migration chưa áp dụng, ghi phiên bản vào `schema_migrations`, rồi tạo lại **`db/structure.sql`** bằng `pg_dump`. Khi review trên Git, đưa cả file migration mới và SQL snapshot đã cập nhật vào cùng một thay đổi; không bổ sung `db/schema.rb` song song để tránh nhầm lẫn.

Đối với trigger hoặc function đặc thù PostgreSQL, viết SQL trong migration Rails (thường qua `execute`) và định nghĩa rõ `up`, `down` khi thao tác có thể đảo ngược. Khi xóa function, hãy xóa trigger gọi function đó *trước*. Kiểm tra SQL snapshot được tạo lại có cả function lẫn trigger dự kiến, không chỉ bảng liên quan.

#### Rollback, khởi tạo database và quyền truy cập

```bash
# Chỉ chạy với database development/test mong muốn.
bin/rails db:rollback STEP=1
bin/rails db:migrate
bin/rails db:prepare
```

- `db:rollback` thực hiện thao tác đảo ngược migration trước đó. SQL tùy chỉnh thường cần tự viết `down` cẩn thận; migration không thể đảo ngược phải báo lỗi rõ ràng.
- `db:migrate` chạy các migration chưa được áp dụng trên database đang kết nối.
- `db:prepare` khởi tạo database khi cần, nạp SQL snapshot bằng `psql` cho database mới và áp dụng migration còn thiếu. **Không chạy các lệnh schema load, reset hoặc drop có tính phá hủy trên database chứa dữ liệu thật.**

SQL snapshot có lệnh `CREATE EXTENSION IF NOT EXISTS vector`. Khi tài khoản PostgreSQL của Rails không có quyền tạo extension, PostgreSQL administrator phải bật pgvector **trong từng database đích** trước khi Rails thực hiện `db:prepare`:

```sql
-- Kết nối đúng database đích bằng tài khoản quản trị PostgreSQL.
CREATE EXTENSION IF NOT EXISTS vector;
```

Tài khoản Rails vẫn cần các quyền thông thường để tạo hoặc sửa các đối tượng database của ứng dụng. **Không nên cấp quyền PostgreSQL superuser** chỉ để chạy Rails migration.

`config/application.rb` đã cấu hình sẵn:

```ruby
config.active_record.schema_format = :sql
# Được áp dụng khi Rails khởi tạo để xuất schema:
ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ["--no-comments"]
```

Các dòng trên dùng để giải thích, **không cần thêm lại**. Tùy chọn `--no-comments` ngăn tạo câu lệnh `COMMENT ON EXTENSION vector`, vốn yêu cầu Rails phải sở hữu extension do administrator cài đặt. Máy chạy Rails cũng cần có `pg_dump` và `psql` tương thích PostgreSQL server; pgvector phải được cài trên chính server đó.

#### Kiểm tra sau migration hoặc khôi phục

```bash
bin/rails db:migrate:status
bin/rails db:schema:dump
bin/rails test test/services/database_structure_test.rb
```

Khi cần, kiểm tra bằng SQL trên đúng **database development/test**:

```sql
SELECT extname FROM pg_extension WHERE extname = 'vector';

SELECT tgname FROM pg_trigger
WHERE NOT tgisinternal
ORDER BY tgname;

SELECT version FROM schema_migrations ORDER BY version;
```

Ứng dụng hiện có **6 PostgreSQL trigger tùy chỉnh**. `test/services/database_structure_test.rb` xác minh các trigger này và extension vector. Để nghiệm thu khả năng khôi phục, hãy chạy `db:prepare` và `db:migrate` trên **database mới, trống và dùng để thử nghiệm**, không phải database có dữ liệu thật.

| Triệu chứng | Nguyên nhân và cách xử lý |
|---|---|
| `permission denied to create extension "vector"` | Nhờ PostgreSQL administrator bật pgvector trong **database đích** trước khi Rails nạp SQL snapshot. |
| `must be owner of extension vector` | Bản dump cũ còn `COMMENT ON EXTENSION vector`; kiểm tra `--no-comments` và tạo lại `db/structure.sql`. |
| Thiếu `pg_dump` / `psql` hoặc phiên bản không tương thích | Cài PostgreSQL client tools phù hợp với server. |
| Có bảng nhưng thiếu custom trigger | Có thể database được tạo từ `db/schema.rb`; kiểm tra cách khôi phục SQL snapshot trên database thử nghiệm trống và đánh giá database đang chạy riêng biệt. |
| `ActiveRecord::IrreversibleMigration` | Xem xét bổ sung thao tác đảo ngược an toàn nếu khả thi; không tự sửa SQL snapshot. |

## Đăng ký email
Chọn EMAIL_PROVIDER (resend, brevo, postmark, sendpulse, smtp), đặt EMAIL_FROM, APP_HOST, EMAIL_SMTP_*. Xác minh domain, SPF/DKIM/DMARC, gửi nhận mail và reset password trước khi mở đăng ký.

## Inference và dữ liệu
- Stage snapshot CompactFaces hợp pháp trên server; không nhận URL import tuỳ ý của member.
- Xác minh 935 ảnh và checksum; chỉ Core SOURCE được enroll.
- INFERENCE_ALLOWED_HOSTS giới hạn đúng HTTPS hosts; token chỉ nằm trên server.
- Kiểm tra revision, preprocessing, dimension, config hash, quota và chi phí Modal thật.
- Cần hiệu chuẩn độc lập và phê duyệt policy trước nhận diện.

## Kiểm tra nghiệm thu
Chạy Rails tests, system tests, Brakeman, RuboCop, build Tailwind và kiểm tra tài liệu song ngữ như [Hướng dẫn đóng góp](../.github/CONTRIBUTING.vi.md).

CI xanh không chứng minh vận hành Modal/R2/SMTP live, tuân thủ pháp lý hay khả năng phục hồi sự cố.
