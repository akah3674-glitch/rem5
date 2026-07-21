#!/bin/bash
# Auto-start NRO Game Server + WebSocket Bridge — WebSocket ONLY
# Goi boi devcontainer.json postStartCommand

LOG_DIR="$HOME/logs"
mkdir -p "$LOG_DIR"
exec >> "$LOG_DIR/autostart.log" 2>&1

echo ""
echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Codespace autostart ==="

REPLIT_API_URL="${REPLIT_API_URL:-}"
SESSION_SECRET="${SESSION_SECRET:-}"

# 1. MariaDB
if mysql -u root -e "SELECT 1;" > /dev/null 2>&1; then
  echo "[OK] MariaDB running"
else
  echo "[START] MariaDB..."
  sudo service mariadb start 2>/dev/null || \
    sudo mariadbd-safe --user=mysql >> "$LOG_DIR/mariadb.log" 2>&1 &
  sleep 5
  mysql -u root -e "SELECT 1;" > /dev/null 2>&1 && echo "[OK] MariaDB OK" || echo "[WARN] MariaDB not ready"
fi

# 2. Game Server (TCP 14445 — internal only, khong expose ra ngoai)
if pgrep -f NgocRongOnline > /dev/null 2>&1; then
  echo "[OK] Game server running ($(pgrep -f NgocRongOnline | head -1))"
else
  NRO_DIR=""
  for d in ~/nro/SRC /home/codespace/nro/SRC /workspaces/*/server; do
    [ -f "$d/NgocRongOnline.jar" ] && NRO_DIR="$d" && break
  done
  if [ -n "$NRO_DIR" ]; then
    cd "$NRO_DIR"
    nohup java -Xms512m -Xmx1g \
      -XX:+UseG1GC -XX:MaxGCPauseMillis=30 \
      -XX:G1HeapRegionSize=4m -XX:+ParallelRefProcEnabled \
      -XX:InitiatingHeapOccupancyPercent=35 \
      -Djava.net.preferIPv4Stack=true \
      -jar NgocRongOnline.jar >> "$LOG_DIR/server.log" 2>&1 &
    echo "[START] Game server PID=$! dir=$NRO_DIR"
    sleep 10
    pgrep -f NgocRongOnline > /dev/null && echo "[OK] Game server up" || echo "[WARN] Game server not up yet"
  else
    echo "[WARN] NgocRongOnline.jar not found — skip"
  fi
fi

# 3. WebSocket Bridge (port 8080 → TCP 14445) — public HTTPS/WSS
if pgrep -f ws_bridge > /dev/null 2>&1; then
  echo "[OK] ws_bridge running ($(pgrep -f ws_bridge | head -1))"
else
  WS_BRIDGE=""
  for p in ~/bin/ws_bridge.py ~/ws_bridge.py /tmp/ws_bridge.py /workspaces/*/scripts/ws_bridge_server.py; do
    [ -f "$p" ] && WS_BRIDGE="$p" && break
  done

  if [ -z "$WS_BRIDGE" ]; then
    WS_BRIDGE="/tmp/ws_bridge.py"
    cat > "$WS_BRIDGE" << 'PYEOF'
#!/usr/bin/env python3
"""WS Bridge: WebSocket 0.0.0.0:8080 -> TCP 127.0.0.1:14445"""
import asyncio, logging, sys, subprocess
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s', datefmt='%H:%M:%S')
log = logging.getLogger(__name__)
try:
    import websockets
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "websockets", "-q"])
    import websockets

async def handle(ws, path=None):
    ip = ws.remote_address[0] if ws.remote_address else "?"
    log.info(f"Client: {ip}")
    try:
        reader, writer = await asyncio.open_connection("127.0.0.1", 14445)
        async def a2b():
            async for d in ws:
                if isinstance(d, bytes): writer.write(d); await writer.drain()
            writer.close()
        async def b2a():
            while True:
                d = await reader.read(65536)
                if not d: break
                await ws.send(d)
            await ws.close()
        await asyncio.gather(a2b(), b2a(), return_exceptions=True)
    except Exception as e:
        log.error(f"Error: {e}")
    log.info(f"Disconnected: {ip}")

async def main():
    log.info("WS Bridge 0.0.0.0:8080 -> 127.0.0.1:14445")
    async with websockets.serve(handle, "0.0.0.0", 8080,
      ping_interval=20, ping_timeout=10,
      max_size=10*1024*1024, compression=None):
        await asyncio.Future()

asyncio.run(main())
PYEOF
  fi
  nohup python3 "$WS_BRIDGE" >> "$LOG_DIR/ws_bridge.log" 2>&1 &
  echo "[START] ws_bridge PID=$! script=$WS_BRIDGE"
  sleep 3
  pgrep -f ws_bridge > /dev/null && echo "[OK] ws_bridge up" || echo "[WARN] ws_bridge not up"
fi

# 4. Port 8080 public + push URL len Replit API
sleep 3
if command -v gh > /dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
  gh codespace ports visibility 8080:public -c "$CODESPACE_NAME" 2>/dev/null \
    && echo "[OK] Port 8080 public" || echo "[WARN] port visibility skip"

  WSS_URL="wss://${CODESPACE_NAME}-8080.app.github.dev"
  if [ -n "$REPLIT_API_URL" ] && [ -n "$SESSION_SECRET" ]; then
    RESP=$(curl -s -X POST "${REPLIT_API_URL}/api/ws-url" \
      -H "Content-Type: application/json" \
      -H "x-update-secret: ${SESSION_SECRET}" \
      -d "{\"url\":\"$WSS_URL\"}" 2>/dev/null)
    echo "[OK] URL pushed: $WSS_URL -> $RESP"
  else
    echo "[INFO] WSS URL: $WSS_URL (REPLIT_API_URL chua set)"
  fi
else
  echo "[WARN] gh CLI / CODESPACE_NAME chua co — skip"
fi

echo "=== [$(date '+%Y-%m-%d %H:%M:%S')] Autostart done ==="
