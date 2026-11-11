# Pull Request

> 🌐 Language / Ngôn ngữ: [English](PULL_REQUEST_TEMPLATE.md) | **Tiếng Việt**

## Mục đích
Thay đổi này giải quyết vấn đề nào?

## Kiểm thử
- [ ] Rails tests và system tests thành công.
- [ ] Brakeman và RuboCop thành công.
- [ ] Đã kiểm tra cặp tài liệu EN/VI và liên kết.
- [ ] Có regression tests nếu đụng tới xác thực, enrollment, nguồn gốc vector hoặc phân quyền.
- [ ] Không chứa secrets hay ảnh khuôn mặt người dùng.

## Ảnh hưởng migration và dịch vụ
Nêu migration PostgreSQL, tác động Devise session, tương tác Modal/R2/SMTP và bằng chứng kiểm thử live nếu đã có.
