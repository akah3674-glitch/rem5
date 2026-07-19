# APK Source — Phân loại chi tiết

| Thông tin | Giá trị |
|-----------|---------|
| **Package** | `com.DefaultCompany.DragonBoy11` |
| **Version** | `` |
| **APK size** | 84M |
| **MD5** | `f0d5f751a24217980f18311d6bccad15` |
| **Smali files** | 172 |
| **Asset files** | 9 |
| **Decompile date** | 2026-07-19 05:57 UTC |

## Cấu trúc thư mục

| Thư mục | Nội dung |
|---------|----------|
| `manifest/` | AndroidManifest.xml, permissions, components |
| `smali-bridge/` | Bridge code (Java source + smali đã inject) |
| `smali-game-index/` | Index phân loại smali game theo chức năng |
| `assets-key/` | Index assets: DLL, metadata, config, audio |
| `res/` | Resources: strings, styles, colors |
| `lib-info/` | Danh sách native libraries (SO files) |
| `patch-scripts/` | Scripts patch server, manifest + rebuild guide |

## Khi cần nâng cấp

1. Xem **`smali-game-index/INDEX.md`** → tìm class cần sửa
2. Xem **`assets-key/ASSETS_INDEX.md`** → tìm asset cần patch
3. Sửa trong **`smali-bridge/java-src/`** nếu cần đổi bridge logic
4. Chạy workflow **`inject-apk.yml`** để build APK mới
5. Xem **`patch-scripts/REBUILD_GUIDE.md`** cho rebuild thủ công

## Bridge Architecture

```
Android APK
  └── BridgeProvider (ContentProvider — chạy trước Unity)
      ├── BridgePreference.applyServerPreset()
      │     └── Ghi NRlink2 + svselect → filesDir
      │           → Game tự connect 127.0.0.1:14445
      └── BridgeService (Foreground Service)
            └── TCP 14445 ←→ WebSocket → Codespace → Game Server
```
