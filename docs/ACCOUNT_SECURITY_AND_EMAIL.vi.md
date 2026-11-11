# Tài khoản, i18n, theme, reset test data và email delivery

🌐 [English](ACCOUNT_SECURITY_AND_EMAIL.md) | **Tiếng Việt**

## Phạm vi

Ứng dụng hỗ trợ đăng ký email tự phục vụ với vai trò **member**, xác thực địa chỉ trước khi đăng nhập, quên/đặt lại mật khẩu, khóa/mở khóa tài khoản, quản lý vai trò và thu hồi phiên. Các chức năng này không thay thế kiểm thử bảo mật hoặc xác thực trực tiếp với nhà cung cấp email trước khi mở đăng ký công khai.

## Tiếng Anh / tiếng Việt

- Locale `en` hoặc `vi`, mặc định `en`. Chọn trong header, hoạt động cả khi chưa đăng nhập.
- Tùy chọn được lưu vào signed cookie; nếu đã đăng nhập thì ghi `users.preferred_locale`.
- Nội dung chính, biểu mẫu, điều hướng, email xác thực, email đặt lại mật khẩu và thông báo xác thực dùng Rails I18n, tập tin `config/locales/en.yml`, `vi.yml`, `ui.vi.yml`.
- Các câu tiếng Anh cũ giữ nguyên dưới dạng fallback nếu chưa có bản dịch. Trước release cần kiểm tra bản dịch bằng trình duyệt và đọc soát thủ công.

## Theme Light / Dark / Auto

- Header có ba lựa chọn: Light, Dark, System (Auto).
- `html[data-theme]` điều khiển `color-scheme`; CSS `light-dark()` theo cài đặt OS nếu là `auto`.
- Signed cookie lưu lựa chọn, không lưu vào database; không cần JavaScript để đọc theme ban đầu. Stimulus chỉ giúp submit chọn theme ngay lập tức.
- Kiểm tra thực tế về tương phản (WCAG), Safari/mobile, focus states và auto-switch khi OS thay đổi là bước nghiệm thu cần có.

## Reset dữ liệu test an toàn

Endpoint `GET /data_resets` yêu cầu đăng nhập; `POST /data_resets` yêu cầu CSRF hợp lệ, rate limit và cụm từ xác nhận chính xác. Các job lưu `cutoff_at` để tránh xóa bản ghi phát sinh sau lúc yêu cầu.

| Phạm vi | Ai được phép | Dữ liệu bị xóa | Cụm xác nhận |
|---|---|---|---|
| `mine` | Thành viên/admin | Ảnh submission tạm và lượt nhận diện của chính người yêu cầu | `RESET MY DATA` |
| `all_test_activity` | Chỉ admin | Submission tạm của mọi người và toàn bộ lịch sử recognition attempts trong phạm vi cutoff | `RESET ALL TEST DATA` |
| `probe_cache` | Chỉ admin | Cache embedding + request dành cho **sample_probe**; không xóa SOURCE enrollment | `RESET PROBE CACHE` |

Không scope nào xóa Core identities, SOURCE enrollment, bộ ảnh dataset tham chiếu, profile/model/service, chính sách hiệu chuẩn hay embedding enrollment. `probe_cache` có thể dẫn đến phát sinh thêm GPU inference khi thử lại. Xóa dữ liệu khó khôi phục; backup và thử trên staging trước khi dùng ở production.

Job: `DataResetJob` và dịch vụ `Submissions::ResetTestData`. Theo dõi số bản ghi bị xóa qua `GET /data_resets/:id`. Admin reset được ghi audit. Việc xóa R2/Active Storage bất đồng bộ cần kiểm tra bằng storage thật.

## Đăng ký / xác minh email

Luồng: `/registration/new` → `POST /registration` → xác minh từ email → `GET /verify_email?token=...` xem trang xác nhận **không kích hoạt tự động** → `POST /verify_email` kích hoạt → đăng nhập. Token xác minh 24 giờ, token reset mật khẩu 30 phút. Đổi mật khẩu thu hồi các phiên đăng nhập đã cấp trước đó. Yêu cầu gửi lại email có khoảng nghỉ 2 phút và giới hạn rate limit.

Tài khoản đăng ký luôn có role `member`; không chấp nhận `role`, `email_verified_at` hoặc các cột nhạy cảm từ POST. Email đã tồn tại trả lời chung nhằm giảm việc dò tài khoản. Người dùng phải đồng ý Terms/Privacy trước khi đăng ký.

## SMTP transactional email

Trong Rails môi trường `development`, mặc định `EMAIL_PROVIDER=file`: email được ghi vào thư mục `tmp/mails/` để dễ kiểm tra link, **không gửi ra Internet**. `test` sử dụng ActionMailer test adapter.

Trong production, self-registration sẽ tự tắt nếu thiếu SMTP credentials, verified sender hoặc `APP_HOST`. Để cấu hình:

```dotenv
PUBLIC_REGISTRATION_ENABLED=true
APP_HOST=faces.example.com
EMAIL_PROVIDER=resend
EMAIL_FROM=Rails 8 Face Recognition <no-reply@faces.example.com>
EMAIL_SMTP_PORT=587
EMAIL_SMTP_USERNAME=resend
EMAIL_SMTP_PASSWORD=<server-secret-only>
EMAIL_HELO_DOMAIN=faces.example.com
```

Tùy `EMAIL_PROVIDER`:

| Provider | Host | Username / Secret |
|---|---|---|
| `resend` | `smtp.resend.com` | username `resend`, mật khẩu là API key phù hợp SMTP |
| `brevo` | `smtp-relay.brevo.com` | SMTP login và **SMTP key** (không phải REST API key) |
| `postmark` | `smtp.postmarkapp.com` | Server API token ở cả username/password hoặc cặp SMTP credential của Message Stream |
| `sendpulse` | Đặt `EMAIL_SMTP_HOST` theo SMTP Dashboard của tài khoản | SMTP login/password được cấp trên Dashboard |
| `smtp` | `EMAIL_SMTP_HOST` tự cấu hình | SMTP username/password tự cấu hình |

Port 587 dùng STARTTLS, port 465 dùng implicit TLS. Production cần xác minh domain/SPF/DKIM/DMARC, đúng From address, quy trình xử lý bounce/delivery và giám sát chi phí/rate từ provider. Không lưu API key trong Git, database, log hay trình duyệt.

Các tài liệu nhà cung cấp:
- Resend: <https://resend.com/changelog/smtp-service>
- Brevo: <https://help.brevo.com/hc/en-us/articles/7924908994450-Send-transactional-emails-using-Brevo-SMTP>
- Postmark: <https://postmarkapp.com/support/article/1112-smtp-settings>
- SendPulse: <https://sendpulse.com/knowledge-base/smtp/setup-smtp-server>

## Bảo mật tài khoản và hạn mức

- Rate limit dùng PostgreSQL với bản ghi có unique key và `SELECT ... FOR UPDATE` (Rails `with_lock`) nên hoạt động trên nhiều web worker; key email/IP được HMAC bằng `secret_key_base`.
- Login: IP tối đa 30 lượt/15 phút; email tối đa 8 lượt/15 phút; cặp IP + email tối đa 5 lượt/15 phút. Khi vượt mức trả HTTP 429.
- Registration 6/IP/giờ, 3/email/giờ; resend 10/IP/giờ, 3/email/giờ; forgot password 10/IP/giờ, 3/email/giờ.
- Upload/recognition/unknown tests/reset cũng dùng throttle phía server; giao diện ẩn nút không thay thế controller authorization.
- Password tối thiểu 12 ký tự; session nonce được kiểm tra qua DB ở mỗi request; admin có thể khóa account, quản lý vai trò, revoke sessions.
- Hệ thống chặn admin tự hạ quyền/tự khóa và không cho vô hiệu hóa admin cuối cùng. Role transition dùng khóa đồng thời và audit log chung transaction.
- CSRF, security cookies, `SameSite`, HTTPS trong production, CSP và private storage là các lớp bổ sung.

Giới hạn quan trọng: Throttle theo email/IP là lớp tối thiểu, không phải phòng vệ hoàn chỉnh chống bot hoặc credential stuffing phân tán. Với website công khai, thêm WAF/CAPTCHA/chống abuse, giám sát hành vi, secret rotation, cấu hình trusted proxy IP, định kỳ dọn `auth_throttles`, và đánh giá pháp lý/quyền riêng tư. Không có xác nhận chạy thực tế trên môi trường PostgreSQL/SMTP trong phiên tạo mã này.

## Chạy kiểm thử

```sh
bundle install
bin/rails db:prepare
bin/rails test
bin/dev
```

Kiểm tra thủ công bằng trình duyệt: chuyển en/vi, Light/Dark/Auto, email xác thực, link hết hạn, login lockout, password reset thu hồi session, member bị 403 ở admin, bảo vệ admin cuối cùng, reset hai tài khoản độc lập và không mất 120 SOURCE enrollment/vector.

## Devise và trạng thái kiểm thử

Xác thực sử dụng **Devise 5.0.4 / Warden**; các controller riêng vẫn xử lý xác minh email, reset password bằng signed token và rate limit PostgreSQL. GitHub CI đã chạy Rails/PostgreSQL/pgvector migrations, Ruby tests và Chrome system tests. SMTP, R2 và Modal live cần kiểm thử riêng.
