---
name: Working Preferences
description: Quy tắc làm việc do người dùng yêu cầu — áp dụng cho mọi phiên
---

# Quy tắc làm việc

**Why:** Người dùng thiết lập để tiết kiệm token, tránh mất tiến trình, duy trì codebase gọn gàng.

## 1. Lưu tiến trình cuối phiên
Trước khi kết thúc mỗi phiên, cập nhật MEMORY.md + topic file liên quan: phần nào xong, phần nào dở, bước tiếp theo.

## 2. Đánh dấu phần đã hoàn thành — KHÔNG ĐỘNG VÀO NỮA
- Ghi nhận vào memory khi module/tính năng xong.
- Không động vào code đã hoàn thành trừ khi có bug hoặc yêu cầu rõ ràng.
- Sửa xong phần nào → tách biệt ra, đánh dấu ✅, không ghi đè lại.

## 3. Tiết kiệm token — ưu tiên cao
- Batch tool call độc lập vào cùng một response.
- Dùng grep/search trước để định vị chính xác, chỉ đọc file khi cần.
- Token ≤ 20% → chế độ cực tiết kiệm: câu ngắn, không giải thích dài, tool call song song.

## 4. Tổ chức gọn gàng — sai đâu sửa đó
- Không viết lại từ đầu; tìm đúng dòng, sửa đúng chỗ.
- Chia file chi tiết → dễ định vị lần sau.

## 5. Đồng bộ GitHub trước, Codespace sau
- Luôn commit + push lên repo chính (akah3674-glitch/rem5) trước.
- Token GitHub lưu trong Replit Secret `GITHUB_PERSONAL_ACCESS_TOKEN` — KHÔNG lưu plaintext vào memory.
- Nếu GitHub push bị block secret scanning: `GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" git push github main`

## 6. Tự deploy lên Codespace — KHÔNG hỏi user
- Sau khi sửa file trên Replit, TỰ upload + deploy lên Codespace ngay trong cùng phiên.
- Workflow chuẩn:
  1. Sửa file trên Replit
  2. `cat file | gh codespace ssh -c "<name>" -- "cat > ~/remote_path"` để upload
  3. Compile/JAR update/restart nếu là Java; hoặc chỉ copy script nếu là bash
  4. Kiểm tra kết quả trực tiếp bằng SSH (pgrep, tail log, mysql query)
  5. Push GitHub
- Chỉ báo cáo kết quả sau khi xong. Không giao việc lại cho user.

## 7. Quy trình SSH vào Codespace
```bash
GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh -c "cautious-space-halibut-p7rwgqwxrg5gfrrqg" -- bash << 'REMOTE'
# commands here
REMOTE
```
- Codespace name: `cautious-space-halibut-p7rwgqwxrg5gfrrqg`
- Source Java: `/home/codespace/nro/SRC/src/`
- JAR: `/home/codespace/nro/SRC/NgocRongOnline.jar`
- Logs: `~/logs/server.log`, `~/logs/frp.log`
- DB: `mysql -u root nro1`

## 8. Kiểm tra lỗi ngay trên Codespace
Sau mỗi thay đổi, SSH vào check:
- `pgrep -f NgocRongOnline` — Java còn sống không
- `pgrep -f frpc` — tunnel còn sống không
- `tail -10 ~/logs/server.log` — lỗi runtime
- `mysql -u root nro1 -se "..."` — verify DB

**How to apply:** Đọc file này đầu phiên. Cập nhật MEMORY.md trước khi kết thúc.
