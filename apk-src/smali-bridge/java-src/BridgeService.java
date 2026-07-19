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
import java.nio.charset.Charset;
import java.util.concurrent.*;
import javax.net.ssl.SSLSocketFactory;

/**
 * NRO WebSocket Bridge — pure Java, no lambdas, no external deps.
 * Tự start khi game mở (qua BridgeProvider ContentProvider).
 * Lắng nghe TCP 127.0.0.1:14445 → WebSocket → cloud game server.
 */
public class BridgeService extends Service {

    static final String TAG = "NROBridge";
    static final int LOCAL_PORT = 14445;
    static final String CHANNEL_ID = "nro_bridge";
    static final int NOTIF_ID = 9001;

    // URL sẽ được thay bằng sed trước khi compile
    static final String WS_URL = "__WS_URL__";

    private ServerSocket serverSocket;
    private ExecutorService pool;
    private volatile boolean running;

    @Override
    public IBinder onBind(Intent i) { return null; }

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
            Notification.Builder b;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                b = new Notification.Builder(this, CHANNEL_ID);
            } else {
                b = new Notification.Builder(this);
            }
            startForeground(NOTIF_ID, b
                .setContentTitle("NRO")
                .setContentText("Bridge active")
                .setSmallIcon(android.R.drawable.stat_sys_download)
                .build());
            pool.submit(new AcceptTask());
            Log.i(TAG, "Bridge started → " + WS_URL);
        }
        return START_STICKY;
    }

    // ── AcceptTask: lắng nghe kết nối từ game ─────────────
    private class AcceptTask implements Runnable {
        public void run() {
            try {
                serverSocket = new ServerSocket(LOCAL_PORT, 50,
                    InetAddress.getByName("127.0.0.1"));
                Log.i(TAG, "Listening 127.0.0.1:" + LOCAL_PORT);
                while (running) {
                    final Socket client = serverSocket.accept();
                    pool.submit(new BridgeTask(client));
                }
            } catch (Exception e) {
                if (running) Log.e(TAG, "Accept: " + e);
            }
        }
    }

    // ── BridgeTask: relay 1 kết nối game ↔ WebSocket ──────
    private class BridgeTask implements Runnable {
        private final Socket tcp;
        BridgeTask(Socket tcp) { this.tcp = tcp; }

        public void run() {
            Socket ws = null;
            try {
                // Parse wss://host[:port]/path
                String url = WS_URL;
                boolean tls = url.startsWith("wss://");
                String rest = url.substring(tls ? 6 : 5);
                int slashIdx = rest.indexOf('/');
                String hostPort = slashIdx >= 0 ? rest.substring(0, slashIdx) : rest;
                String path = slashIdx >= 0 ? rest.substring(slashIdx) : "/";
                int colonIdx = hostPort.lastIndexOf(':');
                String host;
                int port;
                if (colonIdx > 0) {
                    host = hostPort.substring(0, colonIdx);
                    port = Integer.parseInt(hostPort.substring(colonIdx + 1));
                } else {
                    host = hostPort;
                    port = tls ? 443 : 80;
                }

                // Mở socket tới cloud
                if (tls) {
                    ws = SSLSocketFactory.getDefault().createSocket(host, port);
                } else {
                    ws = new Socket(host, port);
                }
                ws.setTcpNoDelay(true);

                // WebSocket handshake
                String key = base64Encode(("NROKey" + System.currentTimeMillis()).getBytes("UTF-8"));
                OutputStream wsOut = ws.getOutputStream();
                String handshake =
                    "GET " + path + " HTTP/1.1\r\n" +
                    "Host: " + host + "\r\n" +
                    "Upgrade: websocket\r\n" +
                    "Connection: Upgrade\r\n" +
                    "Sec-WebSocket-Key: " + key + "\r\n" +
                    "Sec-WebSocket-Version: 13\r\n\r\n";
                wsOut.write(handshake.getBytes("US-ASCII"));
                wsOut.flush();

                // Bỏ qua response header (đọc đến \r\n\r\n)
                InputStream wsIn = ws.getInputStream();
                byte[] hdrBuf = new byte[4096];
                int hLen = 0;
                int b;
                while ((b = wsIn.read()) != -1 && hLen < hdrBuf.length) {
                    hdrBuf[hLen++] = (byte) b;
                    if (hLen >= 4 &&
                        hdrBuf[hLen-4] == '\r' && hdrBuf[hLen-3] == '\n' &&
                        hdrBuf[hLen-2] == '\r' && hdrBuf[hLen-1] == '\n') break;
                }
                String hdrStr = new String(hdrBuf, 0, hLen, "US-ASCII");
                if (!hdrStr.contains("101")) {
                    Log.e(TAG, "WS handshake failed: " + hdrStr.substring(0, Math.min(80, hdrStr.length())));
                    close(tcp); close(ws); return;
                }
                Log.i(TAG, "WS connected: " + host + ":" + port);

                // Relay dữ liệu
                final InputStream gameIn = tcp.getInputStream();
                final OutputStream gameOut = tcp.getOutputStream();
                final Socket wsRef = ws;
                final OutputStream wsOutFinal = wsOut;
                final InputStream wsInFinal = wsIn;

                // Thread game → cloud
                pool.submit(new Runnable() {
                    public void run() {
                        try {
                            byte[] buf = new byte[65536];
                            int len;
                            while ((len = gameIn.read(buf)) > 0) {
                                wsSend(wsOutFinal, buf, len);
                            }
                        } catch (Exception e) {
                            Log.d(TAG, "g→c: " + e);
                        } finally {
                            close(wsRef);
                        }
                    }
                });

                // Thread cloud → game (đọc WebSocket frames)
                try {
                    while (true) {
                        int b0 = wsInFinal.read();
                        int b1 = wsInFinal.read();
                        if (b0 == -1 || b1 == -1) break;
                        int opcode = b0 & 0x0F;
                        if (opcode == 8) break; // CLOSE
                        boolean masked = (b1 & 0x80) != 0;
                        long paylen = b1 & 0x7F;
                        if (paylen == 126) {
                            paylen = ((long)(wsInFinal.read() & 0xFF) << 8)
                                   |  (wsInFinal.read() & 0xFF);
                        } else if (paylen == 127) {
                            paylen = 0;
                            for (int i = 0; i < 8; i++)
                                paylen = (paylen << 8) | (wsInFinal.read() & 0xFF);
                        }
                        byte[] maskKey = new byte[4];
                        if (masked) wsInFinal.read(maskKey);
                        byte[] payload = new byte[(int) paylen];
                        int read = 0;
                        while (read < payload.length) {
                            int r = wsInFinal.read(payload, read, payload.length - read);
                            if (r == -1) break;
                            read += r;
                        }
                        if (masked) {
                            for (int i = 0; i < read; i++) {
                                payload[i] ^= maskKey[i % 4];
                            }
                        }
                        gameOut.write(payload, 0, read);
                        gameOut.flush();
                    }
                } catch (Exception e) {
                    Log.d(TAG, "c→g: " + e);
                }

            } catch (Exception e) {
                Log.e(TAG, "Bridge: " + e);
            } finally {
                close(tcp);
                if (ws != null) close(ws);
            }
        }
    }

    // ── Gửi binary WebSocket frame (masked, server cần mask) ─
    private void wsSend(OutputStream out, byte[] data, int len) throws IOException {
        ByteArrayOutputStream frame = new ByteArrayOutputStream(len + 10);
        frame.write(0x82); // FIN + binary opcode
        byte[] mask = {
            (byte)((len    ) & 0xFF),
            (byte)((len>> 8) & 0xFF),
            (byte)((len>>16) & 0xFF),
            (byte)(0x42),
        };
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
        for (int i = 0; i < len; i++) {
            frame.write(data[i] ^ mask[i % 4]);
        }
        out.write(frame.toByteArray());
        out.flush();
    }

    // ── Base64 đơn giản (tránh dùng java.util.Base64 để tương thích) ─
    private static final String B64 =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    private String base64Encode(byte[] in) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < in.length; i += 3) {
            int b0 = in[i] & 0xFF;
            int b1 = (i+1 < in.length) ? (in[i+1] & 0xFF) : 0;
            int b2 = (i+2 < in.length) ? (in[i+2] & 0xFF) : 0;
            sb.append(B64.charAt(b0 >> 2));
            sb.append(B64.charAt(((b0 & 3) << 4) | (b1 >> 4)));
            sb.append((i+1 < in.length) ? B64.charAt(((b1 & 0xF) << 2) | (b2 >> 6)) : '=');
            sb.append((i+2 < in.length) ? B64.charAt(b2 & 0x3F) : '=');
        }
        return sb.toString();
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
