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

## Giải nén RAR sau khi tải

`unrar` và `7z` cài qua `nix-env` đều **segfault** trong Replit. Phải dùng `nix-shell`:

```bash
# List nội dung
nix-shell -p unrar --run "unrar l /tmp/file.rar 2>&1 | head -60"

# Giải nén
nix-shell -p unrar --run "unrar x -y /tmp/file.rar /tmp/output/ 2>&1 | tail -5"

# Nhiều file song song (mỗi lệnh chạy nền)
nix-shell -p unrar --run "unrar x -y /tmp/a.rar /tmp/out_a/" &
nix-shell -p unrar --run "unrar x -y /tmp/b.rar /tmp/out_b/" &
wait
```

**Why:** `nix-env -iA nixpkgs.unrar` cài được nhưng binary bị segfault do incompatible glibc. `nix-shell -p unrar` dùng isolated environment chạy đúng.

## KHÔNG dùng

- `https://drive.google.com/uc?export=download&id=...` → trả HTML virus warning
- `gdown` → pip install bị chặn trong môi trường Replit
- `wget` → cũng bị virus warning
- `nix-env -iA nixpkgs.unrar` rồi gọi thẳng `unrar` → segfault

## Đã tải thành công (2026-07-18)

| File ID | Tên file | Size |
|---|---|---|
| `1X9vHWR-3fbXv8iPutoSaFwgolo57_bE1` | ZIP chứa 4 RAR bên dưới | 1.5GB |

### Nội dung bên trong ZIP (4 RAR):
| RAR | Nội dung | Size gốc |
|---|---|---|
| `SRC-Team.rar` | Java server source + nro.sql + mob data | 428MB |
| `Teamobi2026.rar` | Teamobi2026 Java server (SRC/20.jar + .class) | 629MB |
| `PRJ_2Tab_550K.rar` | Unity client (assets x2/x3/x4, nhạc, font) | 332MB |
| `HUNR_Client.rar` | Unity client HUNR (C#, Visual Studio project) | 92MB |

## GitHub Repo tổng hợp tài nguyên

**Repo:** `akah3674-glitch/nro-assets` (private)
**Remote trong workspace:** `git remote add nro-assets https://TOKEN@github.com/akah3674-glitch/nro-assets.git`
**Push:** `git push nro-assets nro-main:main`

### Cấu trúc repo nro-assets:
```
icons/x1-x4/        ← 64,315 icon files (item/skill/UI) — Teamobi2026
effects/x1-x4/      ← effect sprites — Teamobi2026 + SRC-Team
mob/x1-x4/          ← mob sprites — Teamobi mob.rar (nested RAR)
img_by_name/x1-x4/  ← images by name — Teamobi2026 + SRC-Team
item_bg/x1-x4/      ← item background frames — Teamobi2026
map/                ← map tiles, bg, eff — SRC-Team
data_img_version/x1-x4/ ← versioned game images — SRC-Team
client/prj/         ← Unity PRJ_2Tab_550K Assets/Resources/res/ (426 PNG)
client/hunr/        ← Unity HUNR_Client Assets/ (785 files)
src/SRC-Team/       ← Java source 434 files + nro.sql
src/Teamobi2026/    ← Java source 548 files
```

**Note:** Worktree tại `/tmp/nro-wt` dùng `git -C /home/runner/workspace` push. Cần tạo lại worktree mỗi session nếu /tmp bị xóa:
```bash
cd /home/runner/workspace
git worktree add /tmp/nro-wt nro-assets/main
```
