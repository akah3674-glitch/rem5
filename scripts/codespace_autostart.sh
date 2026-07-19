#!/bin/bash
# Auto-start NRO Game Server + WebSocket Bridge khi Codespace wake/resume
# Được gọi bởi devcontainer.json postStartCommand

LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/autostart.log" 2>&1

echo "=== [$(date)] Codespace autostart ==="

# ── 1. Game Server ────────────────────────────────────────────────────────────
if pgrep -f NgocRongOnline > /dev/null 2>&1; then
  echo "[OK] Game server đang chạy ($(pgrep -f NgocRongOnline))"
else
  NRO_DIR=""
  for d in ~/nro/SRC /home/codespace/nro/SRC /workspaces/*/server; do
    [ -f "$d/NgocRongOnline.jar" ] && NRO_DIR="$d" && break
  done
  if [ -n "$NRO_DIR" ]; then
    cd "$NRO_DIR"
    nohup java -Xms256m -Xmx1g -jar NgocRongOnline.jar >> "$LOG_DIR/server.log" 2>&1 &
    echo "[START] Game server PID=$! dir=$NRO_DIR"
  else
    echo "[WARN] Không tìm thấy NgocRongOnline.jar"
  fi
fi

# ── 2. WebSocket Bridge (port 8080 → TCP 14445) ───────────────────────────────
if pgrep -f ws_bridge > /dev/null 2>&1; then
  echo "[OK] ws_bridge đang chạy ($(pgrep -f ws_bridge))"
else
  # Tìm ws_bridge script
  WS_BRIDGE=""
  for p in /tmp/ws_bridge.py ~/ws_bridge.py /workspaces/*/scripts/ws_bridge_server.py; do
    [ -f "$p" ] && WS_BRIDGE="$p" && break
  done

  # Nếu không tìm thấy, tạo inline
  if [ -z "$WS_BRIDGE" ]; then
    WS_BRIDGE="/tmp/ws_bridge.py"
    cat > "$WS_BRIDGE" << 'PYEOF'
#!/usr/bin/env python3
"""WS Bridge: WebSocket port 8080 → TCP 127.0.0.1:14445 (Game Server)"""
import asyncio, logging, sys
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s', datefmt='%H:%M:%S')
log = logging.getLogger(__name__)
GAME_HOST, GAME_PORT, LISTEN_PORT = "127.0.0.1", 14445, 8080

try:
    import websockets
except ImportError:
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "websockets", "-q"])
    import websockets

async def handle(ws, path=None):
    log.info(f"APK kết nối: {ws.remote_address}")
    try:
        reader, writer = await asyncio.open_connection(GAME_HOST, GAME_PORT)
        log.info(f"Game server connected {GAME_HOST}:{GAME_PORT}")
        async def ws_to_tcp():
            async for data in ws:
                if isinstance(data, bytes):
                    writer.write(data)
                    await writer.drain()
            writer.close()
        async def tcp_to_ws():
            while True:
                data = await reader.read(65536)
                if not data: break
                await ws.send(data)
            await ws.close()
        await asyncio.gather(ws_to_tcp(), tcp_to_ws())
    except Exception as e:
        log.error(f"Error: {e}")

async def main():
    log.info(f"WS Bridge listening 0.0.0.0:{LISTEN_PORT} → {GAME_HOST}:{GAME_PORT}")
    async with websockets.serve(
        handle, "0.0.0.0", LISTEN_PORT,
        ping_interval=20, ping_timeout=10,
        max_size=10*1024*1024, compression=None
    ):
        await asyncio.Future()

asyncio.run(main())
PYEOF
  fi

  nohup python3 "$WS_BRIDGE" >> "$LOG_DIR/ws_bridge.log" 2>&1 &
  echo "[START] ws_bridge PID=$! script=$WS_BRIDGE"
fi

# ── 3. Đảm bảo port 8080 public ──────────────────────────────────────────────
sleep 3
if command -v gh > /dev/null 2>&1 && [ -n "$CODESPACE_NAME" ]; then
  gh codespace ports visibility 8080:public -c "$CODESPACE_NAME" 2>/dev/null \
    && echo "[OK] Port 8080 set public" \
    || echo "[WARN] Không set được port visibility (có thể đã public)"
fi

echo "=== [$(date)] Autostart hoàn tất ==="
