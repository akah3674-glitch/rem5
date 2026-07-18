---
name: Google Drive Download Method
description: Cách tải file từ Google Drive trong môi trường Replit/server (không có browser)
---

# Tải File Google Drive — Không Cần Browser

**Why:** curl thông thường chỉ trả về HTML "Virus scan warning". Cần dùng `drive.usercontent.google.com` với `confirm=t`.

## Lệnh tải 1 file

```bash
curl -L -c /tmp/gc.txt -b /tmp/gc.txt \
  "https://drive.usercontent.google.com/download?id=<FILE_ID>&export=download&confirm=t" \
  -o /tmp/output.zip --max-time 270
```

- Thay `<FILE_ID>` bằng ID trong link Drive (phần sau `/d/` và trước `/view`)
- `--max-time 270` vì ShellExec timeout tối đa 300s
- `-c/-b /tmp/gc.txt` giữ cookie session

## Tải nhiều file song song

```bash
for IDX in "FILE_ID_1 out1.zip" "FILE_ID_2 out2.zip" "FILE_ID_3 out3.zip"; do
  ID=$(echo $IDX | cut -d' ' -f1)
  OUT=$(echo $IDX | cut -d' ' -f2)
  curl -sL -c /tmp/gc_${OUT}.txt -b /tmp/gc_${OUT}.txt \
    "https://drive.usercontent.google.com/download?id=${ID}&export=download&confirm=t" \
    -o /tmp/$OUT --max-time 270 &
done
wait
ls -lh /tmp/*.zip
```

**Lưu ý:** Mỗi file dùng cookie riêng (`gc_${OUT}.txt`) để tránh xung đột session.

## KHÔNG dùng

- `https://drive.google.com/uc?export=download&id=...` → trả HTML virus warning
- `gdown` → pip install bị chặn trong môi trường Replit
- `wget` → cũng bị virus warning

## Đã tải thành công (2026-07-18)

| File ID | Tên file | Size |
|---|---|---|
| `1X9vHWR-3fbXv8iPutoSaFwgolo57_bE1` | file1.zip (PRJ+HUNR+Teamobi+SRC) | 1.5GB |
| `1ENWegm_JR1E4kRYGgx1ypgeoIMbkn_aj` | file2.zip | 92MB |
| `1HlpW2Dg-Tt-UNSLlljC47LB_SrhYYII4` | file3.zip | 332MB |
| `1XxlILhBTyF-1uRK2NQ7BKAVRYuJ6qhmv` | file4.zip | 428MB |
