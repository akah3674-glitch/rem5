#!/usr/bin/env python3
"""
Patch NRO APK smali để:
1. Hardcode server IP → 127.0.0.1, port → 14445
2. Auto-connect bỏ qua màn hình chọn server (inject simulate-click vào onCreate)
"""
import os, re, sys, json

SMALI_DIR  = sys.argv[1] if len(sys.argv) > 1 else "/tmp/game_src/smali"
ASSETS_DIR = sys.argv[2] if len(sys.argv) > 2 else "/tmp/game_src/assets"

TARGET_HOST     = "127.0.0.1"
TARGET_PORT     = 14445
TARGET_PORT_HEX = hex(TARGET_PORT)   # "0x386d"

# Các port NRO thường dùng (trừ 14445)
OTHER_PORTS = {14449: "0x3871", 21445: "0x53c5", 14446: "0x386e",
               14447: "0x386f", 14448: "0x3870", 14450: "0x3872"}

changed = []

# ─────────────────────────────────────────────────────────────────
# 1. Patch assets (JSON / text config files)
# ─────────────────────────────────────────────────────────────────
if os.path.exists(ASSETS_DIR):
    for root, _, files in os.walk(ASSETS_DIR):
        for fname in files:
            fp = os.path.join(root, fname)
            try:
                with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
            except Exception:
                continue
            orig = text
            # Replace IPv4 addresses
            text = re.sub(r'(?<!["\w])(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(?!["\w])',
                          TARGET_HOST, text)
            # Replace common server domains
            text = re.sub(r'fw\.patus\.tech|nrolight\.net|nro\d*\.\w+\.\w+',
                          TARGET_HOST, text)
            # Replace ports in strings
            for p in OTHER_PORTS:
                text = text.replace(f':{p}', f':{TARGET_PORT}')
                text = text.replace(f'"{p}"', f'"{TARGET_PORT}"')
            if text != orig:
                with open(fp, "w", encoding="utf-8") as fh:
                    fh.write(text)
                changed.append(("assets", fp))
                print(f"  [assets] {os.path.relpath(fp, ASSETS_DIR)}")

# ─────────────────────────────────────────────────────────────────
# 2. Scan smali — collect info, then patch
# ─────────────────────────────────────────────────────────────────
RE_IP_CONST    = re.compile(r'(const-string\s+\w+,\s+")(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(")')
RE_DOMAIN_CONST = re.compile(r'(const-string\s+\w+,\s+")(fw\.patus\.tech|nrolight\.net)(")')
RE_PORT_DEC    = re.compile(r'(\bconst(?:/4|/16|)?\s+\w+,\s+)(\d{4,5})\b')

# Smali files that likely have server-selection logic
server_select_files = []  # files containing "DragonBoy" / server list
socket_files        = []  # files doing TCP connect

for root, _, files in os.walk(SMALI_DIR):
    for fname in files:
        if not fname.endswith(".smali"):
            continue
        fp = os.path.join(root, fname)
        with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
            content = fh.read()

        if re.search(r'DragonBoy|server.*list|ServerList|chon.*sv|selectServer',
                     content, re.IGNORECASE):
            server_select_files.append(fp)

        if any(kw in content for kw in [
            "Ljava/net/Socket;", "SSLSocket", "InetSocketAddress",
            "openConnection", "HttpURLConnection"
        ]):
            socket_files.append(fp)

print(f"\nServer-select smali ({len(server_select_files)}):")
for f in server_select_files:
    print(f"  {os.path.relpath(f, SMALI_DIR)}")

print(f"\nSocket/network smali ({len(socket_files)}):")
for f in socket_files[:20]:
    print(f"  {os.path.relpath(f, SMALI_DIR)}")

# ─── Patch all smali ─────────────────────────────────────────────
for root, _, files in os.walk(SMALI_DIR):
    for fname in files:
        if not fname.endswith(".smali"):
            continue
        fp = os.path.join(root, fname)
        with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
            content = fh.read()
        orig = content

        has_net = fp in socket_files
        has_ip  = RE_IP_CONST.search(content) is not None
        has_dom = RE_DOMAIN_CONST.search(content) is not None

        if has_net or has_ip or has_dom:
            # Patch IPv4 literals
            content = RE_IP_CONST.sub(
                lambda m: m.group(1) + TARGET_HOST + m.group(3), content)
            # Patch domain literals
            content = RE_DOMAIN_CONST.sub(
                lambda m: m.group(1) + TARGET_HOST + m.group(3), content)
            # Patch port hex literals (only when near socket code)
            if has_net or has_ip:
                for old_port, old_hex in OTHER_PORTS.items():
                    content = content.replace(old_hex, TARGET_PORT_HEX)
                # Patch decimal port constants that look like game ports
                def patch_dec_port(m):
                    val = int(m.group(2))
                    if val in OTHER_PORTS:
                        return m.group(1) + str(TARGET_PORT)
                    return m.group(0)
                content = RE_PORT_DEC.sub(patch_dec_port, content)

        if content != orig:
            with open(fp, "w", encoding="utf-8") as fh:
                fh.write(content)
            changed.append(("smali", fp))
            print(f"  [smali] {os.path.relpath(fp, SMALI_DIR)}")

# ─────────────────────────────────────────────────────────────────
# 3. Auto-connect patch — tìm server-select Activity và inject
#    invoke-virtual vào cuối onCreate để tự click server đầu tiên
# ─────────────────────────────────────────────────────────────────
AUTO_CONNECT_DONE = False

for fp in server_select_files:
    with open(fp, "r", encoding="utf-8", errors="ignore") as fh:
        content = fh.read()
    orig = content

    # Tìm onClick / onItemClick / onServerClick methods
    # NRO pattern: method có tên chứa "click", "select", "connect", "server"
    # và gọi Intent hoặc GameConfig set

    # Tìm method onCreate trong file này
    # Inject: gọi performClick() trên view đầu tiên, hoặc gọi trực tiếp method connect

    # Chiến lược đơn giản: tìm method "onClick" hoặc "onItemClick"
    # Nếu tìm thấy → extract tên → thêm auto-call trong onCreate/onResume

    # Tìm tên các method liên quan đến kết nối server
    connect_methods = re.findall(
        r'\.method.*?((?:on(?:Item)?Click|connect|selectServer|loginServer|startGame)\w*)\s*\(',
        content, re.IGNORECASE
    )
    
    # Tìm onCreate method
    oncreate_match = re.search(
        r'(\.method public onCreate\(Landroid/os/Bundle;\)V.*?\.end method)',
        content, re.DOTALL
    )
    
    if oncreate_match and connect_methods:
        method_name = connect_methods[0]
        oncreate_body = oncreate_match.group(0)
        
        # Tìm return-void trong onCreate và insert auto-connect trước đó
        # Thêm invoke của connect method với register p0 (this)
        auto_call = f"""
    # AUTO-CONNECT: bỏ qua server selection UI
    const/4 v0, 0x0
    invoke-virtual {{p0, v0}}, {oncreate_match.group(0).split('{')[0].strip().split()[-1].split('(')[0]}->"""
        
        # Tạo smali snippet đơn giản: gọi method connect với index 0
        # Pattern: invoke-virtual {p0}, Lclass;->methodName()V
        class_name = re.search(r'\.class.*?L([^;]+);', content)
        if class_name and method_name:
            cls = "L" + class_name.group(1) + ";"
            snippet = f"""
    # [AUTO-CONNECT PATCH] tự động chọn server đầu tiên
    const/4 v10, 0x0
    invoke-virtual {{p0, v10}}, {cls}->{method_name}(I)V
"""
            # Insert trước return-void cuối cùng của onCreate
            patched_oncreate = oncreate_body.replace(
                "\n    return-void\n\n.end method",
                snippet + "\n    return-void\n\n.end method",
                1  # chỉ replace lần đầu tiên từ cuối
            )
            if patched_oncreate != oncreate_body:
                content = content.replace(oncreate_body, patched_oncreate)
                AUTO_CONNECT_DONE = True

    if content != orig:
        with open(fp, "w", encoding="utf-8") as fh:
            fh.write(content)
        changed.append(("auto-connect", fp))
        print(f"  [auto-connect] {os.path.relpath(fp, SMALI_DIR)}")

# ─────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────
print(f"\n{'='*50}")
print(f"TỔNG: {len(changed)} files đã patch")
print(f"Auto-connect: {'✅ OK' if AUTO_CONNECT_DONE else '⚠️ Không tìm thấy Activity phù hợp — cần patch thủ công'}")
print(f"Server IP → {TARGET_HOST}")
print(f"Port → {TARGET_PORT}")
print(f"{'='*50}")
