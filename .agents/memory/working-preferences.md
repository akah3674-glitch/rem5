---
name: Working Preferences
description: Quy tắc làm việc do người dùng yêu cầu — áp dụng cho mọi phiên
---

# Quy tắc làm việc

**Why:** Người dùng thiết lập để tiết kiệm token, tránh mất tiến trình, duy trì codebase gọn gàng.

## 1. Lưu tiến trình cuối phiên
Trước khi kết thúc mỗi phiên, cập nhật MEMORY.md + topic file liên quan: phần nào xong, phần nào dở, bước tiếp theo.

## 2. Đánh dấu phần đã hoàn thành
Ghi nhận vào memory khi module/tính năng xong. Không động vào code đã hoàn thành trừ khi có bug hoặc yêu cầu rõ ràng.

## 3. Tiết kiệm token — ưu tiên cao
- Batch tool call độc lập vào cùng một response.
- Dùng grep/search trước để định vị chính xác, chỉ đọc file khi cần.
- Token ≤ 20% → chế độ cực tiết kiệm: câu ngắn, không giải thích dài, tool call song song.

## 4. Tổ chức gọn gàng — sai đâu sửa đó
- Không viết lại từ đầu; tìm đúng dòng, sửa đúng chỗ.
- Chia file chi tiết → dễ định vị lần sau.

## 5. Đồng bộ GitHub
- Luôn push lên repo chính (akah3674-glitch/rem5) trước.
- Token GitHub lưu trong Replit Secret `GITHUB_PERSONAL_ACCESS_TOKEN` — KHÔNG lưu plaintext vào memory.
- Codespace: `cautious-space-halibut-p7rwgqwxrg5gfrrqg` | Source: `/home/codespace/nro/SRC/`

**How to apply:** Đọc file này đầu phiên. Cập nhật MEMORY.md trước khi kết thúc.
