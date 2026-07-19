package com.nro.bridge;

import android.content.*;
import android.database.Cursor;
import android.net.Uri;
import android.util.Log;

/**
 * ContentProvider trick — chạy trước Activity, dùng để auto-start BridgeService.
 * Android gọi onCreate() của tất cả ContentProvider trước khi mở bất kỳ Activity nào.
 * Đây là cách reliable nhất để inject code vào Unity app mà không sửa Activity.
 */
public class BridgeProvider extends ContentProvider {
    @Override
    public boolean onCreate() {
        try {
            Context ctx = getContext().getApplicationContext();
            android.content.Intent i = new android.content.Intent(ctx, BridgeService.class);
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                ctx.startForegroundService(i);
            } else {
                ctx.startService(i);
            }
            Log.i("NROBridge", "Auto-started BridgeService via ContentProvider");
        } catch (Exception e) {
            Log.e("NROBridge", "Failed to start: " + e);
        }
        return true;
    }

    // Các method bắt buộc — không dùng
    @Override public Cursor query(Uri u, String[] p, String s, String[] a, String o) { return null; }
    @Override public String getType(Uri u) { return null; }
    @Override public Uri insert(Uri u, ContentValues v) { return null; }
    @Override public int delete(Uri u, String s, String[] a) { return 0; }
    @Override public int update(Uri u, ContentValues v, String s, String[] a) { return 0; }
}
