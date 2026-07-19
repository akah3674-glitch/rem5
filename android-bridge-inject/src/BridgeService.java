package com.nro.bridge;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.concurrent.*;
import javax.net.ssl.SSLSocketFactory;

/**
 * NRO WebSocket Bridge — pure Java, no external deps.
 * Chạy trong game APK, tự start khi game mở.
 * Lắng nghe TCP 127.0.0.1:14445 → tunnel qua WebSocket → cloud game server.
 */
public class BridgeService extends Service {
    static final String TAG = "NROBridge";
    static final int LOCAL_PORT = 14445;
    static final String CHANNEL_ID = "nro_bridge";
    static final int NOTIF_ID = 9001;

    // ═══════════════════════════════════════════════════════
    // URL WebSocket của Codespace / Replit — thay trước khi build
    // ═══════════════════════════════════════════════════════
    static final String WS_URL = "__WS_URL__";

    private ServerSocket serverSocket;
    private ExecutorService pool;
    private volatile boolean running;

    @Override public IBinder onBind(Intent i) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        pool = Executors.newCachedThreadPool();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel ch = new NotificationChannel(
                CHANNEL_ID, "NRO Bridge", NotificationManager.IMPORTANCE_MIN);
            ((NotificationManager) getSystemService(NOTIFICATION_SERVICE))
                .createNotificationChannel(ch);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (!running) {
            running = true;
            Notification.Builder b = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
            startForeground(NOTIF_ID, b
                .setContentTitle("NRO")
                .setContentText("Bridge active")
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .build());
            pool.submit(this::acceptLoop);
            Log.i(TAG, "Bridge started → " + WS_URL);
        }
        return START_STICKY;
    }

    private void acceptLoop() {
        try {
            serverSocket = new ServerSocket(LOCAL_PORT, 50,
                InetAddress.getByName("127.0.0.1"));
            Log.i(TAG, "Listening 127.0.0.1:" + LOCAL_PORT);
            while (running) {
                Socket client = serverSocket.accept();
                pool.submit(() -> bridge(client));
            }
        } catch (Exception e) {
            if (running) Log.e(TAG, "Accept: " + e);
        }
    }

    private void bridge(Socket tcp) {
        try {
            // Parse wss://host:port/path
            URI uri = new URI(WS_URL);
            String host = uri.getHost();
            int port = uri.getPort() == -1
                ? (WS_URL.startsWith("wss") ? 443 : 80)
                : uri.getPort();
            String path = uri.getRawPath().isEmpty() ? "/" : uri.getRawPath();
            boolean tls = WS_URL.startsWith("wss");

            // TCP → cloud
            Socket ws = tls
                ? SSLSocketFactory.getDefault().createSocket(host, port)
                : new Socket(host, port);
            ws.setTcpNoDelay(true);

            // WebSocket handshake
            String key = Base64.getEncoder().encodeToString(
                ("NROKey" + System.currentTimeMillis()).getBytes());
            OutputStream wsOut = ws.getOutputStream();
            wsOut.write((
                "GET " + path + " HTTP/1.1\r\n" +
                "Host: " + host + "\r\n" +
                "Upgrade: websocket\r\n" +
                "Connection: Upgrade\r\n" +
                "Sec-WebSocket-Key: " + key + "\r\n" +
                "Sec-WebSocket-Version: 13\r\n\r\n"
            ).getBytes(StandardCharsets.US_ASCII));
            wsOut.flush();

            // Read 101 response
            InputStream wsIn = ws.getInputStream();
            StringBuilder hdr = new StringBuilder();
            int prev = 0, c;
            while ((c = wsIn.read()) != -1) {
                hdr.append((char) c);
                if (prev == '\r' && c == '\n' &&
                    hdr.toString().endsWith("\r\n\r\n")) break;
                prev = c;
            }
            if (!hdr.toString().contains("101")) {
                Log.e(TAG, "WS handshake failed: " + hdr);
                tcp.close(); ws.close(); return;
            }
            Log.i(TAG, "WS connected to " + host + ":" + port);

            // Relay: game TCP ↔ WebSocket
            InputStream gameIn  = tcp.getInputStream();
            OutputStream gameOut = tcp.getOutputStream();

            pool.submit(() -> {
                // game → cloud  (WebSocket binary frames, masked)
                try {
                    byte[] buf = new byte[65536];
                    int len;
                    while ((len = gameIn.read(buf)) > 0)
                        wsSend(wsOut, buf, len);
                } catch (Exception e) { Log.d(TAG, "g→c: " + e); }
                finally { close(ws); }
            });

            // cloud → game  (read WebSocket frames, strip header)
            try {
                while (true) {
                    int b0 = wsIn.read(), b1 = wsIn.read();
                    if (b0 == -1 || b1 == -1) break;
                    boolean fin  = (b0 & 0x80) != 0;
                    int opcode   = b0 & 0x0F;
                    if (opcode == 8) break; // CLOSE
                    boolean mask = (b1 & 0x80) != 0;
                    long paylen  = b1 & 0x7F;
                    if (paylen == 126) {
                        paylen = ((wsIn.read() & 0xFF) << 8) | (wsIn.read() & 0xFF);
                    } else if (paylen == 127) {
                        paylen = 0;
                        for (int i = 0; i < 8; i++)
                            paylen = (paylen << 8) | (wsIn.read() & 0xFF);
                    }
                    byte[] maskKey = mask ? new byte[4] : null;
                    if (mask) wsIn.read(maskKey);

                    byte[] payload = new byte[(int) paylen];
                    int read = 0;
                    while (read < payload.length) {
                        int r = wsIn.read(payload, read, payload.length - read);
                        if (r == -1) break;
                        read += r;
                    }
                    if (mask)
                        for (int i = 0; i < read; i++)
                            payload[i] ^= maskKey[i % 4];

                    gameOut.write(payload, 0, read);
                    gameOut.flush();
                }
            } catch (Exception e) { Log.d(TAG, "c→g: " + e); }
            finally { close(tcp); close(ws); }

        } catch (Exception e) {
            Log.e(TAG, "Bridge error: " + e);
            close(tcp);
        }
    }

    /** Gửi binary WebSocket frame (masked) */
    private void wsSend(OutputStream out, byte[] data, int len) throws IOException {
        // Mask key random
        byte[] mask = {
            (byte)(System.nanoTime() & 0xFF),
            (byte)((System.nanoTime() >> 8) & 0xFF),
            (byte)((System.nanoTime() >> 16) & 0xFF),
            (byte)((System.nanoTime() >> 24) & 0xFF),
        };
        ByteArrayOutputStream frame = new ByteArrayOutputStream(len + 10);
        frame.write(0x82); // FIN + binary
        if (len <= 125) {
            frame.write(0x80 | len);
        } else if (len <= 65535) {
            frame.write(0x80 | 126);
            frame.write((len >> 8) & 0xFF);
            frame.write(len & 0xFF);
        } else {
            frame.write(0x80 | 127);
            for (int i = 7; i >= 0; i--)
                frame.write((len >> (i * 8)) & 0xFF);
        }
        frame.write(mask);
        for (int i = 0; i < len; i++)
            frame.write(data[i] ^ mask[i % 4]);
        out.write(frame.toByteArray());
        out.flush();
    }

    private void close(Closeable c) {
        try { if (c != null) c.close(); } catch (Exception ignored) {}
    }

    @Override
    public void onDestroy() {
        running = false;
        close(serverSocket);
        if (pool != null) pool.shutdownNow();
        super.onDestroy();
    }
}
