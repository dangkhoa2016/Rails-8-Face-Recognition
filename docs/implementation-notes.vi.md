# Ghi chú triển khai và ranh giới xác minh

> 🌐 Language / Ngôn ngữ: [English](implementation-notes.md) | **Tiếng Việt**

Repository có mã nguồn cho các luồng quản trị/thành viên. CI đã chạy migrations PostgreSQL/pgvector, Ruby tests, system tests, Brakeman, RuboCop và Tailwind; không có bằng chứng chạy Modal GPU, R2 và SMTP live.

1. **Dependency lock:** `Gemfile.lock` đã được tạo từ Ruby 3.3 và đưa vào repository để khóa dependency. CI dùng Bundler theo lockfile; cần rà soát bảo mật trước khi nâng phiên bản.
2. **Dataset:** importer yêu cầu metadata.csv và 935 PNG với SHA256, đúng 120 Core + 67 Additional × 5 slot. Kiểm tra hash không xác nhận tính nhất quán sinh trắc học.
3. **R2:** phải cấp hai bucket private, kiểm tra upload/read/delete, TTL và backup.
4. **Modal:** phải xác nhận revision, preprocessing, dimension và config_sha256 từ endpoint; token chỉ ở server; hostname trong allowlist.
5. **Background jobs:** cần kiểm tra lịch chạy Solid Queue, retry, lease và giới hạn chi phí trên môi trường thực.
6. **Chất lượng/đạo đức:** benchmark độc lập tạo căn cứ hiệu chuẩn; phê duyệt policy trong Rails chỉ là thao tác admin, không tự xác thực khoa học.
7. **Bảo mật:** cần rà soát session, rate-limit phân tán, CSRF, xóa file R2, lưu trữ audit và consent.
8. **Kiểm thử:** CI pass không đồng nghĩa hoàn thành toàn bộ nghiệm thu production. Ghi mã commit và kết quả dịch vụ thực khi công bố.
