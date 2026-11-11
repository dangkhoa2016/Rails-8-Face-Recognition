# Chính sách bảo mật

> 🌐 Language / Ngôn ngữ: [English](SECURITY.md) | **Tiếng Việt**

## Phạm vi hỗ trợ
Rà soát bảo mật áp dụng cho nhánh phát triển hiện tại và các bản phát hành trong tương lai. CI xanh không đồng nghĩa với bảo đảm an toàn production.

## Báo cáo lỗ hổng riêng tư
Gửi email **Đăng Khoa <i.am@dangkhoa.dev>**, kèm mô tả, bước tái lập và revision ảnh hưởng. **Không đăng công khai** credential, ảnh riêng tư, SMTP token, cách vượt xác thực hoặc dữ liệu tài khoản.

## Ranh giới bảo vệ
- Devise/Warden kết hợp rate limiting lưu PostgreSQL.
- Chỉ đăng nhập sau xác minh email; từ chối tài khoản bị khóa và session bị thu hồi.
- Chỉ admin thay đổi profile/policy; thao tác đặc quyền có audit.
- Ảnh upload riêng tư, TTL và kiểm tra quyền trước khi trả ảnh.
- HTTPS, danh sách hostname cho phép và bearer token chỉ nằm phía server.
- Chỉ trả kết quả nhận diện khi profile đủ vector và có policy được hiệu chuẩn/phê duyệt.

Cần phân biệt bằng chứng unit test với nghiệm thu môi trường production.
