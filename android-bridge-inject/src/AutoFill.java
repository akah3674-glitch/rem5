package com.nro.bridge;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.TextView;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * AutoFill v3.0 — Quét TẤT CẢ windows (kể cả Dialog window riêng biệt)
 * bằng cách dùng WindowManagerGlobal.mViews reflection.
 *
 * Bug v2.0: chỉ quét Activity.getWindow().getDecorView() → KHÔNG tìm thấy
 * Dialog vì Dialog là một Window riêng biệt trong WindowManager.
 *
 * Fix: quét toàn bộ mViews trong WindowManagerGlobal → tìm thấy bất kỳ
 * window nào đang hiển thị, bao gồm cả Dialog, PopupWindow, etc.
 */
public class AutoFill {

    private static final String TAG          = "NROAutoFill";
    private static final String TARGET_IP    = "127.0.0.1";
    private static final String TARGET_PORT  = "15000";
    private static final int    INTERVAL_MS  = 200;
    private static final int    MAX_TRIES    = 75;   // 15 giây

    private static volatile boolean sRegistered = false;
    private static volatile boolean sDone       = false;

    /**
     * Gọi từ BridgeProvider.onCreate() — đăng ký + bắt đầu quét ngay lập tức.
     */
    public static void registerLifecycle(Application app) {
        if (sRegistered) return;
        sRegistered = true;

        final Handler h = new Handler(Looper.getMainLooper());

        // Bắt đầu quét ngay, không chờ Activity start
        scheduleCheck(h, 0);

        // Cũng hook vào Activity lifecycle làm backup trigger
        app.registerActivityLifecycleCallbacks(new Application.ActivityLifecycleCallbacks() {
            @Override
            public void onActivityStarted(Activity a) {
                if (!sDone) scheduleCheck(h, 0);
            }
            @Override
            public void onActivityResumed(Activity a) {
                if (!sDone) scheduleCheck(h, 0);
            }
            @Override public void onActivityCreated(Activity a, Bundle b) {}
            @Override public void onActivityPaused(Activity a)             {}
            @Override public void onActivityStopped(Activity a)            {}
            @Override public void onActivitySaveInstanceState(Activity a, Bundle b) {}
            @Override public void onActivityDestroyed(Activity a)          {}
        });
    }

    // ── Quét định kỳ ────────────────────────────────────────────
    private static void scheduleCheck(final Handler h, final int attempt) {
        if (sDone || attempt >= MAX_TRIES) return;
        h.postDelayed(new Runnable() {
            @Override public void run() {
                if (sDone) return;
                try {
                    if (tryFillAllWindows()) {
                        sDone = true;
                        Log.i(TAG, "AutoFill OK (attempt=" + attempt + ")");
                        return;
                    }
                } catch (Exception e) {
                    Log.d(TAG, "attempt=" + attempt + " err=" + e.getMessage());
                }
                scheduleCheck(h, attempt + 1);
            }
        }, INTERVAL_MS);
    }

    /**
     * Quét TẤT CẢ windows trong WindowManagerGlobal.mViews.
     * Đây là cách duy nhất để tìm Dialog window — vì Dialog KHÔNG nằm
     * trong Activity.getWindow().getDecorView().
     */
    private static boolean tryFillAllWindows() throws Exception {
        // Lấy WindowManagerGlobal singleton
        Class<?> wmGlobal = Class.forName("android.view.WindowManagerGlobal");
        Method getInstance = wmGlobal.getDeclaredMethod("getInstance");
        getInstance.setAccessible(true);
        Object wm = getInstance.invoke(null);

        // Lấy danh sách tất cả root views
        Field mViewsField = wmGlobal.getDeclaredField("mViews");
        mViewsField.setAccessible(true);
        Object rawViews = mViewsField.get(wm);

        List<View> allViews = new ArrayList<>();
        if (rawViews instanceof List) {
            for (Object v : (List<?>) rawViews) {
                if (v instanceof View) allViews.add((View) v);
            }
        }

        for (View root : allViews) {
            if (root == null) continue;
            if (tryFillInView(root)) return true;
        }
        return false;
    }

    private static boolean tryFillInView(View root) {
        List<EditText> editTexts = new ArrayList<>();
        List<View>     clickable = new ArrayList<>();
        collectViews(root, editTexts, clickable);

        if (editTexts.size() < 2) return false;

        Log.i(TAG, "Found " + editTexts.size() + " EditTexts in window "
                + root.getClass().getSimpleName());

        // Điền IP và Port
        editTexts.get(0).setText(TARGET_IP);
        editTexts.get(1).setText(TARGET_PORT);
        Log.i(TAG, "Set IP=" + TARGET_IP + " Port=" + TARGET_PORT);

        // Tìm nút OK
        for (View v : clickable) {
            String label = getLabel(v);
            if (isOkLabel(label)) {
                Log.i(TAG, "Clicking: " + label);
                v.performClick();
                return true;
            }
        }

        // Fallback: click view clickable đầu tiên (nút OK thường ở cuối)
        if (!clickable.isEmpty()) {
            View last = clickable.get(clickable.size() - 1);
            Log.i(TAG, "Fallback click: " + getLabel(last));
            last.performClick();
            return true;
        }
        return false;
    }

    private static String getLabel(View v) {
        if (v instanceof TextView) {
            CharSequence cs = ((TextView) v).getText();
            return cs != null ? cs.toString().trim() : "";
        }
        if (v.getContentDescription() != null) {
            return v.getContentDescription().toString().trim();
        }
        return "";
    }

    private static boolean isOkLabel(String s) {
        if (s == null || s.isEmpty()) return false;
        String l = s.toLowerCase();
        return l.equals("ok")
            || l.contains("k\u1ebft")    // Kết nối
            || l.contains("x\u00e1c")    // Xác nhận
            || l.contains("connect")
            || l.contains("confirm")
            || l.contains("done");
    }

    /**
     * Đệ quy thu thập EditText và View clickable.
     * Không lọc theo visibility — dialog EditText đôi khi vẫn INVISIBLE khi thu thập.
     */
    private static void collectViews(View v, List<EditText> texts, List<View> clickable) {
        if (v == null) return;

        if (v instanceof EditText) {
            texts.add((EditText) v);
            return;
        }

        // Thu thập View có thể click (Button, TextView với click listener, etc.)
        if (v.isClickable() || v.hasOnClickListeners()) {
            String label = getLabel(v);
            if (!label.isEmpty()) {
                clickable.add(v);
            }
        }

        if (v instanceof ViewGroup) {
            ViewGroup g = (ViewGroup) v;
            for (int i = 0; i < g.getChildCount(); i++) {
                collectViews(g.getChildAt(i), texts, clickable);
            }
        }
    }
}
