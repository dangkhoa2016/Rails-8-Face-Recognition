# Kiến trúc và phạm vi chức năng

> 🌐 Language / Ngôn ngữ: [English](architecture.md) | **Tiếng Việt**

```text
Trình duyệt (Tailwind / ERB / Turbo / Stimulus)
  -> Rails 8 + Devise/Warden + phân quyền admin/member
      -> PostgreSQL + pgvector (chỉ Core SOURCE làm enrollment)
      -> Active Storage -> hai bucket R2 riêng tư
      -> Solid Queue (preflight, tạo vector thiếu, nhận diện, import, dọn dẹp)
          -> API embedding Modal có Bearer authentication (Qwen/WeMM)
```

## Thành phần đã triển khai
- Public: trang chủ, giới thiệu, quyền riêng tư, điều khoản, đăng nhập.
- Thành viên: gallery, ảnh mẫu, upload riêng tư, xóa, yêu cầu nhận diện, trạng thái và lịch sử.
- Quản trị: dashboard, import bộ dữ liệu, định danh/ảnh, dịch vụ/model, embedding profile bất biến, recognition policy, unknown tests và audit log.
- Services: kiểm tra ảnh/manifest, trả private blob theo quyền, gọi API giới hạn hostname, kiểm tra phản hồi, preflight và chỉ tạo vector thiếu.
- Background: Solid Queue cùng lịch dọn dữ liệu; hành vi mạng thật cần nghiệm thu trên môi trường triển khai.

## Tái sử dụng profile
Tổ hợp model + revision + dimension + preprocessing + instruction có fingerprint xác định. Mỗi ảnh/profile lưu một vector duy nhất. Nếu quay lại profile cũ đã đầy đủ vector, không xóa hay gọi inference mới. Database có unique indexes và trigger chống thay đổi trái phép.

## Cô lập kết quả đánh giá
Notebook benchmark độc lập nằm trong repository inference, không trong Rails. Admin chỉ nhập policy/ngưỡng đã xem xét, có tham chiếu và SHA báo cáo. Không quyết định Matched/Unknown nếu thiếu 120 SOURCE vectors và policy được phê duyệt. Cosine không phải phần trăm xác suất.

## Giới hạn xác minh
CI cung cấp kiểm thử Rails/PostgreSQL, Brakeman, RuboCop, browser và Tailwind. Điều này không thay thế kiểm thử 935 ảnh thật, R2, Modal, SMTP, chính sách quyền riêng tư và nghiệm thu production.
