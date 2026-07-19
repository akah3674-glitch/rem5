---
name: NRO No-TCP Architecture — DONE v1.3.0
description: Bridge nhúng trong APK, relay qua Replit WS (URL cố định). v1.3.0 released.
---

## Kiến trúc hiện tại (v1.3.0)

```
APK → wss://[replit-dev-domain]/api/ws → Replit relay → wss://codespace-8080 → TCP local → Game Server
```

**Không dùng raw TCP xuyên internet** — hoàn toàn WebSocket.

## APK URL cố định (không bao giờ cần build lại)

`wss://e79372d3-fe48-4f9f-baa2-8dd65d05bf38-00-2shrgxg66t9cc.sisko.replit.dev/api/ws`

**Release:** https://github.com/akah3674-glitch/rem5/releases/tag/v1.3.0

## Replit WS Relay

- File: `artifacts/api-server/src/index.ts`
- WebSocket upgrade tại `/api/ws` → relay sang `GAME_WS_URL` env var
- `GAME_WS_URL` = `wss://cautious-space-halibut-p7rwgqwxrg5gfrrqg-8080.app.github.dev`
- Nếu Codespace URL đổi → chỉ cần update `GAME_WS_URL` trên Replit, không rebuild APK

## Codespace Auto-Start (khi wake/resume)

- `scripts/codespace_autostart.sh` — auto-start game server + ws_bridge
- `.devcontainer/devcontainer.json` → `postStartCommand` gọi script trên
- Port 8080 tự set public

## Keepalive (GitHub Actions scheduled)

- `.github/workflows/codespace-keepalive.yml` — chạy mỗi 20 phút
- Ping ws bridge → nếu chết thì SSH vào Codespace restart services
- Tránh Codespace sleep (timeout 30 phút)

## Fix v1.2.0 (APK crash Android 14)

- Thêm `FOREGROUND_SERVICE_DATA_SYNC` permission vào `android-bridge-inject/patch_manifest.py`
- Bắt buộc khi dùng `foregroundServiceType="dataSync"` trên Android 14+

## Test

Custom Server = `127.0.0.1:14445` trong game → bridge tự relay qua Replit → Codespace → game server local.

## Nếu Codespace URL đổi (tạo Codespace mới)

1. Lấy URL mới: `wss://<new-codespace>-8080.app.github.dev`
2. Update env var `GAME_WS_URL` trên Replit (không cần rebuild APK)
3. APK không thay đổi
