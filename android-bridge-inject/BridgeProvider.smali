# BridgeProvider.smali — ContentProvider chạy trước mọi Activity Unity
# 1. AutoFill.registerLifecycle() — quét tất cả windows, tự điền IP/Port dialog
# 2. BridgePreference.applyServerPreset() — ghi NRlink2 = 1 server → auto-connect
# 3. Start BridgeService (foreground TCP relay → WSS)

.class public Lcom/nro/bridge/BridgeProvider;
.super Landroid/content/ContentProvider;
.source "BridgeProvider.java"

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/content/ContentProvider;-><init>()V
    return-void
.end method

.method public onCreate()Z
    .registers 6

    :try_start

    # ── 1. Lấy ApplicationContext ─────────────────────────────
    invoke-virtual {p0}, Lcom/nro/bridge/BridgeProvider;->getContext()Landroid/content/Context;
    move-result-object v0
    invoke-virtual {v0}, Landroid/content/Context;->getApplicationContext()Landroid/content/Context;
    move-result-object v0

    # ── 2. AutoFill: quét ALL windows, tự điền IP/Port và click OK ──
    # Dùng WindowManagerGlobal.mViews reflection để tìm cả Dialog windows
    check-cast v0, Landroid/app/Application;
    invoke-static {v0}, Lcom/nro/bridge/AutoFill;->registerLifecycle(Landroid/app/Application;)V

    # ── 3. BridgePreference: ghi NRlink2 = 1 server (LocalHost:127.0.0.1:15000) ──
    # nameServer.Length == 1 → Unity tự connect, không hiện dialog
    invoke-static {v0}, Lcom/nro/bridge/BridgePreference;->applyServerPreset(Landroid/content/Context;)V

    # ── 4. Start BridgeService (TCP relay 15000 → WSS cloud) ─────
    new-instance v1, Landroid/content/Intent;
    const-class v2, Lcom/nro/bridge/BridgeService;
    invoke-direct {v1, v0, v2}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V

    # Android 8+ cần startForegroundService; BridgeService gọi startForeground() trong 5s
    sget v3, Landroid/os/Build$VERSION;->SDK_INT:I
    const/16 v4, 0x1a    # API 26 = Android 8.0
    if-lt v3, v4, :start_compat
    invoke-virtual {v0, v1}, Landroid/content/Context;->startForegroundService(Landroid/content/Intent;)Landroid/content/ComponentName;
    goto :done_start
    :start_compat
    invoke-virtual {v0, v1}, Landroid/content/Context;->startService(Landroid/content/Intent;)Landroid/content/ComponentName;
    :done_start

    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :catch_all

    :return_true
    const/4 v0, 0x1
    return v0

    :catch_all
    move-exception v0
    # Lỗi silent — không crash game
    const/4 v0, 0x1
    return v0
.end method

# ── Stub methods bắt buộc (abstract trong ContentProvider) ──────────

.method public query(Landroid/net/Uri;[Ljava/lang/String;Landroid/os/Bundle;Landroid/os/CancellationSignal;)Landroid/database/Cursor;
    .registers 6
    const/4 v0, 0x0
    return-object v0
.end method

.method public query(Landroid/net/Uri;[Ljava/lang/String;Ljava/lang/String;[Ljava/lang/String;Ljava/lang/String;)Landroid/database/Cursor;
    .registers 7
    const/4 v0, 0x0
    return-object v0
.end method

.method public getType(Landroid/net/Uri;)Ljava/lang/String;
    .registers 2
    const/4 v0, 0x0
    return-object v0
.end method

.method public insert(Landroid/net/Uri;Landroid/content/ContentValues;)Landroid/net/Uri;
    .registers 3
    const/4 v0, 0x0
    return-object v0
.end method

.method public delete(Landroid/net/Uri;Ljava/lang/String;[Ljava/lang/String;)I
    .registers 4
    const/4 v0, 0x0
    return v0
.end method

.method public update(Landroid/net/Uri;Landroid/content/ContentValues;Ljava/lang/String;[Ljava/lang/String;)I
    .registers 5
    const/4 v0, 0x0
    return v0
.end method
