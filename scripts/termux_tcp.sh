#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  NRO TCP Tunnel Tool for Termux
#  Tạo TCP tunnel từ Android ra internet (không cần public IP)
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

GAME_PORT=${GAME_PORT:-14445}
LOG_DIR="$HOME/logs"
BIN_DIR="$HOME/bin"
mkdir -p "$LOG_DIR" "$BIN_DIR"

banner() {
  echo -e "${CYAN}${BOLD}"
  echo "  ╔══════════════════════════════════╗"
  echo "  ║   NRO TCP Tunnel — Termux Tool   ║"
  echo "  ╚══════════════════════════════════╝${NC}"
  echo ""
}

ok()   { echo -e "  ${GREEN}✅ $*${NC}"; }
err()  { echo -e "  ${RED}❌ $*${NC}"; }
info() { echo -e "  ${YELLOW}→  $*${NC}"; }
sep()  { echo -e "  ${BLUE}────────────────────────────────────${NC}"; }

# ── Kiểm tra/cài package ────────────────────────────────────
check_deps() {
  info "Kiểm tra dependencies..."
  local missing=()
  for pkg in curl wget openssh; do
    command -v $pkg &>/dev/null || missing+=($pkg)
  done
  if [ ${#missing[@]} -gt 0 ]; then
    info "Cài: ${missing[*]}"
    pkg install -y "${missing[@]}" 2>/dev/null
  fi
  ok "Dependencies OK"
}

# ── Download playit v0.15.0 ──────────────────────────────────
setup_playit() {
  local bin="$BIN_DIR/playit"
  if [ ! -f "$bin" ]; then
    info "Download playit v0.15.0 (ARM64)..."
    # Thử ARM64 trước, fallback ARM
    wget -q "https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-aarch64" \
         -O "$bin" 2>/dev/null \
    || wget -q "https://github.com/playit-cloud/playit-agent/releases/download/v0.15.0/playit-linux-armv7" \
         -O "$bin" 2>/dev/null
    chmod +x "$bin"
    [ -f "$bin" ] && ok "playit downloaded" || { err "Download thất bại"; return 1; }
  else
    ok "playit đã có sẵn"
  fi
}

# ── Download frpc ────────────────────────────────────────────
setup_frpc() {
  local bin="$BIN_DIR/frpc"
  local cfg="$HOME/frpc_nro.toml"
  if [ ! -f "$bin" ]; then
    info "Download frpc v0.61.0 (ARM64)..."
    wget -q "https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_arm64.tar.gz" \
         -O /tmp/frp.tar.gz 2>/dev/null \
    || wget -q "https://github.com/fatedier/frp/releases/download/v0.61.0/frp_0.61.0_linux_arm.tar.gz" \
         -O /tmp/frp.tar.gz 2>/dev/null
    tar -xzf /tmp/frp.tar.gz -C /tmp/ 2>/dev/null
    find /tmp -name "frpc" -type f 2>/dev/null | head -1 | xargs -I{} cp {} "$bin"
    chmod +x "$bin" 2>/dev/null
    rm -f /tmp/frp.tar.gz
    [ -f "$bin" ] && ok "frpc downloaded" || { err "Download thất bại"; return 1; }
  else
    ok "frpc đã có sẵn"
  fi

  # Tạo config nếu chưa có
  if [ ! -f "$cfg" ]; then
    cat > "$cfg" << EOF
serverAddr = "frp.freefrp.net"
serverPort = 7000
auth.method = "token"
auth.token = "freefrp.net"

[[proxies]]
name = "nro-termux-$(date +%s)"
type = "tcp"
localIP = "127.0.0.1"
localPort = $GAME_PORT
remotePort = 0
EOF
    ok "Tạo frpc config: $cfg"
  fi
}

# ── Download bore ────────────────────────────────────────────
setup_bore() {
  local bin="$BIN_DIR/bore"
  if [ ! -f "$bin" ]; then
    info "Download bore..."
    # bore static binary
    wget -q "https://github.com/ekzhang/bore/releases/latest/download/bore-v0.5.0-aarch64-unknown-linux-musl.tar.gz" \
         -O /tmp/bore.tar.gz 2>/dev/null \
    || wget -q "https://github.com/ekzhang/bore/releases/latest/download/bore-v0.5.0-armv7-unknown-linux-musleabihf.tar.gz" \
         -O /tmp/bore.tar.gz 2>/dev/null
    tar -xzf /tmp/bore.tar.gz -C "$BIN_DIR/" 2>/dev/null
    chmod +x "$BIN_DIR/bore" 2>/dev/null
    rm -f /tmp/bore.tar.gz
    [ -f "$bin" ] && ok "bore downloaded" || { err "Download thất bại"; return 1; }
  else
    ok "bore đã có sẵn"
  fi
}

# ── Status ───────────────────────────────────────────────────
show_status() {
  sep
  echo -e "  ${BOLD}📊 Trạng thái tunnel:${NC}"
  sep
  pgrep -f "playit" &>/dev/null \
    && ok "playit.gg   RUNNING  → $(grep 'listening' $LOG_DIR/playit.log 2>/dev/null | tail -1 | grep -oP 'at \K.*' || echo 'xem log')" \
    || err "playit.gg   STOPPED"
  pgrep -f "frpc" &>/dev/null \
    && ok "frpc        RUNNING  → frp.freefrp.net" \
    || err "frpc        STOPPED"
  pgrep -f "bore" &>/dev/null \
    && ok "bore        RUNNING  → $(grep 'listening' $LOG_DIR/bore.log 2>/dev/null | tail -1 | grep -oP 'at \K.*' || echo 'xem log')" \
    || err "bore        STOPPED"
  echo ""
  echo -e "  ${BOLD}🌐 IP công cộng:${NC}"
  PUBLIC_IP=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "không lấy được")
  echo -e "  ${CYAN}$PUBLIC_IP${NC}"
  sep
}

# ── Chạy playit ─────────────────────────────────────────────
run_playit() {
  setup_playit || return 1
  pkill -f "$BIN_DIR/playit" 2>/dev/null; sleep 1

  # Tạo config nếu chưa có
  mkdir -p "$HOME/.config/playit_gg"
  if [ ! -f "$HOME/.config/playit_gg/playit.toml" ]; then
    info "Lần đầu chạy playit — sẽ hiện link để claim tunnel"
    info "Truy cập link đó trên trình duyệt, sau đó tunnel tự chạy"
    "$BIN_DIR/playit"
    return
  fi

  nohup "$BIN_DIR/playit" >> "$LOG_DIR/playit.log" 2>&1 &
  local pid=$!
  info "playit khởi động (PID $pid)..."
  sleep 5
  if pgrep -f "$BIN_DIR/playit" &>/dev/null; then
    ok "playit đang chạy!"
    tail -8 "$LOG_DIR/playit.log"
  else
    err "playit crash — xem log:"
    tail -10 "$LOG_DIR/playit.log"
  fi
}

# ── Chạy frpc ────────────────────────────────────────────────
run_frpc() {
  setup_frpc || return 1
  pkill -f "$BIN_DIR/frpc" 2>/dev/null; sleep 1
  nohup "$BIN_DIR/frpc" -c "$HOME/frpc_nro.toml" >> "$LOG_DIR/frpc.log" 2>&1 &
  local pid=$!
  info "frpc khởi động (PID $pid)..."
  sleep 4
  if grep -q "start proxy success" "$LOG_DIR/frpc.log" 2>/dev/null; then
    ok "frpc đang chạy!"
    REMOTE_PORT=$(grep -oP 'remotePort=\K\d+' "$LOG_DIR/frpc.log" 2>/dev/null | tail -1)
    ok "Địa chỉ: frp.freefrp.net:${REMOTE_PORT:-21445}"
  else
    err "frpc lỗi — xem log:"
    tail -10 "$LOG_DIR/frpc.log"
  fi
}

# ── Chạy bore ────────────────────────────────────────────────
run_bore() {
  setup_bore || return 1
  pkill -f "$BIN_DIR/bore" 2>/dev/null; sleep 1
  nohup "$BIN_DIR/bore" local "$GAME_PORT" --to bore.pub >> "$LOG_DIR/bore.log" 2>&1 &
  local pid=$!
  info "bore khởi động (PID $pid)..."
  sleep 4
  if grep -q "listening at" "$LOG_DIR/bore.log" 2>/dev/null; then
    ADDR=$(grep "listening at" "$LOG_DIR/bore.log" | tail -1 | grep -oP 'at \K.*')
    ok "bore đang chạy!"
    ok "Địa chỉ: $ADDR"
  else
    err "bore lỗi — xem log:"
    tail -10 "$LOG_DIR/bore.log"
  fi
}

# ── Chạy SSH reverse tunnel (serveo/localhost.run) ───────────
run_ssh_tunnel() {
  echo ""
  echo -e "  Chọn SSH tunnel server:"
  echo -e "  ${CYAN}1)${NC} serveo.net     (miễn phí, có thể chậm)"
  echo -e "  ${CYAN}2)${NC} localhost.run  (AWS infrastructure)"
  echo ""
  read -p "  Lựa chọn [1/2]: " srv_choice

  pkill -f "ssh.*serveo\|ssh.*localhost.run" 2>/dev/null; sleep 1

  case $srv_choice in
    1)
      SERVER="serveo.net"
      ;;
    2)
      SERVER="localhost.run"
      ;;
    *)
      SERVER="serveo.net"
      ;;
  esac

  info "Kết nối SSH tunnel → $SERVER..."
  nohup ssh -p 80 -R "0:localhost:$GAME_PORT" \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=5 \
    -o ExitOnForwardFailure=yes \
    -o ConnectTimeout=10 \
    "nokey@$SERVER" >> "$LOG_DIR/ssh_tunnel.log" 2>&1 &
  sleep 5
  ADDR=$(grep -oP '\d+\.\d+\.\d+\.\d+:\d+|[\w-]+\.serveo\.net:\d+|[\w-]+\.localhost\.run:\d+' \
         "$LOG_DIR/ssh_tunnel.log" 2>/dev/null | tail -1)
  if [ -n "$ADDR" ]; then
    ok "SSH tunnel chạy!"
    ok "Địa chỉ: $ADDR"
  else
    err "Tunnel lỗi — xem log:"
    tail -10 "$LOG_DIR/ssh_tunnel.log"
  fi
}

# ── Stop all ─────────────────────────────────────────────────
stop_all() {
  info "Dừng tất cả tunnel..."
  pkill -f "$BIN_DIR/playit" 2>/dev/null && ok "playit stopped" || true
  pkill -f "$BIN_DIR/frpc"   2>/dev/null && ok "frpc stopped"   || true
  pkill -f "$BIN_DIR/bore"   2>/dev/null && ok "bore stopped"   || true
  pkill -f "ssh.*serveo\|ssh.*localhost.run" 2>/dev/null && ok "ssh tunnel stopped" || true
}

# ── Xem log ──────────────────────────────────────────────────
view_logs() {
  echo ""
  echo -e "  Xem log của tunnel nào?"
  echo -e "  ${CYAN}1)${NC} playit.gg"
  echo -e "  ${CYAN}2)${NC} frpc"
  echo -e "  ${CYAN}3)${NC} bore"
  echo -e "  ${CYAN}4)${NC} SSH tunnel"
  echo ""
  read -p "  Lựa chọn: " log_choice
  case $log_choice in
    1) tail -20 "$LOG_DIR/playit.log" 2>/dev/null || err "Chưa có log" ;;
    2) tail -20 "$LOG_DIR/frpc.log"   2>/dev/null || err "Chưa có log" ;;
    3) tail -20 "$LOG_DIR/bore.log"   2>/dev/null || err "Chưa có log" ;;
    4) tail -20 "$LOG_DIR/ssh_tunnel.log" 2>/dev/null || err "Chưa có log" ;;
  esac
}

# ── Set playit secret key ─────────────────────────────────────
set_playit_key() {
  echo ""
  read -p "  Nhập playit secret key: " pkey
  mkdir -p "$HOME/.config/playit_gg"
  cat > "$HOME/.config/playit_gg/playit.toml" << EOF
secret_key = "$pkey"
EOF
  ok "Đã lưu secret key"
  info "Chạy lại playit để áp dụng"
}

# ── Main Menu ─────────────────────────────────────────────────
main_menu() {
  while true; do
    clear
    banner
    show_status
    echo -e "  ${BOLD}[TUNNEL]${NC}"
    echo -e "  ${CYAN}1)${NC} Chạy playit.gg   (anycast, ổn định nhất)"
    echo -e "  ${CYAN}2)${NC} Chạy frpc         (freefrp.net backup)"
    echo -e "  ${CYAN}3)${NC} Chạy bore         (bore.pub)"
    echo -e "  ${CYAN}4)${NC} Chạy SSH tunnel   (serveo/localhost.run)"
    echo ""
    echo -e "  ${BOLD}[TOOLS]${NC}"
    echo -e "  ${CYAN}5)${NC} Setup playit secret key"
    echo -e "  ${CYAN}6)${NC} Xem logs"
    echo -e "  ${CYAN}7)${NC} Dừng tất cả tunnel"
    echo -e "  ${CYAN}8)${NC} Cài dependencies"
    echo -e "  ${CYAN}0)${NC} Thoát"
    echo ""
    read -p "  Lựa chọn: " choice
    echo ""
    case $choice in
      1) run_playit ;;
      2) run_frpc ;;
      3) run_bore ;;
      4) run_ssh_tunnel ;;
      5) set_playit_key ;;
      6) view_logs ;;
      7) stop_all ;;
      8) check_deps ;;
      0) echo -e "  ${GREEN}Bye!${NC}"; exit 0 ;;
      *) err "Lựa chọn không hợp lệ" ;;
    esac
    echo ""
    read -p "  [Enter để tiếp tục]"
  done
}

# ── Entry point ───────────────────────────────────────────────
check_deps
main_menu
