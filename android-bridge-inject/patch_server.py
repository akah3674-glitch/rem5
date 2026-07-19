#!/usr/bin/env python3
"""
NRO APK patch v1.6.0 — Auto-connect
Chiến lược:
  1. Tìm ipString (hex XOR-encoded) trong global-metadata.dat
     → thay bằng "LocalHost:127.0.0.1:14445:0,0,0" đã encode → còn 1 server → game tự chọn
  2. Fallback: tìm "Blue 1:14.225.203.242" (server list dạng raw text)
     → thay bằng "LocalHost:127.0.0.1:14445:0,0,0" padded nulls
  3. Text config files: chỉ patch JSON/XML/txt (SKIP binary)

Root cause v1.4.0: open binary bằng text mode → corrupt → Unity crash loop → lag
v1.5.0: fix corruption, giữ binary nguyên
v1.6.0: thêm auto-connect bằng cách giảm server list xuống 1 entry
"""
import os, re, sys

SMALI_DIR  = sys.argv[1] if len(sys.argv) > 1 else "/tmp/game_src/smali"
ASSETS_DIR = sys.argv[2] if len(sys.argv) > 2 else "/tmp/game_src/assets"

TARGET_IP        = "127.0.0.1"
TARGET_PORT      = 14445
TARGET_SERVER    = "LocalHost:127.0.0.1:14445:0,0,0"   # single-entry → auto-connect
XOR_KEY          = "69"                                  # ModFunc.DecodeByteArrayString key

# ipString gốc (4 Blue servers) — 8 byte đầu để nhận diện
ORIG_IPSTRING_START = b"74-55-43-5C-16-08-0C-08"

# Text config extensions — chỉ các file này được patch text
TEXT_EXTS = {'.json','.txt','.xml','.properties','.cfg',
             '.ini','.yaml','.yml','.conf','.csv','.plist','.proto'}

OTHER_PORTS_INT = [14449, 21445, 14446, 14447, 14448, 14450, 5798]

changed_text = []
changed_meta = 0


# ──────────────────────────────────────────────────────────────────
# Helper: XOR encode/decode (giống hệt ModFunc.cs)
# ──────────────────────────────────────────────────────────────────
def xor_encode(plaintext: str, key: str = XOR_KEY) -> bytes:
    key_b  = key.encode('utf-8')
    plain_b = plaintext.encode('utf-8')
    return bytes(b ^ key_b[i % len(key_b)] for i, b in enumerate(plain_b))

def to_ipstring(plaintext: str) -> bytes:
    """Encode như ModFunc.EncodeStringToByteArrayString — trả về bytes ASCII của hex string"""
    raw = xor_encode(plaintext)
    return ('-'.join(f'{b:02X}' for b in raw)).encode('ascii')

def is_binary(path):
    try:
        with open(path, 'rb') as f:
            return b'\x00' in f.read(4096)
    except Exception:
        return True


# ──────────────────────────────────────────────────────────────────
# 1. Text config files — SKIP binary hoàn toàn
# ──────────────────────────────────────────────────────────────────
if os.path.exists(ASSETS_DIR):
    for root, _, files in os.walk(ASSETS_DIR):
        for fname in files:
            ext = os.path.splitext(fname)[1].lower()
            if ext not in TEXT_EXTS:
                continue
            fp = os.path.join(root, fname)
            if is_binary(fp):
                continue
            try:
                with open(fp, 'r', encoding='utf-8') as fh:
                    text = fh.read()
            except UnicodeDecodeError:
                continue
            orig = text
            text = re.sub(
                r'\b(?!127\.0\.0\.1\b)(?:\d{1,3}\.){3}\d{1,3}\b',
                TARGET_IP, text)
            for p in OTHER_PORTS_INT:
                text = text.replace(f':{p}', f':{TARGET_PORT}')
                text = text.replace(f'"{p}"', f'"{TARGET_PORT}"')
            if text != orig:
                with open(fp, 'w', encoding='utf-8') as fh:
                    fh.write(text)
                changed_text.append(os.path.relpath(fp, ASSETS_DIR))
                print(f"  [text] {changed_text[-1]}")


# ──────────────────────────────────────────────────────────────────
# 2. global-metadata.dat — safe binary in-place patch
# ──────────────────────────────────────────────────────────────────
meta_path = None
for root, _, files in os.walk(ASSETS_DIR):
    for f in files:
        if f == 'global-metadata.dat':
            meta_path = os.path.join(root, f)
            break
    if meta_path:
        break

if not meta_path:
    print("[meta] Không tìm thấy global-metadata.dat — skip")
else:
    with open(meta_path, 'rb') as f:
        data = bytearray(f.read())

    orig_size = len(data)
    print(f"\n[meta] {os.path.basename(meta_path)} — {orig_size:,} bytes")

    # ── Chuẩn bị replacement ──────────────────────────────────────
    # New ipString: XOR-encode single-server string
    NEW_IPSTRING_B = to_ipstring(TARGET_SERVER)
    print(f"  Target server : '{TARGET_SERVER}'")
    print(f"  Encoded ipStr : {NEW_IPSTRING_B[:30].decode()}... ({len(NEW_IPSTRING_B)} bytes)")

    # Verify decode: XOR lại phải ra TARGET_SERVER
    raw = xor_encode(TARGET_SERVER)
    rebuilt = ('-'.join(f'{b:02X}' for b in raw)).encode('ascii')
    decoded_check = bytes(b ^ XOR_KEY.encode()[i % len(XOR_KEY)] for i, b in enumerate(raw))
    assert decoded_check.decode('utf-8') == TARGET_SERVER, "BUG: XOR encode/decode không khớp!"

    # ── Chiến lược A: tìm ipString gốc (hex XOR format) ──────────
    idx = bytes(data).find(ORIG_IPSTRING_START)
    if idx != -1:
        # Tìm hết chuỗi hex này (đến null byte hoặc ký tự không phải hex/dash)
        end = idx
        while end < len(data) and data[end] != 0x00:
            # hex string chỉ gồm [0-9A-F-] (uppercase)
            if data[end] not in b'0123456789ABCDEF-':
                break
            end += 1
        old_len = end - idx
        print(f"  [A] Tìm thấy ipString tại offset={idx}, length={old_len}")
        print(f"      Nội dung: {bytes(data[idx:idx+40]).decode('ascii', errors='?')}...")

        if len(NEW_IPSTRING_B) <= old_len:
            replacement = NEW_IPSTRING_B + b'\x00' * (old_len - len(NEW_IPSTRING_B))
            for i, b in enumerate(replacement):
                data[idx + i] = b
            changed_meta += 1
            print(f"  [A] ✅ Patched ipString ({old_len} → {len(NEW_IPSTRING_B)} bytes + "
                  f"{old_len - len(NEW_IPSTRING_B)} null pad)")
        else:
            print(f"  [A] ⚠️ New ipString ({len(NEW_IPSTRING_B)}) dài hơn old ({old_len}) — skip A")

    else:
        print(f"  [A] ipString gốc không tìm thấy")

    # ── Chiến lược B: tìm "Blue 1:14.225.203.242" (raw text) ─────
    if changed_meta == 0:
        BLUE_START = b"Blue 1:14.225.203.242"
        idx2 = bytes(data).find(BLUE_START)
        if idx2 != -1:
            # Tìm hết server list string (đến null byte)
            end2 = idx2
            while end2 < len(data) and data[end2] != 0x00:
                end2 += 1
            old_len2 = end2 - idx2
            old_str = bytes(data[idx2:end2]).decode('utf-8', errors='?')
            print(f"  [B] Tìm thấy server list tại offset={idx2}: '{old_str[:60]}...'")
            print(f"      Length: {old_len2}")

            TARGET_B = TARGET_SERVER.encode('utf-8')
            if len(TARGET_B) <= old_len2:
                replacement2 = TARGET_B + b'\x00' * (old_len2 - len(TARGET_B))
                for i, b in enumerate(replacement2):
                    data[idx2 + i] = b
                changed_meta += 1
                print(f"  [B] ✅ Patched server list → '{TARGET_SERVER}' + null pad")
            else:
                print(f"  [B] ⚠️ Target string dài hơn source — không thể in-place replace")
        else:
            print(f"  [B] Raw server list không tìm thấy")

    # ── Chiến lược C: tìm "LocalHost:127.0.0.1:14445" (mod đã apply) ─
    if changed_meta == 0:
        LOCAL_B = b"LocalHost:127.0.0.1:14445"
        idx3 = bytes(data).find(LOCAL_B)
        if idx3 != -1:
            print(f"  [C] ✅ APK đã có 'LocalHost:127.0.0.1:14445' tại offset={idx3}")
            print(f"      Auto-connect sẽ hoạt động sau khi Clear Data + cài lại")
            # Không cần patch gì thêm
        else:
            print(f"  [C] ⚠️ Không tìm thấy bất kỳ server string nào — có thể obfuscated")

    # ── Kiểm tra file size không đổi ─────────────────────────────
    assert len(data) == orig_size, f"BUG: file size thay đổi! {len(data)} ≠ {orig_size}"

    if changed_meta > 0:
        with open(meta_path, 'wb') as f:
            f.write(bytes(data))
        print(f"  [meta] Saved — size unchanged ({orig_size:,} bytes) ✅")
    else:
        print(f"  [meta] Không cần patch (hoặc không tìm được string để patch)")


# ──────────────────────────────────────────────────────────────────
# 3. Smali: KHÔNG patch (Unity IL2CPP, không có socket trong Java)
# ──────────────────────────────────────────────────────────────────
print(f"\n[smali] Skip — Unity IL2CPP game, TCP logic nằm trong C# (IL2CPP), không có trong Java smali")


# ──────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────
print(f"\n{'='*55}")
print(f"Text config patched : {len(changed_text)} files")
print(f"Meta binary patched : {changed_meta} location(s)")
print(f"Binary files        : KHÔNG đụng")
print(f"Auto-connect        : {'✅ server list → 1 entry' if changed_meta > 0 else 'xem log [C] ở trên'}")
print(f"Target              : {TARGET_SERVER}")
print(f"{'='*55}")
