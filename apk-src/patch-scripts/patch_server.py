#!/usr/bin/env python3
"""
NRO APK patch v1.7.0 — Auto-connect (hỗ trợ cả IL2CPP và Mono)

Chiến lược:
  A. global-metadata.dat (IL2CPP): tìm ipString hex gốc → replace XOR-encoded localhost
  B. Assembly-CSharp.dll (Mono): tìm ipString UTF-16LE → replace encoded localhost (padded)
  C. Fallback: tìm "Blue 1:" raw text (bất kỳ file nào)
  Text config: chỉ patch JSON/XML/txt (SKIP binary)

Root cause v1.4.0: open binary bằng text mode → corrupt → Unity crash loop → lag
v1.5.0: fix corruption  |  v1.6.0: thêm IL2CPP patch  |  v1.7.0: thêm Mono/DLL patch
"""
import os, re, sys

SMALI_DIR  = sys.argv[1] if len(sys.argv) > 1 else "/tmp/game_src/smali"
ASSETS_DIR = sys.argv[2] if len(sys.argv) > 2 else "/tmp/game_src/assets"

TARGET_SERVER = "LocalHost:127.0.0.1:14445:0,0,0"   # 1 server → auto-connect
XOR_KEY       = "69"

# ipString gốc (hex-encoded, 8 byte đầu để nhận diện)
ORIG_IPSTRING_HEX_START = b"74-55-43-5C-16-08-0C-08"

TEXT_EXTS = {'.json','.txt','.xml','.properties','.cfg',
             '.ini','.yaml','.yml','.conf','.csv','.plist','.proto'}
OTHER_PORTS_INT = [14449, 21445, 14446, 14447, 14448, 14450, 5798]

changed_text = 0
changed_meta = 0
changed_dll  = 0


# ─────────────────────────────────────────────────────────────────
# XOR helpers (identical to ModFunc.cs logic)
# ─────────────────────────────────────────────────────────────────
def xor_encrypt(plaintext: str, key: str = XOR_KEY) -> bytes:
    kb = key.encode('utf-8')
    pb = plaintext.encode('utf-8')
    return bytes(b ^ kb[i % len(kb)] for i, b in enumerate(pb))

def to_ipstring_bytes(plaintext: str) -> bytes:
    """→ ASCII bytes của XOR-encoded hex string (vd: b'7A-56-55-...')"""
    raw = xor_encrypt(plaintext)
    return ('-'.join(f'{b:02X}' for b in raw)).encode('ascii')

# Verify encode/decode
_raw = xor_encrypt(TARGET_SERVER)
_rebuilt = ('-'.join(f'{b:02X}' for b in _raw)).encode('ascii')
_kbytes = XOR_KEY.encode('utf-8')
_decoded = bytes(b ^ _kbytes[i % len(_kbytes)] for i, b in enumerate(_raw)).decode('utf-8')
assert _decoded == TARGET_SERVER, "BUG: XOR encode/decode mismatch"

NEW_IPSTRING_BYTES = to_ipstring_bytes(TARGET_SERVER)   # 32 chars → 95 ASCII bytes
print(f"[init] Target      : {TARGET_SERVER}")
print(f"[init] Encoded str : {NEW_IPSTRING_BYTES.decode()}")
print(f"[init] Encoded len : {len(NEW_IPSTRING_BYTES)} bytes (old ipString ~365 bytes)")

def is_binary(path):
    try:
        with open(path, 'rb') as f:
            return b'\x00' in f.read(4096)
    except:
        return True

def inplace_replace(data: bytearray, start: int, old_len: int, new_bytes: bytes,
                    pad_byte: bytes = b' ') -> bool:
    """Replace old_len bytes at `start` with new_bytes, padding the rest.
       pad_byte: 1 byte for binary padding OR b'  ' (2 bytes) for UTF-16LE space."""
    if len(new_bytes) > old_len:
        return False
    pad_needed = old_len - len(new_bytes)
    if len(pad_byte) == 2:  # UTF-16LE padding
        full_pads = pad_needed // 2
        extra    = pad_needed % 2
        replacement = new_bytes + pad_byte * full_pads + (b'\x00' if extra else b'')
    else:
        replacement = new_bytes + pad_byte * pad_needed
    assert len(replacement) == old_len, f"BUG padding: {len(replacement)} ≠ {old_len}"
    for i, b in enumerate(replacement):
        data[start + i] = b
    return True


# ═════════════════════════════════════════════════════════════════
# 1. TEXT CONFIG FILES — chỉ patch extension text
# ═════════════════════════════════════════════════════════════════
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
            text = re.sub(r'\b(?!127\.0\.0\.1\b)(?:\d{1,3}\.){3}\d{1,3}\b', "127.0.0.1", text)
            for p in OTHER_PORTS_INT:
                text = text.replace(f':{p}', f':{14445}')
                text = text.replace(f'"{p}"', f'"{14445}"')
            if text != orig:
                with open(fp, 'w', encoding='utf-8') as fh:
                    fh.write(text)
                changed_text += 1
                print(f"  [text] {os.path.relpath(fp, ASSETS_DIR)}")


# ═════════════════════════════════════════════════════════════════
# Tìm tất cả file binary cần xét
# ═════════════════════════════════════════════════════════════════
meta_path = None
dll_paths = []

for root, dirs, files in os.walk(ASSETS_DIR):
    for f in files:
        fp = os.path.join(root, f)
        if f == 'global-metadata.dat':
            meta_path = fp
        elif f.endswith('.dll') and 'Assembly-CSharp' in f:
            dll_paths.append(fp)


# ═════════════════════════════════════════════════════════════════
# 2. global-metadata.dat (IL2CPP) — safe binary in-place patch
# ═════════════════════════════════════════════════════════════════
print(f"\n{'─'*55}")
print(f"[IL2CPP] global-metadata.dat")
if not meta_path:
    print("  → Không tìm thấy")
else:
    with open(meta_path, 'rb') as f:
        data = bytearray(f.read())
    orig_size = len(data)
    print(f"  Path : {os.path.relpath(meta_path, ASSETS_DIR)}")
    print(f"  Size : {orig_size:,} bytes")

    raw = bytes(data)

    # Strategy A1: tìm ipString gốc (hex format)
    idx = raw.find(ORIG_IPSTRING_HEX_START)
    if idx != -1:
        end = idx
        while end < len(raw) and raw[end] != 0 and raw[end] in b'0123456789ABCDEF-':
            end += 1
        old_len = end - idx
        print(f"  [A1] Found ipString at offset={idx}, len={old_len}")
        if inplace_replace(data, idx, old_len, NEW_IPSTRING_BYTES, b' '):
            changed_meta += 1
            print(f"  [A1] ✅ Patched (pad_byte=space)")
        else:
            print(f"  [A1] ⚠️ New string longer — skip")
    else:
        # Strategy A2: tìm "Blue 1:14.225.203.242" raw text
        BLUE_B = b"Blue 1:14.225.203.242"
        idx2 = raw.find(BLUE_B)
        if idx2 != -1:
            end2 = idx2
            while end2 < len(raw) and raw[end2] != 0:
                end2 += 1
            old_str = raw[idx2:end2].decode('utf-8', errors='?')
            old_len2 = end2 - idx2
            print(f"  [A2] Found raw server list at offset={idx2}: '{old_str[:50]}...'")
            new_b = TARGET_SERVER.encode('utf-8')
            if inplace_replace(data, idx2, old_len2, new_b, b' '):
                changed_meta += 1
                print(f"  [A2] ✅ Patched raw list → single server (pad=space)")
            else:
                print(f"  [A2] ⚠️ Cannot replace — target longer")
        else:
            # A3: kiểm tra đã có localhost chưa
            if raw.find(b"LocalHost:127.0.0.1:14445") != -1:
                print(f"  [A3] ✅ Đã có 'LocalHost:127.0.0.1:14445' — APK là mod source")
            else:
                print(f"  [A-?] Không tìm thấy server string nào (có thể trong DLL)")

    assert len(data) == orig_size, "BUG: meta size changed!"
    if changed_meta > 0:
        with open(meta_path, 'wb') as f:
            f.write(bytes(data))
        print(f"  Saved ✅ (size unchanged)")


# ═════════════════════════════════════════════════════════════════
# 3. Assembly-CSharp.dll (Mono) — UTF-16LE binary in-place patch
# ═════════════════════════════════════════════════════════════════
print(f"\n{'─'*55}")
print(f"[Mono] Assembly-CSharp.dll — {len(dll_paths)} file(s) found")

for dll_path in dll_paths:
    dll_size = os.path.getsize(dll_path)
    print(f"\n  DLL: {os.path.relpath(dll_path, ASSETS_DIR)}  ({dll_size:,} bytes)")

    with open(dll_path, 'rb') as f:
        dll = bytearray(f.read())
    dll_orig_size = len(dll)
    dll_raw = bytes(dll)
    dll_changed = 0

    # Helper: search UTF-16LE string in DLL
    def find_u16(s: str) -> int:
        return dll_raw.find(s.encode('utf-16le'))

    # Helper: show context around DLL match
    def show_ctx(idx: int, nbytes: int = 40):
        ctx = dll_raw[max(0, idx-4):idx+nbytes+4]
        return ''.join(chr(b) if 32 <= b < 127 else ('.' if b else '_') for b in ctx if True)

    # Diagnosis: kiểm tra các patterns
    patterns_check = [
        "LocalHost:127.0.0.1:14445",   # already patched
        "Blue 1:14.225.203.242",        # raw server list
        "14.225.203.242",               # just IP
        "74-55-43-5C",                  # start of ipString
        "Blue 1:",                      # just beginning
    ]
    print(f"  Scan kết quả:")
    found_anything = False
    for p in patterns_check:
        ix = find_u16(p)
        if ix != -1:
            print(f"    ✓ '{p}' tại offset {ix}")
            found_anything = True
        else:
            print(f"    ✗ '{p}'")

    if not found_anything:
        # Thử tìm bất kỳ IP nào liên quan
        ip_u16 = "14.225.203.242".encode('utf-16le')
        if dll_raw.find(ip_u16) == -1:
            print(f"  → Không tìm thấy string nào — DLL có thể encrypt hoặc đây không phải Mono")
        continue

    # ── Strategy B1: tìm ipString hex start ──────────────────────
    ORIG_HEX_U16 = ORIG_IPSTRING_HEX_START.decode('ascii').encode('utf-16le')
    ix_b1 = dll_raw.find(ORIG_HEX_U16)
    if ix_b1 != -1:
        # Tìm hết chuỗi hex này (đến null-null hoặc ký tự không phải hex/dash)
        end_b1 = ix_b1
        while end_b1 + 1 < len(dll_raw):
            ch = dll_raw[end_b1:end_b1+2]
            if ch == b'\x00\x00':
                break
            try:
                c = ch.decode('utf-16le')
                if c not in '0123456789ABCDEFabcdef-':
                    break
            except:
                break
            end_b1 += 2
        old_len_b1 = end_b1 - ix_b1
        old_str_b1 = dll_raw[ix_b1:end_b1].decode('utf-16le', errors='?')
        print(f"\n  [B1] ipString hex tại offset={ix_b1}, len={old_len_b1} bytes")
        print(f"       Start: {old_str_b1[:50]}...")
        # New: XOR-encoded single-server string, encoded as UTF-16LE
        new_b1 = NEW_IPSTRING_BYTES.decode('ascii').encode('utf-16le')
        if inplace_replace(dll, ix_b1, old_len_b1, new_b1,
                           pad_byte=' '.encode('utf-16le')):
            dll_changed += 1
            print(f"  [B1] ✅ Patched ipString → single-server (pad=space UTF-16LE)")
        else:
            print(f"  [B1] ⚠️ New string longer ({len(new_b1)}) > old ({old_len_b1})")

    # ── Strategy B2: tìm "Blue 1:14.225.203.242..." full list ────
    if dll_changed == 0:
        BLUE_U16 = "Blue 1:14.225.203.242".encode('utf-16le')
        ix_b2 = dll_raw.find(BLUE_U16)
        if ix_b2 != -1:
            end_b2 = ix_b2
            while end_b2 + 1 < len(dll_raw):
                ch = dll_raw[end_b2:end_b2+2]
                if ch == b'\x00\x00':
                    break
                end_b2 += 2
            old_len_b2 = end_b2 - ix_b2
            old_str_b2 = dll_raw[ix_b2:end_b2].decode('utf-16le', errors='?')
            print(f"\n  [B2] Server list tại offset={ix_b2}: '{old_str_b2[:60]}...'")
            new_b2 = TARGET_SERVER.encode('utf-16le')
            if inplace_replace(dll, ix_b2, old_len_b2, new_b2,
                               pad_byte=' '.encode('utf-16le')):
                dll_changed += 1
                print(f"  [B2] ✅ Patched server list → single server")
            else:
                print(f"  [B2] ⚠️ Cannot replace in-place")

    # ── Strategy B3: thay tất cả IP:Port occurrences ─────────────
    if dll_changed == 0:
        ip_str = "14.225.203.242"
        for old_port in ["3736", "3737", "3738", "3859"]:
            old_combo = f"{ip_str}:{old_port}"   # "14.225.203.242:3736"
            new_combo = "127.0.0.1:14445   "     # same length (19 chars, pad spaces)
            assert len(old_combo) == len(new_combo), f"Combo length mismatch: {len(old_combo)} ≠ {len(new_combo)}"
            search_u16 = old_combo.encode('utf-16le')
            replace_u16 = new_combo.encode('utf-16le')
            start = 0
            while True:
                ix = dll_raw.find(search_u16, start)
                if ix == -1:
                    break
                print(f"  [B3] Replacing '{old_combo}' → '{new_combo}' at offset={ix}")
                for i, b in enumerate(replace_u16):
                    dll[ix + i] = b
                dll_changed += 1
                dll_raw = bytes(dll)
                start = ix + len(replace_u16)

    # ── Strategy B4: kiểm tra đã có localhost ─────────────────────
    if dll_changed == 0:
        LOCAL_U16 = "LocalHost:127.0.0.1:14445".encode('utf-16le')
        if dll_raw.find(LOCAL_U16) != -1:
            print(f"  [B4] ✅ DLL đã có 'LocalHost:127.0.0.1:14445' — APK là mod source")

    assert len(dll) == dll_orig_size, "BUG: DLL size changed!"
    if dll_changed > 0:
        with open(dll_path, 'wb') as f:
            f.write(bytes(dll))
        print(f"  Saved ✅  ({dll_changed} location(s) patched, size unchanged)")
        changed_dll += dll_changed


# ═════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════
print(f"\n{'='*55}")
print(f"Text config patched : {changed_text} files")
print(f"IL2CPP meta patched : {changed_meta} location(s)")
print(f"Mono DLL patched    : {changed_dll} location(s)")
print(f"Binary safety       : ✅ chỉ dùng rb/wb mode")
auto_ok = (changed_meta + changed_dll) > 0
print(f"Auto-connect        : {'✅ 1 server → game tự chọn' if auto_ok else '⚠️ cần kiểm tra log'}")
print(f"Target              : {TARGET_SERVER}")
print(f"{'='*55}")
