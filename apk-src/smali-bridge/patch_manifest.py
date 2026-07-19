#!/usr/bin/env python3
"""
Patch AndroidManifest.xml sau khi apktool decompile.
Thêm BridgeService + BridgeProvider vào manifest của game.
"""
import sys, re

manifest_path = sys.argv[1]
text = open(manifest_path, encoding='utf-8').read()

# Kiểm tra đã inject chưa
if 'com.nro.bridge' in text:
    print("✅ Manifest đã có bridge code, bỏ qua.")
    sys.exit(0)

# Thêm FOREGROUND_SERVICE permission nếu chưa có
if 'FOREGROUND_SERVICE"' not in text and 'FOREGROUND_SERVICE/' not in text:
    text = text.replace(
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>'
    )

# Android 14+ (API 34): FOREGROUND_SERVICE_DATA_SYNC bắt buộc khi dùng foregroundServiceType="dataSync"
if 'FOREGROUND_SERVICE_DATA_SYNC' not in text:
    # Thêm sau FOREGROUND_SERVICE hoặc sau INTERNET
    if 'android.permission.FOREGROUND_SERVICE"' in text:
        text = text.replace(
            '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>',
            '<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n'
            '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>'
        )
    else:
        text = text.replace(
            '<uses-permission android:name="android.permission.INTERNET"/>',
            '<uses-permission android:name="android.permission.INTERNET"/>\n'
            '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n'
            '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"/>'
        )

# Inject service + provider vào cuối thẻ <application> (trước </application>)
inject = '''
        <!-- NRO Bridge — injected -->
        <service
            android:name="com.nro.bridge.BridgeService"
            android:exported="false"
            android:foregroundServiceType="dataSync"/>
        <provider
            android:name="com.nro.bridge.BridgeProvider"
            android:authorities="com.DefaultCompany.DragonBoy11.nrobridge"
            android:exported="false"/>'''

text = text.replace('</application>', inject + '\n    </application>')

open(manifest_path, 'w', encoding='utf-8').write(text)
print("✅ Manifest patched: FOREGROUND_SERVICE_DATA_SYNC + BridgeService + BridgeProvider added")
