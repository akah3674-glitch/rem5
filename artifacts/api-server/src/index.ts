import http from "node:http";
import net from "node:net";
import { WebSocketServer, WebSocket } from "ws";
import app from "./app";
import { logger } from "./lib/logger";
import { getWsUrl } from "./routes/wsUrl";

const rawPort = process.env["PORT"];

if (!rawPort) {
  throw new Error(
    "PORT environment variable is required but was not provided.",
  );
}

const port = Number(rawPort);

if (Number.isNaN(port) || port <= 0) {
  throw new Error(`Invalid PORT value: "${rawPort}"`);
}

// ── WebSocket relay server ────────────────────────────────────────────────────
const wss = new WebSocketServer({ noServer: true });

wss.on("connection", (clientWs) => {
  logger.info({ gameWsUrl: GAME_WS_URL }, "APK connected — opening relay to Codespace");

  // Queue messages từ APK trong lúc gameWs chưa OPEN
  // (Codespace WS cần ~150-300ms để mở — nếu drop sẽ mất game handshake)
  const pendingFromApk: Array<{ data: Buffer | string; isBinary: boolean }> = [];
  let relayReady = false;
  let closed = false;

  // Lấy URL mới nhất từ wsUrl store (keepalive Codespace cập nhật sau mỗi restart)
  const GAME_WS_URL = getWsUrl();
  const gameWs = new WebSocket(GAME_WS_URL, {
    handshakeTimeout: 15000,
  });

  const cleanup = (reason: string) => {
    if (closed) return;
    closed = true;
    logger.info({ reason }, "Relay closed");
    if (clientWs.readyState === WebSocket.OPEN) clientWs.close();
    if (gameWs.readyState === WebSocket.OPEN || gameWs.readyState === WebSocket.CONNECTING)
      gameWs.close();
  };

  gameWs.on("open", () => {
    logger.info(
      { queued: pendingFromApk.length },
      "Relay to Codespace established — flushing queued messages"
    );
    relayReady = true;

    // Flush tất cả data APK đã gửi trong lúc chờ
    for (const msg of pendingFromApk) {
      if (gameWs.readyState === WebSocket.OPEN) {
        gameWs.send(msg.data, { binary: msg.isBinary });
      }
    }
    pendingFromApk.length = 0;
  });

  // APK → Codespace
  clientWs.on("message", (data, isBinary) => {
    if (relayReady && gameWs.readyState === WebSocket.OPEN) {
      gameWs.send(data as Buffer, { binary: isBinary });
    } else if (!closed) {
      // Queue lại — gameWs chưa sẵn sàng
      pendingFromApk.push({ data: data as Buffer, isBinary });
      if (pendingFromApk.length === 1) {
        logger.debug("Queuing APK data while relay opens...");
      }
    }
  });

  // Codespace → APK
  gameWs.on("message", (data, isBinary) => {
    if (clientWs.readyState === WebSocket.OPEN) {
      clientWs.send(data as Buffer, { binary: isBinary });
    }
  });

  gameWs.on("error", (e) => {
    logger.error({ err: e.message }, "Codespace WS error");
    cleanup("game ws error");
  });
  gameWs.on("close", () => cleanup("game ws closed"));
  clientWs.on("error", (e) => {
    logger.error({ err: e.message }, "APK WS error");
    cleanup("apk ws error");
  });
  clientWs.on("close", () => {
    if (!closed) {
      logger.info("APK disconnected");
      cleanup("apk disconnected");
    }
  });
});

// ── HTTP server với WebSocket upgrade support ─────────────────────────────────
const server = http.createServer(app);

server.on("upgrade", (req, socket, head) => {
  const url = req.url ?? "";
  if (url === "/api/ws" || url.startsWith("/api/ws?")) {
    wss.handleUpgrade(req, socket as net.Socket, head, (ws) => {
      wss.emit("connection", ws, req);
    });
  } else {
    socket.destroy();
  }
});

server.listen(port, () => {
  logger.info({ port, gameWsUrl: GAME_WS_URL }, "Server listening — WS relay active");
});
