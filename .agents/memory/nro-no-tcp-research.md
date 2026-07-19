---
name: NRO Bridge APK — hiện tại v1.8.0
description: Auto-connect hoàn chỉnh. BridgePreference ghi NRlink2+svselect. Rms dùng filesDir (KHÔNG phải PlayerPrefs).
---

## Kiến trúc (v1.8.0)

```
APK (BridgeProvider.onCreate) → ghi NRlink2+svselect → Unity đọc 1 server → auto-connect
     ↓ đồng thời
BridgeService (foreground) → TCP 127.0.0.1:14445 ← Unity game → WS relay → Replit → Codespace → Game Server
```

## Cơ chế Auto-Connect (v1.8.0)

`Rms.cs` lưu data vào **files** (KHÔNG phải PlayerPrefs/SharedPrefs):
- Path: `context.getFilesDir()` = `/data/data/<pkg>/files/`
- `saveRMSString(key, val)` → DataOutputStream.writeUTF(val) → file `key`
- `saveRMSInt(key, x)` → 1 byte = x → file `key`

`BridgePreference.applyServerPreset(ctx)` ghi TRƯỚC khi Unity đọc:
- `NRlink2` = DataOutputStream.writeUTF("7A-56-55-58-5A-71-59-4A-42-03-07-0B-01-17-06-17-06-17-07-03-07-0D-02-0D-03-03-06-15-06-15-06")
  (= XOR-encode("LocalHost:127.0.0.1:14445:0,0,0", "69"))
- `svselect` = 1 byte = 0

Game ServerListScreen.cs: nếu `nameServer.Length == 1` → auto-select, không hiện UI chọn server.

**Why XOR key "69":** ModFunc.DecodeByteArrayString dùng XOR với UTF-8 bytes của "69" = [0x36, 0x39].

## Server list format (GetServerList parse)

`"Name:IP:Port:lang,Name2:IP2:Port2:lang2,...,defaultLang,priority"`  
→ Split ",", last 2 items = defaultLang + priority  
→ Còn lại = server entries

Single server: `"LocalHost:127.0.0.1:14445:0,0,0"` → 1 server + lang=0 + priority=0

## Key files

- `android-bridge-inject/src/BridgePreference.java` — ghi NRlink2+svselect
- `android-bridge-inject/src/BridgeService.java` — TCP→WS relay, port 14445
- `android-bridge-inject/BridgeProvider.smali` — gọi BridgePreference + start BridgeService
- `android-bridge-inject/patch_server.py` — patch text config + safe binary IL2CPP/Mono (v1.7.0+)
- `.github/workflows/inject-apk.yml` — full build pipeline

## WS URL (Replit relay → Codespace)

`wss://e79372d3-fe48-4f9f-baa2-8dd65d05bf38-00-2shrgxg66t9cc.sisko.replit.dev/api/ws`

Thay `GAME_WS_URL` trên Replit nếu Codespace URL đổi → không cần rebuild APK.

## Lỗi v1.4.0 (đã fix v1.5.0+)

patch_server.py mở binary Unity bằng text mode → corrupt data.unity3d + global-metadata.dat → crash loop → lag.
Fix: chỉ patch text extensions, dùng rb/wb cho binary.

## Lịch sử releases

- v1.0-v1.3: bridge inject, Custom Server thủ công
- v1.4.0: BROKEN — corrupt Unity binary
- v1.5.0: fix binary corruption
- v1.6.0-v1.7.0: thử patch IL2CPP/Mono (không tìm thấy string)
- v1.8.0: auto-connect hoàn chỉnh qua filesDir injection ✅

## Test

Cài v1.8.0 → mở game → KHÔNG cần nhập IP → tự kết nối 127.0.0.1:14445 → relay qua Replit → Codespace → game server.
