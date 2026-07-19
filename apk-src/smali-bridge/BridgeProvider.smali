# BridgeProvider.smali — viết tay, không cần baksmali
# ContentProvider trick: onCreate() chạy trước mọi Activity của Unity
# 1. Gọi BridgePreference.applyServerPreset() → ghi NRlink2 + svselect → auto-connect
# 2. Start BridgeService (foreground service, relay TCP→WS)

.class public Lcom/nro/bridge/BridgeProvider;
.super Landroid/content/ContentProvider;
.source "BridgeProvider.java"

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/content/ContentProvider;-><init>()V
    return-void
.end method

.method public onCreate()Z
    .registers 5

    :try_start

    # ── 1. Lấy context ────────────────────────────────────────
    invoke-virtual {p0}, Lcom/nro/bridge/BridgeProvider;->getContext()Landroid/content/Context;
    move-result-object v0
    invoke-virtual {v0}, Landroid/content/Context;->getApplicationContext()Landroid/content/Context;
    move-result-object v0

    # ── 2. Pre-set server preference → auto-connect ──────────
    # Ghi NRlink2 (server list = 1 server: LocalHost:127.0.0.1:14445)
    # và svselect = 0 vào filesDir trước khi Unity đọc
    invoke-static {v0}, Lcom/nro/bridge/BridgePreference;->applyServerPreset(Landroid/content/Context;)V

    # ── 3. Start BridgeService (TCP→WS relay) ────────────────
    new-instance v1, Landroid/content/Intent;
    const-class v2, Lcom/nro/bridge/BridgeService;
    invoke-direct {v1, v0, v2}, Landroid/content/Intent;-><init>(Landroid/content/Context;Ljava/lang/Class;)V
    invoke-virtual {v0, v1}, Landroid/content/Context;->startForegroundService(Landroid/content/Intent;)Landroid/content/ComponentName;

    :try_end
    .catch Ljava/lang/Exception; {:try_start .. :try_end} :catch_all

    :return_true
    const/4 v0, 0x1
    return v0

    :catch_all
    move-exception v0
    const/4 v0, 0x1
    return v0
.end method

# ── Stub methods (abstract trong ContentProvider) ──────────

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
