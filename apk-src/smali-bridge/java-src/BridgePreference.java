package com.nro.bridge;

import android.content.Context;
import android.util.Log;
import java.io.DataOutputStream;
import java.io.File;
import java.io.FileOutputStream;

/**
 * BridgePreference — ghi preference server TRƯỚC khi Unity game đọc.
 *
 * Unity Rms.cs lưu data vào Application.persistentDataPath (= context.getFilesDir()):
 *   saveRMSString(key, val) → file key chứa DataOutputStream.writeUTF(val)
 *   saveRMSInt(key, x)      → file key chứa 1 byte = (sbyte)x
 *
 * "NRlink2" = server list dạng XOR-encoded hex string (key "69")
 *   Value cho "LocalHost:127.0.0.1:14445:0,0,0":
 *   "7A-56-55-58-5A-71-59-4A-42-03-07-0B-01-17-06-17-06-17-07-03-07-0D-02-0D-03-03-06-15-06-15-06"
 *   (XOR("LocalHost:127.0.0.1:14445:0,0,0", "69") → dash-separated hex)
 *
 * "svselect" = server index đã chọn, 1 byte = 0 (server đầu tiên)
 *
 * Kết quả: game load 1 server duy nhất → nameServer.Length == 1 → auto-connect
 */
public class BridgePreference {

    private static final String TAG = "NROBridge";

    /** XOR-encoded "LocalHost:127.0.0.1:14445:0,0,0" với key "69" */
    private static final String SINGLE_SERVER_ENCODED =
        "7A-56-55-58-5A-71-59-4A-42-03-07-0B-01-17-06-17-06-17-07-03-07-0D-02-0D-03-03-06-15-06-15-06";

    /**
     * Ghi file preference NGAY LẬP TỨC — luôn overwrite để đảm bảo auto-connect.
     * Gọi từ BridgeProvider.onCreate() (chạy trước mọi Activity Unity).
     */
    public static void applyServerPreset(Context ctx) {
        try {
            File filesDir = ctx.getFilesDir();
            if (!filesDir.exists()) {
                filesDir.mkdirs();
            }

            // ── Ghi "NRlink2" = DataOutputStream.writeUTF(SINGLE_SERVER_ENCODED) ──
            // writeUTF format: [2-byte big-endian length][UTF-8 bytes]
            File nrlink2 = new File(filesDir, "NRlink2");
            try (DataOutputStream dos = new DataOutputStream(new FileOutputStream(nrlink2, false))) {
                dos.writeUTF(SINGLE_SERVER_ENCODED);
            }

            // ── Ghi "svselect" = 1 byte = 0 (index server đầu tiên) ──
            // saveRMSInt dùng: saveRMS(file, new sbyte[1] { (sbyte)x })
            File svselect = new File(filesDir, "svselect");
            try (FileOutputStream fos = new FileOutputStream(svselect, false)) {
                fos.write(0);
            }

            Log.d(TAG, "Server preset OK: " + filesDir.getAbsolutePath()
                + " | NRlink2=" + nrlink2.length() + "B, svselect=" + svselect.length() + "B");

        } catch (Exception e) {
            Log.e(TAG, "Server preset failed: " + e);
        }
    }
}
