# Source, model and dataset licenses

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](model-data-licenses.vi.md)

## Source code
The Rails application uses [MIT](../LICENSE): Copyright (c) 2026 Đăng Khoa <i.am@dangkhoa.dev>.

## Dataset
CompactFaces is a separately distributed **synthetic-face** dataset. Repository MIT does **not** relicense its images. Verify the canonical license for the exact dataset revision and its provenance restrictions at the [dataset source](https://huggingface.co/datasets/dangkhoa2016/compactfaces-synthetic-face-dataset) before download, mirroring, publication, or commercial usage. Attribution is required.

## External models
Model weights are **not** included. Rails only calls a separately deployed embedding service. Both upstream model cards currently list Apache License 2.0 (recheck the deployed revision); third-party components may have separate terms:
- [Qwen3-VL-Embedding-8B](https://huggingface.co/Qwen/Qwen3-VL-Embedding-8B)
- [Tencent WeMM-Embedding-9B](https://huggingface.co/tencent/WeMM-Embedding-9B)

Verify the license/model card of the **exact pinned revision**; MIT for this repository grants no rights to weights or third-party images.

## Use limitations
A synthetic-data cosine benchmark cannot prove real-world biometric reliability, fairness or legality. Require independent calibration, consent, privacy protections and legal review before consequential use.
