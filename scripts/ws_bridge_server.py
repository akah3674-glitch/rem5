#!/usr/bin/env python3
"""
WebSocket Bridge SERVER — chạy trên Codespace port 8080
Client gửi TCP game data qua WebSocket → bridge forward tới game server 14445
"""
import asyncio
import sys
import logging

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s', datefmt='%H:%M:%S')
log = logging.getLogger(__name__)

GAME_HOST = "127.0.0.1"
GAME_PORT = 14445
LISTEN_PORT = 8080

try:
    import websockets
except ImportError:
    import subprocess, sys
    subprocess.run([sys.executable, "-m", "pip", "install", "websockets", "-q"])
    import websockets

async def handle_client(websocket, path=None):
    client_addr = websocket.remote_address
    log.info(f"Client kết nối: {client_addr}")
    
    try:
        # Kết nối tới game server
        reader, writer = await asyncio.open_connection(GAME_HOST, GAME_PORT)
        log.info(f"Đã kết nối game server {GAME_HOST}:{GAME_PORT}")
        
        async def ws_to_tcp():
            try:
                async for data in websocket:
                    if isinstance(data, bytes):
                        writer.write(data)
                        await writer.drain()
            except Exception as e:
                log.debug(f"ws→tcp end: {e}")
            finally:
                writer.close()

        async def tcp_to_ws():
            try:
                while True:
                    data = await reader.read(65536)
                    if not data:
                        break
                    await websocket.send(data)
            except Exception as e:
                log.debug(f"tcp→ws end: {e}")
            finally:
                await websocket.close()

        await asyncio.gather(ws_to_tcp(), tcp_to_ws())
        
    except ConnectionRefusedError:
        log.error(f"Không kết nối được game server {GAME_HOST}:{GAME_PORT}")
        await websocket.close()
    except Exception as e:
        log.error(f"Lỗi: {e}")
    finally:
        log.info(f"Client ngắt kết nối: {client_addr}")

async def main():
    log.info(f"WebSocket Bridge Server khởi động port {LISTEN_PORT}")
    log.info(f"Forward → {GAME_HOST}:{GAME_PORT}")
    
    async with websockets.serve(
        handle_client,
        "0.0.0.0",
        LISTEN_PORT,
        ping_interval=20,
        ping_timeout=10,
        max_size=10 * 1024 * 1024,  # 10MB
        compression=None,  # không compress để giảm CPU
    ):
        log.info(f"✅ Đang lắng nghe ws://0.0.0.0:{LISTEN_PORT}")
        await asyncio.Future()  # chạy mãi mãi

if __name__ == "__main__":
    asyncio.run(main())
