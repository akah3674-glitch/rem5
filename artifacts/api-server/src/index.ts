import http from "node:http";
import net from "node:net";
import { WebSocketServer, WebSocket } from "ws";
import app from "./app";
import { logger } from "./lib/logger";

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

// URL WebSocket của Codespace — đặt trong env để đổi mà không cần rebuild APK
const GAME_WS_URL =
  process.env["GAME_WS_URL"] ||
  "wss://cautious-space-halibut-p7rwgqwxrg5gfrrqg-8080.app.github.dev";

// ── WebSocket relay server ────────────────────────────────────────────────────
// APK kết nối tới /api/ws → relay bidirectional qua WebSocket tới Codespace
// Codespace ws_bridge_server.py nhận và forward TCP → Game Server local
// Không dùng raw TCP xuyên internet
const wss = new WebSocketServer({ noServer: true });

wss.on("connection", (clientWs) => {
  logger.info({ gameWsUrl: GAME_WS_URL }, "APK connected — opening relay to Codespace");

  const gameWs = new WebSocket(GAME_WS_URL, {
    handshakeTimeout: 10000,
    // Không cần headers đặc biệt
  });

  gameWs.binaryType = "nodebuffer";

  // APK → Codespace
  clientWs.on("message", (data, isBinary) => {
    if (gameWs.readyState === WebSocket.OPEN) {
      gameWs.send(data, { binary: isBinary });
    }
  });

  // Codespace → APK
  gameWs.on("message", (data, isBinary) => {
    if (clientWs.readyState === WebSocket.OPEN) {
      clientWs.send(data, { binary: isBinary });
    }
  });

  const cleanup = (reason: string) => {
    logger.info({ reason }, "Relay closed");
    if (clientWs.readyState === WebSocket.OPEN) clientWs.close();
    if (gameWs.readyState === WebSocket.OPEN) gameWs.close();
  };

  gameWs.on("open", () => logger.info("Relay to Codespace established"));
  gameWs.on("error", (e) => {
    logger.error({ err: e.message }, "Codespace WS error");
    cleanup("game ws error");
  });
  gameWs.on("close", () => cleanup("game ws closed"));
  clientWs.on("error", (e) => {
    logger.error({ err: e.message }, "APK WS error");
    cleanup("apk ws error");
  });
  clientWs.on("close", () => cleanup("apk disconnected"));
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
