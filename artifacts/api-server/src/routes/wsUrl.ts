import { Router } from "express";

const router = Router();

// URL hiện tại của Cloudflare tunnel — cập nhật bởi Codespace keepalive
let currentWsUrl: string =
  process.env["GAME_WS_URL"] ||
  "wss://salon-rankings-locks-separation.trycloudflare.com";

const UPDATE_SECRET = process.env["SESSION_SECRET"] || "dev-secret";

/** GET /api/ws-url — APK fetch URL khi khởi động */
router.get("/ws-url", (_req, res) => {
  res.json({ url: currentWsUrl, updatedAt: new Date().toISOString() });
});

/** POST /api/ws-url — Codespace keepalive cập nhật URL mới */
router.post("/ws-url", (req, res) => {
  const secret = req.headers["x-update-secret"] || req.body?.secret;
  if (secret !== UPDATE_SECRET) {
    res.status(403).json({ error: "forbidden" });
    return;
  }
  const { url } = req.body;
  if (!url || !url.startsWith("wss://")) {
    res.status(400).json({ error: "invalid url — must start with wss://" });
    return;
  }
  currentWsUrl = url;
  console.log(`[ws-url] Updated → ${url}`);
  res.json({ ok: true, url: currentWsUrl });
});

/** Dùng getter để index.ts lấy URL mới nhất tại thời điểm connection */
export function getWsUrl(): string { return currentWsUrl; }
export default router;
