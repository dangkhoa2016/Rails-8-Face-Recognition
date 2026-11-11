# Giấy phép mã nguồn, mô hình và dữ liệu

> 🌐 Language / Ngôn ngữ: [English](model-data-licenses.md) | **Tiếng Việt**

## Mã nguồn
Ứng dụng Rails dùng [MIT](../LICENSE): Copyright (c) 2026 Đăng Khoa <i.am@dangkhoa.dev>.

## Bộ dữ liệu
CompactFaces là bộ ảnh khuôn mặt **tổng hợp** có giấy phép riêng. MIT cho repository **không** cấp lại giấy phép ảnh. Cần xác minh giấy phép chính thức của đúng dataset revision và nguồn gốc ở [nguồn dữ liệu](https://huggingface.co/datasets/dangkhoa2016/compactfaces-synthetic-face-dataset) trước khi tải, sao chép, công bố hoặc kinh doanh. Phải ghi nguồn.

## Mô hình ngoài
Repository **không** kèm model weights; Rails chỉ gọi API embedding bên ngoài. Cả hai model card hiện công bố Apache License 2.0 (cần kiểm tra lại ở revision triển khai); điều khoản cho thành phần bên thứ ba có thể khác:
- [Qwen3-VL-Embedding-8B](https://huggingface.co/Qwen/Qwen3-VL-Embedding-8B)
- [Tencent WeMM-Embedding-9B](https://huggingface.co/tencent/WeMM-Embedding-9B)

Kiểm tra license/model card của **revision chính xác đã pin**. MIT cho mã nguồn không cấp quyền sử dụng weights hoặc ảnh của bên thứ ba.

## Giới hạn sử dụng
Benchmark cosine trên ảnh tổng hợp không chứng minh độ tin cậy, tính công bằng hoặc hợp pháp của sinh trắc học thực. Cần hiệu chuẩn độc lập, consent, bảo mật và rà soát pháp lý trước khi áp dụng vào quyết định quan trọng.
