---
name: NRO No-TCP Architecture — DONE
description: Bridge nhúng trong APK, WSS Codespace public. v1.1.0 đã release.
---

## Kết quả cuối (DONE ✅)

**Kiến trúc:** Game APK → TCP 127.0.0.1:14445 → BridgeService (trong APK) → WSS Codespace → TCP 14445 → Game Server

**Release:** https://github.com/akah3674-glitch/rem5/releases/tag/v1.1.0

**Codespace:** `cautious-space-halibut-p7rwgqwxrg5gfrrqg`
- Bridge: `wss://cautious-space-halibut-p7rwgqwxrg5gfrrqg-8080.app.github.dev` (port public)
- ws_bridge chạy tại `/tmp/ws_bridge.py` → nohup, PID không cố định
- Game server port 14445, playit.gg `147.185.221.211:52286`

**Cách start bridge trên Codespace:**
```bash
pkill -f ws_bridge 2>/dev/null; nohup python3 /tmp/ws_bridge.py > /tmp/ws_bridge.log 2>&1 &
gh codespace ports visibility 8080:public -c cautious-space-halibut-p7rwgqwxrg5gfrrqg
```

**Rebuild APK khi URL đổi:** trigger `.github/workflows/inject-apk.yml` với input `ws_url` mới → download artifact → upload release mới.

**APK inject strategy:**
- `BridgeProvider.smali` (viết tay) → smali/ → classes.dex
- `BridgeService.java` (pure Java, no lambda) → javac → d8 → classes2.dex → zip vào APK
- Multi-dex Android API 26+ native, không cần support lib

**Test:** Custom Server = `127.0.0.1:14445` trong game.
