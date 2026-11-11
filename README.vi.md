# Rails 8 Face Recognition

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

[![Rails CI](https://github.com/dangkhoa2016/Rails-8-Face-Recognition/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dangkhoa2016/Rails-8-Face-Recognition/actions/workflows/ci.yml)
![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Ruby](https://img.shields.io/badge/Ruby-3.3-CC342D?logo=ruby&logoColor=white)
![Rails](https://img.shields.io/badge/Rails-8.1-D30001?logo=rubyonrails&logoColor=white)
![Tailwind](https://img.shields.io/badge/Tailwind_CSS-4-06B6D4?logo=tailwindcss&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-pgvector-4169E1?logo=postgresql&logoColor=white)
![Authentication](https://img.shields.io/badge/Auth-Devise%205.0.4-7C3AED)
[![Source license: MIT](https://img.shields.io/badge/Source%20License-MIT-yellow.svg)](LICENSE)

**Rails 8 Face Recognition** là ứng dụng Rails song ngữ để nghiên cứu **nhận diện khuôn mặt 1:N trên dữ liệu tổng hợp CompactFaces**. Dự án dùng PostgreSQL/pgvector lưu embedding profiles bất biến, Tailwind CSS 4/Hotwire cho giao diện, Devise/Warden xác thực, Cloudflare R2 private để lưu ảnh, Solid Queue cho background jobs và endpoint Modal inference được triển khai độc lập.

**Quan trọng:** đây là phần mềm nghiên cứu, **chưa được nghiệm thu cho nhận diện sinh trắc học production**. Cosine similarity **không phải xác suất**; CI thành công không chứng minh Modal/R2/SMTP live đã được nghiệm thu.

## Mục tiêu dự án

Cho phép so sánh nhiều model mà không trộn vector của các checkpoint, dimension, preprocessing hoặc instruction khác nhau. Mỗi profile có khóa cấu hình bất biến. Chuyển 1024D → 4096D → 1024D sẽ **tái sử dụng vector 1024D**, không tự động gọi GPU lần nữa.

Benchmark chất lượng nhận diện đặt **độc lập với Rails**, trong repository [Multimodal-Embeddings-AI-Inference](https://github.com/dangkhoa2016/Multimodal-Embeddings-AI-Inference). Rails chỉ nhận diện khi gallery SOURCE đủ và có policy hiệu chuẩn dành riêng cho profile đã được phê duyệt.

## Tính năng

| Nhóm | Chức năng |
|---|---|
| Bộ dữ liệu | 120 Core identities × 5 ảnh + 67 Additional identities × 5 = **935** ảnh tổng hợp |
| Enrollment | Chỉ 120 ảnh Core **SOURCE** được enroll; P1/P2/E1/E2 là probes |
| Mô hình | Qwen3-VL-Embedding-8B và WeMM-Embedding-9B qua API Modal có xác thực |
| Vector | pgvector biến độ dài; nhiều dimension/revision cùng tồn tại, không ghi đè |
| Nhận diện | Exact cosine trong profile đang active; Unknown cần ngưỡng được phê duyệt |
| Tài khoản | Devise 5.0.4/Warden, xác minh email, thu hồi session, PostgreSQL login throttling |
| Thành viên | Gallery, upload private, gửi yêu cầu/xem kết quả/lịch sử, reset dữ liệu riêng |
| Admin | Import, identities, models, services, profiles, policies, users, audit logs |
| UI/UX | Tiếng Anh/Việt, Sáng/Tối/Theo hệ thống, Tailwind 4 responsive, Turbo/Stimulus |
| Email | Action Mailer SMTP: Resend, Brevo, Postmark, SendPulse, SMTP riêng |
| Jobs | Solid Queue chạy import, inference, recognition, reset và cleanup |

## Kiến trúc

```text
Trình duyệt / Tailwind 4 / Hotwire
  -> Rails 8.1 + Devise/Warden + rate limit PostgreSQL
      -> PostgreSQL 17 + pgvector (profiles và vectors độc lập)
      -> Active Storage private / Cloudflare R2
      -> Solid Queue -> API embedding Modal có Bearer authentication
```

Không gửi ảnh khuôn mặt hoặc bearer token tới dịch vụ tracking công khai. Truy cập ảnh qua controller kiểm tra quyền. Xem [Kiến trúc](docs/architecture.vi.md).

## Chạy thử cục bộ

Cần Ruby 3.3, Bundler, PostgreSQL có extension pgvector và mạng cài gems/Tailwind.

```sh
bundle install
cp .env.example .env
# Cấu hình DATABASE_URL và secrets bằng env loader cục bộ.
bin/rails db:prepare
bin/rails db:seed
bin/dev
```

Chỉ đặt ADMIN_EMAIL và ADMIN_PASSWORD khi seed admin lần đầu. Không thay đổi mật khẩu admin đã có. Development chạy Rails, Tailwind watch và Solid Queue. Production cần TLS, Rails secrets mạnh, trusted proxies và object storage private.

## Xác thực và bảo mật

Devise xác thực mật khẩu, Warden quản lý session. Các controller riêng vẫn xử lý **email verification 24 giờ**, **reset password 30 phút**, session revocation và đăng ký công khai có consent. Rate limiter PostgreSQL giới hạn theo IP, email và cặp IP/email; trả HTTP 429 khi bị lạm dụng. Chỉ tài khoản đã xác minh và chưa khóa mới đăng nhập.

Member không được truy cập upload của nhau. Thăng quyền, khóa và thu hồi session được audit; bảo vệ admin cuối cùng. Reset test data không xóa enrollment vectors. Xem [Tài khoản, bảo mật và email](docs/ACCOUNT_SECURITY_AND_EMAIL.vi.md).

## Ranh giới đánh giá

Admin import snapshot 935 ảnh đã xác minh, khai báo model/dimension, preflight và chỉ tạo những vector SOURCE còn thiếu. Chỉ profile có đủ **120/120** vector SOURCE và policy/ngưỡng được review mới được activate. Benchmark độc lập cung cấp bằng chứng phù hợp cho từng profile.

Weights của model và ảnh tổng hợp có **giấy phép riêng**. MIT của mã nguồn không cấp lại giấy phép cho chúng; xem [Giấy phép mô hình/dữ liệu](docs/model-data-licenses.vi.md).

## Kiểm thử

GitHub CI chạy PostgreSQL/pgvector migrations, Rails regression tests, Chrome headless system tests, Brakeman, RuboCop, build Tailwind và kiểm tra tài liệu song ngữ. Mốc đã xác minh trước đó là **49 tests / 227 assertions, không lỗi**, gồm 4 browser tests. Đây là bằng chứng kiểm thử mã nguồn, không phải đo độ chính xác inference live.

```sh
bin/rails test
bin/rails test:system
bundle exec brakeman --no-pager
bundle exec rubocop
bin/rails tailwindcss:build
ruby scripts/check_bilingual_docs.rb
```

## Tài liệu và hỗ trợ

Bắt đầu tại [Mục lục tài liệu](docs/index.vi.md) cho kiến trúc, triển khai, UI/UX, khắc phục lỗi, bảo mật và giấy phép song ngữ.

- [Giao diện và vận hành](docs/UI_UX_AND_OPERATIONS.vi.md)
- [Triển khai và nghiệm thu](docs/deployment.vi.md)
- [Đóng góp](.github/CONTRIBUTING.vi.md)
- [Chính sách bảo mật](.github/SECURITY.vi.md)
- [Hỗ trợ](.github/SUPPORT.vi.md)

## Giấy phép và ghi nguồn

Mã nguồn: **MIT**, © 2026 **Đăng Khoa <i.am@dangkhoa.dev>** — [LICENSE](LICENSE).

Dữ liệu CompactFaces và weights Qwen/WeMM có điều khoản upstream riêng. Không giới thiệu dự án như bản phát hành chính thức của nhà phát triển model hoặc hệ thống nhận diện khuôn mặt quan trọng đã nghiệm thu.
