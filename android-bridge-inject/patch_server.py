#!/usr/bin/env python3
"""
NRO APK patch v1.5.0
- CHỈ patch text config files (JSON, XML, txt...) - SKIP binary files
- global-metadata.dat: safe in-place binary replace (giữ nguyên file size)
- KHÔNG bao giờ open Unity binary bằng text mode (data.unity3d, .dll, .dat)
- KHÔNG inject smali (Unity IL2CPP, logic không nằm trong Java smali)

Root cause v1.4.0 crash:
  data.unity3d + global-metadata.dat bị open text mode → regex replace ngẫu nhiên
  → Unity engine không đọc được asset → crash loop → lag máy
"""
import os, re, sys

SMALI_DIR  = sys.argv[1] if len(sys.argv) > 1 else "/tmp/game_src/smali"
ASSETS_DIR = sys.argv[2] if len(sys.argv) > 2 else "/tmp/game_src/assets"

TARGET_IP   = "127.0.0.1"
TARGET_PORT = 14445

# Chỉ patch đúng các extension text thuần
TEXT_EXTS = {'.json', '.txt', '.xml', '.properties', '.cfg', '.ini',
             '.yaml', '.yml', '.conf', '.csv', '.plist', '.proto'}

# Các IP server cũ cần replace trong global-metadata.dat (binary in-place)
# Thứ tự: dài trước ngắn sau để tránh partial match
KNOWN_SERVER_IPS = [
    b"147.185.221.211",   # playit.gg NRO
    b"23.95.31.196",      # bore.pub cũ
    b"14.225.213.148",    # Hà Nội server
    b"fw.patus.tech",     # patus server domain
    b"nrolight.net",      # nrolight domain
]

# Các port cần replace trong text files
OTHER_PORTS_INT = [14449, 21445, 14446, 14447, 14448, 14450, 5798]

changed_text = []
changed_meta = 0


def is_binary(path):
    """True nếu file chứa null bytes → binary, không được text-patch."""
    try:
        with open(path, 'rb') as f:
            return b'\x00' in f.read(4096)
    except Exception:
        return True


# ─────────────────────────────────────────────────────────────────
# 1. Patch text config files trong assets — SKIP binary hoàn toàn
# ─────────────────────────────────────────────────────────────────
if os.path.exists(ASSETS_DIR):
    for root, _, files in os.walk(ASSETS_DIR):
        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in TEXT_EXTS:
                continue          # bỏ qua mọi file không phải text config
            fp = os.path.join(root, fname)
            if is_binary(fp):
                continue          # double-check: bỏ qua binary
            try:
                with open(fp, 'r', encoding='utf-8') as fh:
                    text = fh.read()
            except UnicodeDecodeError:
                continue          # không phải UTF-8 → skip
            orig = text
            # Thay IP server (giữ nguyên 127.0.0.1)
            text = re.sub(
                r'\b(?!127\.0\.0\.1\b)(?:\d{1,3}\.){3}\d{1,3}\b',
                TARGET_IP, text)
            # Thay port
            for p in OTHER_PORTS_INT:
                text = text.replace(f':{p}', f':{TARGET_PORT}')
                text = text.replace(f'"{p}"', f'"{TARGET_PORT}"')
            if text != orig:
                with open(fp, 'w', encoding='utf-8') as fh:
                    fh.write(text)
                changed_text.append(os.path.relpath(fp, ASSETS_DIR))
                print(f"  [text] {changed_text[-1]}")

# ─────────────────────────────────────────────────────────────────
# 2. global-metadata.dat: safe BINARY in-place patch
#    Mở bằng rb/wb — giữ nguyên file size — replace bytes trực tiếp
# ─────────────────────────────────────────────────────────────────
meta_path = None
for root, _, files in os.walk(ASSETS_DIR):
    for f in files:
        if f == 'global-metadata.dat':
            meta_path = os.path.join(root, f)
            break
    if meta_path:
        break

if meta_path:
    with open(meta_path, 'rb') as f:
        data = bytearray(f.read())

    orig_size = len(data)
    TARGET_B  = TARGET_IP.encode('ascii')

    print(f"\n[meta] Scanning {os.path.basename(meta_path)} ({orig_size:,} bytes)...")

    # --- Debug: in các server URL/IP tìm thấy ---
    url_re = re.compile(rb'https?://[a-zA-Z0-9._/:%?&=\-]{8,200}')
    for m in url_re.finditer(bytes(data)):
        url = m.group().decode('ascii', errors='replace')
        if any(k in url.lower() for k in ['nro', 'server', 'patus', 'nrolight', 'dragonboy', 'game']):
            print(f"  [URL found] offset={m.start()}: {url[:120]}")

    for kw in KNOWN_SERVER_IPS:
        pos = bytes(data).find(kw)
        if pos != -1:
            ctx = bytes(data[max(0, pos-20):pos+len(kw)+20])
            ctx_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in ctx)
            print(f"  [IP found] '{kw.decode()}' at offset={pos}  ctx='{ctx_str}'")

    # --- In-place binary replacement ---
    for search_b in KNOWN_SERVER_IPS:
        start = 0
        while True:
            idx = bytes(data).find(search_b, start)
            if idx == -1:
                break
            old_len = len(search_b)
            new_len = len(TARGET_B)
            if new_len > old_len:
                print(f"  [SKIP] '{search_b.decode()}': replacement longer, skipping")
                start = idx + 1
                continue
            # Đặt bytes mới vào đúng vị trí, null-pad phần dôi dư
            replacement = TARGET_B + b'\x00' * (old_len - new_len)
            for i, byte in enumerate(replacement):
                data[idx + i] = byte
            print(f"  [meta-patch] '{search_b.decode()}' → '{TARGET_B.decode()}'"
                  f" (pad={old_len - new_len} nulls) at offset={idx}")
            changed_meta += 1
            start = idx + 1  # tìm tiếp occurrence khác

    assert len(data) == orig_size, "BUG: file size thay đổi sau patch!"

    if changed_meta > 0:
        with open(meta_path, 'wb') as f:
            f.write(bytes(data))
        print(f"  [meta] Saved — {changed_meta} occurrence(s) patched, size unchanged")
    else:
        print(f"  [meta] No known server IPs found (may already be 127.0.0.1 or obfuscated)")

else:
    print("[meta] global-metadata.dat not found in assets — skip")

# ─────────────────────────────────────────────────────────────────
# 3. Smali: KHÔNG patch gì cả
#    Game là Unity IL2CPP — toàn bộ logic trong C# compiled → meta
#    Các smali file là Unity wrapper Java (không có TCP socket)
# ─────────────────────────────────────────────────────────────────
print(f"\n[smali] Skip — Unity IL2CPP game, logic không nằm trong Java smali")

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────
print(f"\n{'='*55}")
print(f"Text config patched : {len(changed_text)} files")
print(f"Meta binary patched : {changed_meta} IP occurrences")
print(f"Binary files        : KHÔNG đụng (an toàn)")
print(f"Target IP           : {TARGET_IP}")
print(f"Target port         : {TARGET_PORT}")
print(f"{'='*55}")
