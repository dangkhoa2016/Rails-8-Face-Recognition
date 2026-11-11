# Đóng góp

> 🌐 Language / Ngôn ngữ: [English](CONTRIBUTING.md) | **Tiếng Việt**

Cảm ơn bạn đóng góp cho Rails 8 Face Recognition. Đây là phần mềm nghiên cứu dùng định danh tổng hợp, không phải dịch vụ sinh trắc học đã nghiệm thu production.

## Quy tắc phát triển
- Commit tập trung, dễ review (ưu tiên dưới khoảng 600 dòng thay đổi).
- Cập nhật đồng thời tài liệu tiếng Anh và tiếng Việt, có liên kết chuyển ngôn ngữ.
- Không thay đổi quy tắc Core SOURCE, tái sử dụng vector hay tính bất biến của profile nếu chưa có test.
- Không lộ ảnh người dùng, mật khẩu, inference token, tệp môi trường hoặc thông tin R2.
- Bổ sung regression tests cho bảo mật tài khoản, phân quyền dữ liệu và nguồn gốc vector.

## Kiểm tra cục bộ
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

Cần PostgreSQL có pgvector. Nghiệm thu Modal GPU/R2/SMTP cần cấu hình dịch vụ thật; CI xanh không chứng minh chất lượng inference live.

## Gửi thay đổi
Mô tả hành vi mong đợi, bằng chứng, tác động bảo mật, migration và mã commit. Không đính kèm ảnh khuôn mặt riêng tư hoặc bí mật.
