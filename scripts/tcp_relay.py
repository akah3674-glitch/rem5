#!/usr/bin/env python3
"""
NRO TCP Relay — tự tạo, không dùng binary bên thứ 3
Chạy trên Termux hoặc bất kỳ máy Linux nào

Modes:
  1. FORWARD  — nhận kết nối vào rồi forward đến server đích
  2. REVERSE  — kết nối ra ngoài tạo tunnel ngược (không cần public IP)
  3. BRIDGE   — ghép 2 kết nối TCP lại với nhau (dùng khi có 2 máy relay)
"""

import socket, threading, select, sys, time, argparse, os, signal

# ── màu terminal ─────────────────────────────────────────────
G = "\033[92m"; Y = "\033[93m"; R = "\033[91m"
C = "\033[96m"; B = "\033[1m";  N = "\033[0m"

def log(msg, color=N):
    ts = time.strftime("%H:%M:%S")
    print(f"{color}[{ts}] {msg}{N}", flush=True)

def ok(m):   log(f"✅ {m}", G)
def err(m):  log(f"❌ {m}", R)
def info(m): log(f"→  {m}", Y)

# ── pipe dữ liệu giữa 2 socket ───────────────────────────────
def pipe(src, dst, label=""):
    try:
        while True:
            r, _, _ = select.select([src], [], [], 30)
            if not r:
                break
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except Exception:
        pass
    finally:
        try: src.close()
        except: pass
        try: dst.close()
        except: pass

def bridge(a, b):
    """Ghép 2 socket — bidirectional"""
    t1 = threading.Thread(target=pipe, args=(a, b, "→"), daemon=True)
    t2 = threading.Thread(target=pipe, args=(b, a, "←"), daemon=True)
    t1.start(); t2.start()

# ════════════════════════════════════════════════════════════
# MODE 1: FORWARD PROXY
# Lắng nghe cổng local, forward mỗi kết nối đến remote
# Dùng khi: điện thoại có public IP hoặc port forwarding
#
# Client Game  →  [phone:LISTEN_PORT]  →  Codespace:TARGET
# ════════════════════════════════════════════════════════════
def mode_forward(listen_port, target_host, target_port):
    info(f"FORWARD MODE: 0.0.0.0:{listen_port} → {target_host}:{target_port}")

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", listen_port))
    srv.listen(50)
    ok(f"Đang lắng nghe port {listen_port}")
    info("Ctrl+C để dừng")

    def handle(client, addr):
        info(f"Kết nối từ {addr[0]}:{addr[1]}")
        try:
            remote = socket.create_connection((target_host, target_port), timeout=10)
            ok(f"Đã nối {addr[0]} → {target_host}:{target_port}")
            bridge(client, remote)
        except Exception as e:
            err(f"Không kết nối được đến {target_host}:{target_port} — {e}")
            client.close()

    while True:
        try:
            client, addr = srv.accept()
            threading.Thread(target=handle, args=(client, addr), daemon=True).start()
        except KeyboardInterrupt:
            break
    srv.close()

# ════════════════════════════════════════════════════════════
# MODE 2: REVERSE TUNNEL
# Phone kết nối ra một relay server công cộng
# Relay server nhận game client, ghép với kết nối của phone
#
# Cần 1 relay server có public IP (VPS, Oracle Free...)
#
# Phone     ──connect out──►  relay_server:CTRL_PORT  (control)
# GameClient ──connect in──►  relay_server:GAME_PORT  (data)
# relay ghép 2 kết nối lại → traffic đi qua phone đến Codespace
# ════════════════════════════════════════════════════════════
CTRL_MAGIC = b"NRO_CTRL_v1\n"
DATA_MAGIC = b"NRO_DATA_v1\n"

def mode_reverse_client(relay_host, ctrl_port, local_host, local_port):
    """Chạy trên Phone/Codespace — kết nối ra relay server"""
    info(f"REVERSE CLIENT: {relay_host}:{ctrl_port} → local {local_host}:{local_port}")

    while True:
        try:
            ctrl = socket.create_connection((relay_host, ctrl_port), timeout=15)
            ctrl.sendall(CTRL_MAGIC)
            ok(f"Kết nối relay thành công: {relay_host}:{ctrl_port}")

            while True:
                # Relay gửi "NEW_CONN\n" mỗi khi có game client kết nối
                data = b""
                while not data.endswith(b"\n"):
                    chunk = ctrl.recv(64)
                    if not chunk:
                        raise ConnectionResetError("relay đóng kết nối")
                    data += chunk

                if data.strip() == b"NEW_CONN":
                    info("Game client mới → mở kết nối local...")
                    # Kết nối đến local game server
                    try:
                        local = socket.create_connection((local_host, local_port), timeout=5)
                    except Exception as e:
                        err(f"Không kết nối local {local_host}:{local_port} — {e}")
                        ctrl.sendall(b"FAIL\n")
                        continue

                    # Mở data channel mới đến relay
                    data_sock = socket.create_connection((relay_host, ctrl_port), timeout=10)
                    data_sock.sendall(DATA_MAGIC)
                    ok("Data channel mở — bridging...")
                    threading.Thread(target=bridge, args=(local, data_sock), daemon=True).start()
                    ctrl.sendall(b"OK\n")

        except KeyboardInterrupt:
            info("Dừng reverse client")
            break
        except Exception as e:
            err(f"Mất kết nối relay: {e} — thử lại sau 5s...")
            time.sleep(5)

def mode_reverse_server(ctrl_port, game_port):
    """Chạy trên VPS/relay — nhận kết nối từ cả phone lẫn game client"""
    info(f"REVERSE SERVER: ctrl={ctrl_port}, game client={game_port}")

    pending_data = []  # data sockets chờ ghép
    pending_clients = []  # game clients chờ ghép
    lock = threading.Lock()
    ctrl_conn = [None]

    def try_bridge():
        with lock:
            while pending_data and pending_clients:
                d = pending_data.pop(0)
                c = pending_clients.pop(0)
                ok("Ghép game client ↔ phone tunnel")
                threading.Thread(target=bridge, args=(d, c), daemon=True).start()

    def handle_ctrl(sock, addr):
        """Xử lý kết nối từ phone (control + data channels)"""
        try:
            hdr = b""
            while not hdr.endswith(b"\n"):
                hdr += sock.recv(64)

            if hdr.strip() == CTRL_MAGIC.strip():
                info(f"Phone tunnel kết nối từ {addr[0]}")
                ctrl_conn[0] = sock

                # Giữ control loop
                while True:
                    msg = b""
                    while not msg.endswith(b"\n"):
                        chunk = sock.recv(64)
                        if not chunk:
                            raise ConnectionResetError
                        msg += chunk
                    # OK / FAIL từ phone sau khi nhận NEW_CONN

            elif hdr.strip() == DATA_MAGIC.strip():
                info(f"Data channel từ phone {addr[0]}")
                with lock:
                    pending_data.append(sock)
                try_bridge()

        except Exception as e:
            info(f"Phone disconnect: {e}")
            if ctrl_conn[0] == sock:
                ctrl_conn[0] = None

    def handle_game_client(sock, addr):
        """Kết nối từ game client"""
        info(f"Game client: {addr[0]}:{addr[1]}")
        with lock:
            pending_clients.append(sock)

        # Báo phone mở data channel
        ctrl = ctrl_conn[0]
        if ctrl:
            try:
                ctrl.sendall(b"NEW_CONN\n")
            except:
                err("Phone tunnel mất kết nối")
        else:
            err("Chưa có phone tunnel kết nối!")

        try_bridge()

    # Server cho ctrl_port (phone kết nối vào)
    ctrl_srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    ctrl_srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    ctrl_srv.bind(("0.0.0.0", ctrl_port))
    ctrl_srv.listen(50)

    # Server cho game_port (game client kết nối vào)
    game_srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    game_srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    game_srv.bind(("0.0.0.0", game_port))
    game_srv.listen(50)

    ok(f"Relay server chạy:")
    ok(f"  Phone kết nối vào: port {ctrl_port}")
    ok(f"  Game client kết nối vào: port {game_port}")
    info("Ctrl+C để dừng")

    def accept_loop(srv, handler):
        while True:
            try:
                sock, addr = srv.accept()
                threading.Thread(target=handler, args=(sock, addr), daemon=True).start()
            except Exception:
                break

    threading.Thread(target=accept_loop, args=(ctrl_srv, handle_ctrl), daemon=True).start()
    threading.Thread(target=accept_loop, args=(game_srv, handle_game_client), daemon=True).start()

    try:
        signal.pause()
    except KeyboardInterrupt:
        pass
    ctrl_srv.close()
    game_srv.close()

# ════════════════════════════════════════════════════════════
# MODE 3: BRIDGE (ghép 2 máy qua TCP)
# Đơn giản nhất — 2 bên đều kết nối ra một điểm hẹn
# ════════════════════════════════════════════════════════════
def mode_bridge_server(port):
    """Chờ 2 kết nối TCP rồi ghép chúng lại"""
    info(f"BRIDGE SERVER: port {port} — chờ 2 kết nối...")
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", port))
    srv.listen(10)

    while True:
        info("Chờ kết nối 1...")
        a, addr_a = srv.accept()
        ok(f"Kết nối 1: {addr_a[0]}")
        info("Chờ kết nối 2...")
        b, addr_b = srv.accept()
        ok(f"Kết nối 2: {addr_b[0]}")
        ok("Bridging hai kết nối...")
        threading.Thread(target=bridge, args=(a, b), daemon=True).start()

# ════════════════════════════════════════════════════════════
# CLI
# ════════════════════════════════════════════════════════════
def main():
    print(f"{C}{B}")
    print("  ╔═══════════════════════════════════╗")
    print("  ║   NRO TCP Relay — Custom Build    ║")
    print("  ╚═══════════════════════════════════╝")
    print(f"{N}")

    p = argparse.ArgumentParser(description="NRO TCP Relay")
    sub = p.add_subparsers(dest="mode")

    # forward
    f = sub.add_parser("forward", help="Forward proxy: nhận vào rồi forward đi")
    f.add_argument("--listen",  type=int, default=14445, help="Port lắng nghe (default 14445)")
    f.add_argument("--target",  required=True, help="IP/domain đích (Codespace)")
    f.add_argument("--port",    type=int, default=14445, help="Port đích")

    # reverse-client (chạy trên phone/Codespace)
    rc = sub.add_parser("reverse-client", help="Kết nối ra relay server (không cần public IP)")
    rc.add_argument("--relay",       required=True, help="IP relay server")
    rc.add_argument("--ctrl-port",   type=int, default=7700, help="Port control trên relay")
    rc.add_argument("--local-host",  default="127.0.0.1")
    rc.add_argument("--local-port",  type=int, default=14445)

    # reverse-server (chạy trên VPS/relay)
    rs = sub.add_parser("reverse-server", help="Relay server: nhận cả phone lẫn game client")
    rs.add_argument("--ctrl-port",  type=int, default=7700)
    rs.add_argument("--game-port",  type=int, default=14445)

    # bridge
    br = sub.add_parser("bridge", help="Ghép 2 kết nối TCP")
    br.add_argument("--port", type=int, default=7800)

    args = p.parse_args()

    if args.mode == "forward":
        mode_forward(args.listen, args.target, args.port)

    elif args.mode == "reverse-client":
        mode_reverse_client(args.relay, args.ctrl_port, args.local_host, args.local_port)

    elif args.mode == "reverse-server":
        mode_reverse_server(args.ctrl_port, args.game_port)

    elif args.mode == "bridge":
        mode_bridge_server(args.port)

    else:
        print(f"""
{B}CÁCH DÙNG:{N}

{G}1. Forward proxy{N} (cần public IP hoặc port forwarding):
   python3 tcp_relay.py forward --listen 14445 --target <IP_CODESPACE> --port 14445

{G}2. Reverse tunnel{N} (không cần public IP — cần 1 VPS):
   # Trên VPS:
   python3 tcp_relay.py reverse-server --ctrl-port 7700 --game-port 14445
   
   # Trên Phone (Termux):
   python3 tcp_relay.py reverse-client --relay <VPS_IP> --local-host <CODESPACE_IP> --local-port 14445
   
   # Hoặc trên Codespace:
   python3 tcp_relay.py reverse-client --relay <VPS_IP> --local-host 127.0.0.1 --local-port 14445

{G}3. Bridge{N} (ghép 2 máy):
   python3 tcp_relay.py bridge --port 7800
""")

if __name__ == "__main__":
    main()
