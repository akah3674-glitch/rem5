# Hướng dẫn Rebuild APK

## Cấu trúc apk-src/
```
apk-src/
├── manifest/           # AndroidManifest.xml + info
├── smali-bridge/       # Bridge code (com/nro/bridge)
│   ├── java-src/       # Java source gốc
│   ├── BridgeProvider.smali
│   ├── patch_server.py
│   └── patch_manifest.py
├── smali-game-index/   # INDEX.md — phân loại smali game
├── assets-key/         # ASSETS_INDEX.md, TOP_FILES.md
├── res/                # values/ (strings, styles)
├── lib-info/           # LIBS.md — danh sách native lib
└── patch-scripts/      # Scripts patch + rebuild
```

## Rebuild nhanh (GitHub Actions)

```
gh workflow run inject-apk.yml \
  --field ws_url="wss://YOUR-ENDPOINT" \
  --field release_tag="vX.Y.Z"
```

## Patch thủ công

```bash
# 1. Decompile
apktool d client.apk -o /tmp/game_src -f

# 2. Inject bridge smali
mkdir -p /tmp/game_src/smali/com/nro/bridge
cp apk-src/smali-bridge/BridgeProvider.smali /tmp/game_src/smali/com/nro/bridge/

# 3. Patch WS URL vào BridgeService.java
sed 's|__WS_URL__|wss://YOUR-URL|g' apk-src/smali-bridge/java-src/BridgeService.java > /tmp/BridgeService_patched.java

# 4. Patch server IP
python3 apk-src/patch-scripts/patch_server.py /tmp/game_src/smali /tmp/game_src/assets

# 5. Patch manifest
python3 apk-src/patch-scripts/patch_manifest.py /tmp/game_src/AndroidManifest.xml

# 6. Rebuild + sign
apktool b /tmp/game_src -o /tmp/rebuilt.apk
```

## Danh sách thay đổi đã apply
- v1.0-1.3: Bridge inject, Custom Server thủ công
- v1.4.0: BROKEN — corrupt Unity binary
- v1.5.0: fix binary corruption
- v1.6-1.7: thử patch IL2CPP/Mono
- v1.8.0: auto-connect qua filesDir injection
- v1.9.0: WS connect thẳng Codespace (bỏ Replit relay)
