# Rails 8 Face Recognition — Giao diện và vận hành

> 🌐 Language / Ngôn ngữ: [English](UI_UX_AND_OPERATIONS.md) | **Tiếng Việt**

Tài liệu này mô tả các **route/controller/view/job đã viết** cho ứng dụng Rails 8 Face Recognition. CI đã kiểm tra ứng dụng Rails/PostgreSQL/pgvector và Chrome headless. Tuy nhiên, đây **không phải** bằng chứng đã chạy Modal GPU, R2 hoặc SMTP thật; các dịch vụ ngoài cần nghiệm thu riêng.

## 1. Bản đồ giao diện và phân quyền

| Màn hình | URL | Quyền | Controller |
|---|---|---|---|
| Landing / giới thiệu | `/`, `/about`, `/privacy`, `/terms` | Public | `HomeController` |
| Đăng nhập/đăng xuất | `/sign_in`, `/session` | Public / session | `SessionsController` |
| Đăng ký/xác minh/quên mật khẩu | `/registration`, `/verify_email`, `/forgot_password`, `/reset_password` | Public | Account controllers |
| Danh sách mẫu | `/samples` | Member/Admin | `SamplesController` |
| Chi tiết mẫu | `/samples/:id` | Member/Admin | `SamplesController` |
| Ảnh private | `/private/images/:id` | Theo đối tượng | `FaceImagesController` |
| Ảnh cá nhân | `/submissions`, `/submissions/new`, `/submissions/:id` | Chủ sở hữu | `SubmissionsController` |
| Nhận diện + kết quả | `/recognition`, `/recognition/new`, `/recognition/:id` | Chủ request | `RecognitionAttemptsController` |
| Admin dashboard | `/admin` | Admin | `Admin::DashboardController` |
| Identity registry | `/admin/identities`, `/admin/identities/:id` | Admin | `Admin::IdentitiesController` |
| Registry ảnh | `/admin/face_images`, `/admin/face_images/:id` | Admin | `Admin::FaceImagesController` |
| Import dữ liệu | `/admin/dataset_imports/...` | Admin | `Admin::DatasetImportsController` |
| Inference services | `/admin/inference_services/...` | Admin | `Admin::InferenceServicesController` |
| Embedding models | `/admin/embedding_models/...` | Admin | `Admin::EmbeddingModelsController` |
| Profiles + thao tác | `/admin/embedding_profiles/...` | Admin | `Admin::EmbeddingProfilesController` |
| Policies + thao tác | `/admin/recognition_policies/...` | Admin | `Admin::RecognitionPoliciesController` |
| Unknown tests | `/admin/unknown_tests/...` | Admin | `Admin::UnknownTestsController` |
| Audit log | `/admin/audit_events` | Admin | `Admin::AuditEventsController` |

Các route có phương thức POST/PATCH/DELETE dùng form có CSRF. Bộ điều khiển Admin dùng `require_admin`. Trang private của người dùng không cho phép xem file người dùng khác ngay cả khi biết ID. Đăng ký member qua email được hỗ trợ nếu đã cấu hình mail service; tài khoản phải xác minh email trước đăng nhập. Session sử dụng Devise/Warden và rate limit PostgreSQL.

## 2. Quy ước UI/UX

- **Tailwind CSS 4**: dark navy/cyan, card thống kê, badge trạng thái, responsive grid, table có cuộn ngang, form label/hint/error, empty state và breadcrumb/back link.
- **Sidebar mobile**: Stimulus `navigation` cho mở/đóng, cập nhật `aria-expanded`, không chặn menu desktop. Có `skip to main content` và focus ring.
- **Turbo**: form submit và điều hướng. Trạng thái background đang pending/verifying/importing được tự refresh khi tab hiển thị.
- **Loading/ready/error**: thông báo rõ đã enqueue, chưa có data, không thể inference, hết hạn ảnh, nhập sai và service unavailable. Các nút kích hoạt hiển thị khi điều kiện hợp lệ; controller kiểm tra lại độc lập.
- **Ý nghĩa kết quả**: `Matched candidate`, `Unknown to this gallery`, `Indeterminate`, `Failed`, `Processing`. Có giải thích cosine similarity không phải xác suất; không công bố độ chính xác nếu thiếu benchmark độc lập.

## 3. Quy trình vận hành khuyến nghị

1. **Bootstrap**: Ruby, Bundler, Postgres/pgvector; thiết lập `DATABASE_URL` (theo môi trường), `ADMIN_EMAIL`, `ADMIN_PASSWORD`. `bundle install`, `db:prepare`, `db:seed`, `bin/dev` chạy web, Tailwind và Solid Queue.
2. **Dataset**: cấp phép tải CompactFaces, stage snapshot trong `DATASET_IMPORT_ROOT`. Admin đăng ký import và chạy Verify/Import; kiểm tra chính xác **935 PNG** / 120 Core / 67 Additional / 5 slot; metadata CSV + từng SHA-256 và kích thước 1024×1024. Không khẳng định consistency danh tính sinh trắc chỉ từ SHA.
3. **Storage**: ở production cấu hình R2 buckets riêng cho reference và submissions; xác minh credentials, quyền, lưu/truy xuất/xóa trước khi upload bởi thành viên.
4. **Inference service**: đặt hostname Modal chính xác vào `INFERENCE_ALLOWED_HOSTS`, bearer token trong server ENV; admin tạo service và check GET `/v1/models` với TLS. Không cho browser giữ token.
5. **Models**: tạo model Qwen/WeMM đúng API ID, dimension khả dụng và revision thực đã được xác nhận. WeMM không nhận custom instruction; Qwen có thể nhận instruction.
6. **Profile**: chọn model + dimension + revision + preprocessing + instruction. Hệ thống tạo profile mới hoặc lấy lại profile trùng chính xác. Chạy preflight 1 ảnh SOURCE, pin `config_sha256`; sau đó Generate Missing cho SOURCE chưa có vector.
7. **Policy**: chạy notebook benchmark trong repository inference (không nằm trong Rails), đăng ký ngưỡng + manifest + SHA-256 report; admin kiểm tra thủ công và approve. Khi 120/120 SOURCE của profile đều có vector, Activate để bật nhận diện.
8. **Member**: duyệt Sample Gallery hoặc upload ảnh pre-cropped hợp pháp. Job lưu vector theo profile và so cosine exact với 120 SOURCE. Member chỉ xem kết quả/lịch sử của mình; upload hết hạn trong 24 giờ hoặc xóa thủ công.
9. **Đổi dimension**: chỉ `Activate` một profile đủ coverage và approved policy. 1024D → 4096D → 1024D giữ toàn bộ 1024D cũ, không gọi Modal cho cache đã có.

### Thiết lập thư mục dataset (người quản trị máy chủ)

Trường Source URL trong Rails Admin **chỉ lưu nguồn gốc**; importer không tải dữ liệu từ URL đó. Người quản trị máy chủ phải tải snapshot CompactFaces được phép sử dụng về đúng máy/container chạy Rails, **bên ngoài repository Git**, rồi đặt đường dẫn thư mục tuyệt đối trong biến `DATASET_IMPORT_ROOT` cho cả Rails/Puma và Solid Queue.

```sh
hf download dangkhoa2016/compactfaces-synthetic-face-dataset --repo-type dataset --local-dir /content/krw-workspace/compactfaces-dataset
test -f /content/krw-workspace/compactfaces-dataset/data/train/metadata.csv
find /content/krw-workspace/compactfaces-dataset/data/train/images -type f -name '*.png' | wc -l
# Kết quả mong đợi: 935
```

Khi khởi động ứng dụng **và các background job**, truyền biến môi trường, ví dụ chạy từ thư mục Rails:

```sh
DATASET_IMPORT_ROOT=/content/krw-workspace/compactfaces-dataset bin/dev
```

Nếu Puma và Solid Queue chạy riêng, phải cấu hình biến này ở **cả hai** nơi rồi khởi động lại; `export` ở terminal khác không thay đổi tiến trình đã chạy. `.env.example` chỉ là file mẫu, Rails không tự nạp file này. Tải lại trang chi tiết Dataset Import để xem trạng thái đường dẫn và metadata, sau đó bấm **Verify and import**. Việc tìm thấy metadata mới là bước kiểm tra sơ bộ, **chưa** xác minh đủ 935 ảnh, SHA-256 hay tính nhất quán khuôn mặt. Metadata đã công bố gọi tập Additional là `ADDITIONAL_OPTIONAL`; importer ánh xạ giá trị này sang `additional` nội bộ khi kiểm tra.

Tuân thủ license riêng của dataset/model. Quy trình import chỉ đọc thư mục được người quản trị chỉ định và không gọi GPU inference.

## 4. Các service/job chính

| File | Chức năng |
|---|---|
| `DatasetImports::VerifiedSnapshot` | Validate manifest + ảnh, ghi reference data idempotently theo import |
| `Submissions::Create`, `ImageUploads::Validate` | Upload private có consent, giới hạn bytes/pixel, checksum và TTL |
| `Embeddings::Client` | HTTPS + hostname allowlist + IP/DNS checks, non-redirect, bearer, validate response metadata/vector |
| `EmbeddingProfiles::Create` | Deterministic profile key và reuse |
| `ProfilePreflightJob` | Xác minh config metadata bằng 1 SOURCE trước bulk |
| `Embeddings::Ensure` | Cached first, lease, kiểm tra hash/config, ghi vector immutable |
| `Embeddings::Schedule`, `EmbeddingGenerationJob` | Chỉ enqueue missing, tránh trùng request đang chạy |
| `Recognition::Decide`, `RecognizeFaceJob` | Exact cosine 120 SOURCE trong cùng profile, quyết định threshold/margin và trạng thái lỗi |
| `DatasetImportJob` | Xác minh/import nền; báo trạng thái thành công/thất bại |
| `Submissions::Purge`, `PurgeExpiredSubmissionsJob` | Xóa dữ liệu tạm và liên quan; schedule mỗi 15 phút (khi Solid Queue scheduler hoạt động) |

## 5. Môi trường & bảo mật

- `DATABASE_URL`: PostgreSQL có extension `vector`.
- `INFERENCE_ALLOWED_HOSTS`: bắt buộc khi gọi Modal, danh sách FQDN HTTPS được phép; không bao gồm scheme.
- `EMBEDDINGS_API_BEARER_TOKEN`: token server-side; bảng service chỉ lưu tên biến ENV, không lưu secret.
- `DATASET_IMPORT_ROOT`: thư mục snapshot **trên server**, không nhận đường dẫn tuỳ ý từ member.
- `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_REFERENCE_BUCKET`, `R2_SUBMISSIONS_BUCKET`: production storage private.
- `SECRET_KEY_BASE`: sử dụng secret manager ở production; không commit `.env`.
- Hạn chế tiết lộ: Active Storage default routes bị tắt; ảnh qua `FaceImagesController` xác minh quyền, trả `Cache-Control: private, no-store`. Log không được ghi ảnh/token/vector. Row-level/index/trigger kiểm tra bất biến profile và embeddings.

## 6. Kiểm thử CI và nghiệm thu dịch vụ ngoài

- [ ] `bundle install` tạo **Gemfile.lock**; build assets Tailwind CSS.
- [ ] `bin/rails db:prepare` thành công với PostgreSQL/pgvector; rollback migration kiểm tra.
- [x] `bin/rails test` và browser system tests chạy trong GitHub Actions (PostgreSQL/pgvector); tính đúng đắn nghiệp vụ live vẫn cần nghiệm thu.
- [x] GitHub Actions có RuboCop/Brakeman và regression tests, đã được xác nhận trên nhánh trước khi chuẩn hóa Devise.
- [x] Chrome headless kiểm tra luồng đăng ký/đăng nhập, ngôn ngữ, theme và menu mobile; screen reader và kiểm tra thiết bị thật vẫn cần bổ sung.
- [ ] Nhập **935 ảnh thật** và đối chiếu SHA-256; xác minh schema CSV/path với bản tải thực tế.
- [ ] R2 private upload/read/delete và lifecycle/purge; xác minh backup retention.
- [ ] Modal live smoke, pinned revisions/dimensions/config hashes, 401/422/429/503/retry/timeout, quota chi phí GPU.
- [ ] Review calibration notebook và policy độc lập; tránh công bố chỉ số nhận diện chưa kiểm chứng.
- [ ] Legal/privacy/accessibility/security review trước public.

**Định nghĩa hoàn thành của vòng giao diện này:** controller + view + route + lớp xử lý tương ứng đã viết cho tất cả màn hình yêu cầu trong handoff. **Không đồng nghĩa** toàn bộ hệ thống đã được kiểm thử tích hợp hoặc release-ready.
