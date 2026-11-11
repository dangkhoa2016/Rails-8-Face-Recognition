# Khắc phục sự cố

> 🌐 Language / Ngôn ngữ: [English](troubleshooting.md) | **Tiếng Việt**

## Lỗi migration PostgreSQL
Kiểm tra DATABASE_URL, quyền database và extension vector. Thử migration trên database development có thể bỏ được; không xóa dữ liệu production chỉ để khắc phục lỗi.

## Devise không đăng nhập
Kiểm tra email đã xác minh và tài khoản đang hoạt động. Timeout phiên Devise và rate limit PostgreSQL là hai cơ chế riêng; HTTP 429 không có nghĩa sai mật khẩu. Phiên đã thu hồi phải tiếp tục bị từ chối.

## Không nhận email xác minh
Kiểm tra EMAIL_PROVIDER, sender đã xác thực, SMTP credentials, Solid Queue workers và log nhà cung cấp. Chế độ file development chỉ ghi tmp/mails, không gửi mail ra ngoài.

## Profile chưa đạt Ready
Xem coverage 120 SOURCE, revision/dimension/config hash đã pin, preflight và approved policy. Quay lại profile cũ phải tái sử dụng cache vector.

## Không upload ảnh được
Kiểm tra chữ ký file/MIME, giới hạn byte/pixel, consent, quyền lưu trữ private và TTL. Ảnh chỉ truy cập qua Rails route kiểm tra quyền, không qua link bucket công khai.

## CI xanh nhưng Modal lỗi
CI dùng mock/offline. Smoke test live có thẩm quyền phải kiểm tra HTTPS, DNS/IP allowlist, bearer key, revision, rate limit API và quota.

Với sự cố nhạy cảm, xem [Bảo mật](../.github/SECURITY.vi.md).
