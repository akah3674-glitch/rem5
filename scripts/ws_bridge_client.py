#!/usr/bin/env python3
"""
WebSocket Bridge CLIENT — chạy trên Termux (phone)
Game client kết nối TCP local → bridge gửi qua WebSocket → Codespace
"""
import asyncio
import sys
import logging

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s', datefmt='%H:%M:%S')
log = logging.getLogger(__name__)

# ═══════════════════════════════════════════
WS_URL   = "wss://cautious-space-halibut-p7rwgqwxrg5gfrrqg-8080.app.github.dev"
LOCAL_PORT = 14445
# ═══════════════════════════════════════════

try:
    import websockets
except ImportError:
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "websockets", "-q"])
    import websockets

async def handle_game_client(reader, writer):
    addr = writer.get_extra_info('peername')
    log.info(f"Game client kết nối: {addr}")

    try:
        async with websockets.connect(
            WS_URL,
            ping_interval=20,
            ping_timeout=10,
            max_size=10 * 1024 * 1024,
            compression=None,
            open_timeout=10,
        ) as ws:
            log.info(f"✅ Đã kết nối WebSocket → {WS_URL}")

            async def tcp_to_ws():
                try:
                    while True:
                        data = await reader.read(65536)
                        if not data:
                            break
                        await ws.send(data)
                except Exception as e:
                    log.debug(f"tcp→ws end: {e}")
                finally:
                    await ws.close()

            async def ws_to_tcp():
                try:
                    async for data in ws:
                        if isinstance(data, bytes):
                            writer.write(data)
                            await writer.drain()
                except Exception as e:
                    log.debug(f"ws→tcp end: {e}")
                finally:
                    writer.close()

            await asyncio.gather(tcp_to_ws(), ws_to_tcp())

    except Exception as e:
        log.error(f"Lỗi WebSocket: {e}")
        writer.close()
    finally:
        log.info(f"Game client ngắt: {addr}")

async def main():
    server = await asyncio.start_server(
        handle_game_client, "0.0.0.0", LOCAL_PORT
    )
    log.info("╔══════════════════════════════════════╗")
    log.info("║   NRO WebSocket Bridge — Client      ║")
    log.info("╚══════════════════════════════════════╝")
    log.info(f"→  TCP local   : 0.0.0.0:{LOCAL_PORT}")
    log.info(f"→  WebSocket   : {WS_URL}")
    log.info(f"→  Ctrl+C để dừng")
    async with server:
        await server.serve_forever()

if __name__ == "__main__":
    asyncio.run(main())
