#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  TEAMOBI 2026 - TERMUX SERVER MANAGER v1.1
#  github.com/akah3674-glitch/rem5
#  ⚠ Dùng: curl ... -o /tmp/tm.sh && bash /tmp/tm.sh
# ============================================================

# Safe stdin redirect khi chạy qua pipe
[ -t 0 ] || exec </dev/tty 2>/dev/null || {
  echo "[ERR] Hãy chạy theo cách này:"
  echo "  curl -fsSL https://raw.githubusercontent.com/akah3674-glitch/rem5/main/setup.sh -o /tmp/tm.sh && bash /tmp/tm.sh"
  exit 1
}

R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m'
B='\033[0;34m' C='\033[0;36m' M='\033[0;35m'
W='\033[1;37m' BLD='\033[1m'  NC='\033[0m'

INSTALL_DIR="$HOME/teamobi-server"
DRIVE_ID="1uH2O2FtuGpIQfIYVAhi9wcuxfDjTQddY"
DRIVE_URL="https://drive.usercontent.google.com/download?id=${DRIVE_ID}&export=download&authuser=0&confirm=t"
RAR_FILE="$INSTALL_DIR/Teamobi2026.rar"
DB_NAME="teamobi2026"
DB_PASS="teamobi@2026"
DB_USER="root"
GAME_PORT=14445
HTTP_PORT=8080
DB_PORT=3306
SETUP_FLAG="$INSTALL_DIR/.setup_done"
SRV_PID="$INSTALL_DIR/.server.pid"
LOG_DIR="$INSTALL_DIR/logs"

banner() {
  clear
  echo -e "${C}${BLD}"
  echo "  ╔══════════════════════════════════════════════════╗"
  echo "  ║     🎮  TEAMOBI 2026 SERVER MANAGER  🎮         ║"
  echo "  ║           Termux Private Server v1.1            ║"
  echo "  ╚══════════════════════════════════════════════════╝${NC}"
}

meolu_art() {
  echo -e "${Y}${BLD}"
  echo "     /\\_____/\\"
  echo "    (  ^   ^ )"
  echo "     (  =ω= )   MÈO LÙ CHÀO BẠN !"
  echo "      )     (   Pet đặc biệt~"
  echo "     (_)-(_)${NC}"
}

port_panel() {
  local ip
  ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}') \
    || ip=$(ifconfig wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}') \
    || ip="127.0.0.1"

  chk() { ss -tlnp 2>/dev/null | grep -q ":$1" && echo -e "${G}● ONLINE ${NC}" || echo -e "${R}○ OFFLINE${NC}"; }

  echo -e "\n${W}  ┌────────────── BẢNG CỔNG ──────────────────────┐${NC}"
  echo -e "  │  ${C}[GAME]${NC}  Port ${Y}14445${NC}  ←→  $(chk 14445)  ${W}│${NC}"
  echo -e "  │  ${C}[HTTP]${NC}  Port ${Y}8080 ${NC}  ←→  $(chk 8080)  ${W}│${NC}"
  echo -e "  │  ${C}[DB]  ${NC}  Port ${Y}3306 ${NC}  ←→  $(chk 3306)  ${W}│${NC}"
  echo -e "  │  ${C}[IP]  ${NC}  ${Y}${ip}${NC}                     ${W}│${NC}"
  echo -e "  └────────────────────────────────────────────────┘${NC}"

  if [ -f "$SRV_PID" ]; then
    local pid; pid=$(cat "$SRV_PID" 2>/dev/null)
    kill -0 "$pid" 2>/dev/null && echo -e "  ${G}▶ Server đang chạy  PID: ${Y}${pid}${NC}"
  fi
}

info_line() { echo -e "  ${C}[INFO]${NC} $1"; }
ok_line()   { echo -e "  ${G}[OK]${NC}   $1"; }
err_line()  { echo -e "  ${R}[ERR]${NC}  $1"; }
warn_line() { echo -e "  ${Y}[WARN]${NC} $1"; }
press_enter() { echo -e -n "\n  ${C}Nhấn Enter để tiếp tục...${NC}"; read -r; }
db_q()     { mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" 2>/dev/null; }
db_qr()    { mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" --skip-column-names -e "$1" 2>/dev/null; }

# ─── 1. SETUP ────────────────────────────────────────────────
do_setup() {
  banner
  echo -e "\n${BLD}${C}  ═══ SETUP TEAMOBI 2026 ═══${NC}\n"

  if [ -f "$SETUP_FLAG" ]; then
    warn_line "Đã setup trước đó."
    echo -e -n "  ${Y}Chạy lại? [Y/n]:${NC} "; read -r a
    [[ "$a" =~ ^[Yy]?$ ]] || return
  fi

  mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$INSTALL_DIR/bin"
  echo Y | termux-setup-storage &>/dev/null

  info_line "Cài packages..."
  pkg update -y &>/dev/null
  for p in openjdk-17 mariadb unrar wget curl iproute2 net-tools; do
    pkg install -y "$p" &>/dev/null && ok_line "$p" || warn_line "$p (bỏ qua)"
  done

  echo ""
  info_line "Tải Teamobi2026.rar (~630MB)..."
  if [ -f "$RAR_FILE" ] && [ "$(stat -c%s "$RAR_FILE" 2>/dev/null)" -gt 100000000 ]; then
    warn_line "File đã tồn tại ($(du -sh "$RAR_FILE" | cut -f1)), bỏ qua."
  else
    curl -L --max-redirs 15 --progress-bar --retry 3 -C - "$DRIVE_URL" -o "$RAR_FILE"
    [ "$(stat -c%s "$RAR_FILE" 2>/dev/null)" -lt 1000000 ] && {
      err_line "Download thất bại! Kiểm tra kết nối."; press_enter; return
    }
    ok_line "Download xong: $(du -sh "$RAR_FILE" | cut -f1)"
  fi

  info_line "Giải nén RAR..."
  cd "$INSTALL_DIR" || exit 1
  unrar x -o+ "$RAR_FILE" "$INSTALL_DIR/" &>/dev/null \
    || unrar e -o+ "$RAR_FILE" "$INSTALL_DIR/" &>/dev/null

  local jar_game jar_login sql_file apk_src
  jar_game=$(find "$INSTALL_DIR" -name "*.jar" 2>/dev/null | grep -iE "game|srcgame|server|main" | head -1)
  jar_login=$(find "$INSTALL_DIR" -name "*.jar" 2>/dev/null | grep -iE "login|auth" | head -1)
  sql_file=$(find "$INSTALL_DIR" -name "*.sql" 2>/dev/null | head -1)
  apk_src=$(find "$INSTALL_DIR" -name "*.apk" 2>/dev/null | head -1)
  [ -z "$jar_game" ] && jar_game=$(find "$INSTALL_DIR" -name "*.jar" 2>/dev/null | head -1)

  printf "JAR_GAME=%s\nJAR_LOGIN=%s\n" "$jar_game" "$jar_login" > "$INSTALL_DIR/.config"
  ok_line "JAR game:  ${jar_game:-không tìm thấy}"
  ok_line "JAR login: ${jar_login:-không có}"

  info_line "Khởi tạo MariaDB..."
  mysqld_safe --skip-grant-tables &>/dev/null & sleep 4

  mysql -u root --connect-expired-password 2>/dev/null <<SQL
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}';
FLUSH PRIVILEGES;
SQL

  mysql -u"$DB_USER" -p"$DB_PASS" 2>/dev/null <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE \`${DB_NAME}\`;
CREATE TABLE IF NOT EXISTS account (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(64) NOT NULL,
  email VARCHAR(100) DEFAULT '',
  role INT DEFAULT 0 COMMENT '0=player,1=gm,2=admin',
  status INT DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS nhan_vat (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT,
  name VARCHAR(50),
  level INT DEFAULT 1,
  vang BIGINT DEFAULT 0,
  ngoc BIGINT DEFAULT 0,
  exp BIGINT DEFAULT 0,
  map_id INT DEFAULT 1,
  FOREIGN KEY (account_id) REFERENCES account(id)
);
CREATE TABLE IF NOT EXISTS meo_lu (
  id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT,
  pet_name VARCHAR(50) DEFAULT 'Mèo Lù',
  pet_level INT DEFAULT 1,
  pet_exp INT DEFAULT 0,
  pet_skill VARCHAR(200) DEFAULT 'Lucky Strike',
  FOREIGN KEY (account_id) REFERENCES account(id)
);
SQL

  [ -n "$sql_file" ] && [ -f "$sql_file" ] && {
    info_line "Import SQL gốc: $(basename "$sql_file")..."
    mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$sql_file" &>/dev/null \
      && ok_line "Import OK" || warn_line "Import lỗi (tiếp tục)"
  }

  pkill mysqld 2>/dev/null; sleep 2

  # Viết start.sh
  cat > "$INSTALL_DIR/bin/start.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/teamobi-server"; source "$D/.config"
mkdir -p "$D/logs"
mysqld_safe --datadir="$PREFIX/var/lib/mysql" &>/dev/null & sleep 3
[ -n "$JAR_LOGIN" ] && [ -f "$JAR_LOGIN" ] && {
  java -Xms128m -Xmx256m -jar "$JAR_LOGIN" > "$D/logs/login.log" 2>&1 &; echo $! > "$D/.login.pid"; sleep 2; }
[ -n "$JAR_GAME" ] && [ -f "$JAR_GAME" ] && {
  java -Xms256m -Xmx512m -jar "$JAR_GAME" > "$D/logs/game.log" 2>&1 &; echo $! > "$D/.server.pid"; }
echo "[$(date)] Servers started."
SH

  cat > "$INSTALL_DIR/bin/stop.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
D="$HOME/teamobi-server"
for pf in "$D/.server.pid" "$D/.login.pid"; do
  [ -f "$pf" ] && { kill "$(cat "$pf")" 2>/dev/null; rm -f "$pf"; }
done
pkill -f mysqld 2>/dev/null
echo "[$(date)] All stopped."
SH

  chmod +x "$INSTALL_DIR/bin/start.sh" "$INSTALL_DIR/bin/stop.sh"

  [ -n "$apk_src" ] && [ -f "$apk_src" ] && {
    mkdir -p "$HOME/storage/downloads/game_download" 2>/dev/null
    cp "$apk_src" "$HOME/storage/downloads/game_download/Teamobi2026.apk" 2>/dev/null \
      && ok_line "APK → Downloads/game_download/Teamobi2026.apk"
  }

  touch "$SETUP_FLAG"
  echo ""; ok_line "${BLD}Setup hoàn tất! Vào menu 2 để chạy server.${NC}"
  press_enter
}

# ─── 2. CHẠY SERVER ──────────────────────────────────────────
do_start() {
  banner; echo -e "\n${G}${BLD}  ═══ CHẠY SERVER ═══${NC}\n"
  [ ! -f "$SETUP_FLAG" ] && { err_line "Chưa setup! Chọn menu 1 trước."; press_enter; return; }

  if [ -f "$SRV_PID" ] && kill -0 "$(cat "$SRV_PID")" 2>/dev/null; then
    warn_line "Server đã đang chạy! PID: $(cat "$SRV_PID")"; press_enter; return
  fi

  info_line "Khởi động MariaDB..."
  mysqld_safe --datadir="$PREFIX/var/lib/mysql" &>/dev/null & sleep 3
  ok_line "MariaDB OK"

  source "$INSTALL_DIR/.config" 2>/dev/null

  [ -n "$JAR_LOGIN" ] && [ -f "$JAR_LOGIN" ] && {
    info_line "Login Server..."
    java -Xms128m -Xmx256m -jar "$JAR_LOGIN" > "$LOG_DIR/login.log" 2>&1 &
    echo $! > "$INSTALL_DIR/.login.pid"; sleep 2
    ok_line "Login PID: $(cat "$INSTALL_DIR/.login.pid")"
  }

  if [ -n "$JAR_GAME" ] && [ -f "$JAR_GAME" ]; then
    info_line "Game Server (port: ${GAME_PORT})..."
    java -Xms256m -Xmx512m -jar "$JAR_GAME" > "$LOG_DIR/game.log" 2>&1 &
    echo $! > "$SRV_PID"; sleep 2
    ok_line "Game PID: $(cat "$SRV_PID")"
  else
    err_line "Không tìm thấy JAR game! Chạy lại Setup."; press_enter; return
  fi

  echo ""; ok_line "${BLD}Server đang chạy!${NC}"
  port_panel; press_enter
}

# ─── 3. TẮT SERVER ───────────────────────────────────────────
do_stop() {
  banner; echo -e "\n${R}${BLD}  ═══ TẮT SERVER ═══${NC}\n"
  local stopped=0
  for pf in "$SRV_PID" "$INSTALL_DIR/.login.pid"; do
    [ -f "$pf" ] && {
      local pid; pid=$(cat "$pf")
      kill -0 "$pid" 2>/dev/null && { kill "$pid" && ok_line "Dừng PID $pid"; stopped=1; }
      rm -f "$pf"
    }
  done
  pkill -f mysqld_safe 2>/dev/null; pkill -f mysqld 2>/dev/null
  ok_line "MariaDB đã dừng"
  [ $stopped -eq 0 ] && info_line "Không có server nào đang chạy."
  press_enter
}

# ─── 4. MÈO LÙ ───────────────────────────────────────────────
do_meolu() {
  banner; meolu_art
  echo -e "\n${M}${BLD}  ═══ MÈO LÙ MANAGER ═══${NC}\n"
  echo -e "  ${Y}1.${NC} Thêm Mèo Lù cho nhân vật"
  echo -e "  ${Y}2.${NC} Xem danh sách Mèo Lù"
  echo -e "  ${Y}3.${NC} Nâng level Mèo Lù"
  echo -e "  ${Y}4.${NC} Đổi tên Mèo Lù"
  echo -e "  ${Y}0.${NC} Quay lại"
  echo -e -n "\n  ${C}Chọn [0-4]:${NC} "; read -r c
  case $c in
    1) echo -e -n "  ${C}Tên nhân vật:${NC} "; read -r n
       local aid; aid=$(db_qr "SELECT a.id FROM account a JOIN nhan_vat v ON v.account_id=a.id WHERE v.name='$n' LIMIT 1;")
       [ -z "$aid" ] && err_line "Không tìm thấy: $n" || {
         db_q "INSERT IGNORE INTO meo_lu (account_id,pet_name,pet_level) VALUES ($aid,'Mèo Lù',1);"
         ok_line "Đã thêm Mèo Lù cho $n!"; } ;;
    2) echo ""; db_q "SELECT m.id,v.name char_name,m.pet_name,m.pet_level,m.pet_skill FROM meo_lu m JOIN nhan_vat v ON v.account_id=m.account_id;" 2>/dev/null || echo "  (chưa có dữ liệu)" ;;
    3) echo -e -n "  ${C}Tên nhân vật:${NC} "; read -r n
       echo -e -n "  ${C}Level mới:${NC} "; read -r lv
       db_q "UPDATE meo_lu m JOIN nhan_vat v ON v.account_id=m.account_id SET m.pet_level=${lv:-1} WHERE v.name='$n';"
       ok_line "Mèo Lù của $n → lv $lv" ;;
    4) echo -e -n "  ${C}Tên nhân vật:${NC} "; read -r n
       echo -e -n "  ${C}Tên mới:${NC} "; read -r nn
       db_q "UPDATE meo_lu m JOIN nhan_vat v ON v.account_id=m.account_id SET m.pet_name='$nn' WHERE v.name='$n';"
       ok_line "Mèo Lù của $n đổi tên → $nn" ;;
    0) return ;;
  esac
  press_enter
}

# ─── 5. ĐĂNG KÝ TÀI KHOẢN ───────────────────────────────────
do_register() {
  banner; echo -e "\n${BLD}${C}  ═══ ĐĂNG KÝ TÀI KHOẢN ═══${NC}\n"
  echo -e -n "  ${C}Tên đăng nhập:${NC} "; read -r u
  [ -z "$u" ] && { err_line "Không được rỗng!"; press_enter; return; }
  echo -e -n "  ${C}Mật khẩu:${NC} "; read -rs p; echo
  [ -z "$p" ] && { err_line "Không được rỗng!"; press_enter; return; }
  echo -e -n "  ${C}Email (Enter để bỏ qua):${NC} "; read -r em
  echo -e "\n  ${Y}0${NC}=Player  ${Y}1${NC}=GM  ${Y}2${NC}=Admin"
  echo -e -n "  ${C}Quyền [0-2]:${NC} "; read -r role; role=${role:-0}

  local h; h=$(echo -n "$p" | md5sum | cut -d' ' -f1)
  local res; res=$(db_q "INSERT INTO account (username,password,email,role) VALUES ('$u','$h','${em:-}',${role});" 2>&1)

  if echo "$res" | grep -qi "duplicate"; then
    err_line "Tên đăng nhập đã tồn tại!"
  else
    local role_name
    [ "$role" -eq 2 ] && role_name="ADMIN" || { [ "$role" -eq 1 ] && role_name="GM" || role_name="Player"; }
    ok_line "Tài khoản '${u}' đã tạo! Quyền: ${role_name}"
    echo -e -n "  ${C}Tạo nhân vật mặc định? [Y/n]:${NC} "; read -r mk
    [[ "$mk" =~ ^[Yy]?$ ]] && {
      echo -e -n "  ${C}Tên nhân vật:${NC} "; read -r cn
      local aid; aid=$(db_qr "SELECT id FROM account WHERE username='$u' LIMIT 1;")
      [ -n "$aid" ] && [ -n "$cn" ] && {
        db_q "INSERT INTO nhan_vat (account_id,name,level) VALUES ($aid,'$cn',1);"
        ok_line "Nhân vật '$cn' đã tạo!"; }
    }
  fi
  press_enter
}

# ─── 6. THÊM VÀNG/NGỌC ───────────────────────────────────────
do_gold_gem() {
  banner; echo -e "\n${BLD}${Y}  ═══ THÊM VÀNG / NGỌC ═══${NC}\n"
  echo -e -n "  ${C}Tên nhân vật (hoặc 'all'):${NC} "; read -r t

  if [ "$t" = "all" ]; then
    echo -e -n "  ${C}Số vàng thêm:${NC} "; read -r vg
    echo -e -n "  ${C}Số ngọc thêm:${NC} "; read -r ng
    [ "${vg:-0}" -gt 0 ] && db_q "UPDATE nhan_vat SET vang=vang+${vg};"
    [ "${ng:-0}" -gt 0 ] && db_q "UPDATE nhan_vat SET ngoc=ngoc+${ng};"
    ok_line "Đã thêm ${vg:-0} vàng + ${ng:-0} ngọc cho TẤT CẢ nhân vật!"
  else
    local cid; cid=$(db_qr "SELECT id FROM nhan_vat WHERE name='$t' LIMIT 1;")
    [ -z "$cid" ] && { err_line "Không tìm thấy: $t"; press_enter; return; }
    info_line "Hiện tại: $(db_qr "SELECT name,level,vang,ngoc FROM nhan_vat WHERE id=$cid;")"
    echo -e -n "  ${C}Số vàng thêm:${NC} "; read -r vg
    echo -e -n "  ${C}Số ngọc thêm:${NC} "; read -r ng
    [ "${vg:-0}" -gt 0 ] && db_q "UPDATE nhan_vat SET vang=vang+${vg} WHERE id=${cid};"
    [ "${ng:-0}" -gt 0 ] && db_q "UPDATE nhan_vat SET ngoc=ngoc+${ng} WHERE id=${cid};"
    ok_line "Sau cập nhật: $(db_qr "SELECT name,level,vang,ngoc FROM nhan_vat WHERE id=$cid;")"
  fi
  press_enter
}

# ─── 7. DANH SÁCH TÀI KHOẢN ─────────────────────────────────
do_list_accounts() {
  banner; echo -e "\n${BLD}${C}  ═══ DANH SÁCH TÀI KHOẢN ═══${NC}\n"
  db_q "SELECT id,username,role,status,created_at FROM account ORDER BY id DESC LIMIT 30;" 2>/dev/null \
    || echo "  (DB chưa chạy hoặc chưa có dữ liệu)"
  echo -e "\n  ${Y}1.${NC} Đổi mật khẩu  ${Y}2.${NC} Đổi quyền  ${Y}3.${NC} Xóa TK  ${Y}0.${NC} Quay lại"
  echo -e -n "  ${C}Chọn:${NC} "; read -r s
  case $s in
    1) echo -e -n "  ${C}Tên TK:${NC} "; read -r u
       echo -e -n "  ${C}Mật khẩu mới:${NC} "; read -rs p; echo
       db_q "UPDATE account SET password='$(echo -n "$p"|md5sum|cut -d' ' -f1)' WHERE username='$u';"
       ok_line "Đã đổi mật khẩu $u." ;;
    2) echo -e -n "  ${C}Tên TK:${NC} "; read -r u
       echo -e -n "  ${C}Quyền mới (0/1/2):${NC} "; read -r r
       db_q "UPDATE account SET role=${r:-0} WHERE username='$u';"
       ok_line "Quyền $u → $r" ;;
    3) echo -e -n "  ${C}Tên TK xóa:${NC} "; read -r u
       echo -e -n "  ${Y}Xác nhận xóa '$u'? [Y/n]:${NC} "; read -r cf
       [[ "$cf" =~ ^[Yy]?$ ]] && { db_q "DELETE FROM account WHERE username='$u';" && ok_line "Đã xóa $u."; } ;;
    0) return ;;
  esac
  press_enter
}

# ─── 8. LOGS ─────────────────────────────────────────────────
do_logs() {
  banner; echo -e "\n${BLD}${C}  ═══ LOGS ═══${NC}\n"
  echo -e "  ${Y}1.${NC} Game log  ${Y}2.${NC} Login log  ${Y}3.${NC} Realtime  ${Y}0.${NC} Quay lại"
  echo -e -n "  ${C}Chọn:${NC} "; read -r c
  case $c in
    1) tail -50 "$LOG_DIR/game.log" 2>/dev/null || echo "Chưa có log."; press_enter ;;
    2) tail -50 "$LOG_DIR/login.log" 2>/dev/null || echo "Chưa có log."; press_enter ;;
    3) echo "Ctrl+C để thoát..."; tail -f "$LOG_DIR/game.log" 2>/dev/null & tail -f "$LOG_DIR/login.log" 2>/dev/null; wait ;;
    0) return ;;
  esac
}

# ─── MAIN MENU ────────────────────────────────────────────────
while true; do
  banner
  [ -f "$SETUP_FLAG" ] && st="${G}● Đã setup${NC}" || st="${R}○ Chưa setup${NC}"
  port_panel
  echo -e "\n  Status: ${st}"
  echo -e "\n  ${BLD}${W}═══════════ MENU ═══════════${NC}"
  echo -e "  ${Y}1.${NC} Setup Server"
  echo -e "  ${G}2.${NC} Chạy Server  ▶"
  echo -e "  ${R}3.${NC} Tắt Server   ■"
  echo -e "  ${M}4.${NC} Mèo Lù 🐱"
  echo -e "  ${C}5.${NC} Đăng ký Tài khoản"
  echo -e "  ${Y}6.${NC} Thêm Vàng / Ngọc"
  echo -e "  ${B}7.${NC} Danh sách Tài khoản"
  echo -e "  ${W}8.${NC} Logs"
  echo -e "  ${W}0.${NC} Thoát"
  echo -e "  ${BLD}${W}════════════════════════════${NC}\n"
  echo -e -n "  ${C}Chọn [0-8]:${NC} "; read -r choice
  case $choice in
    1) do_setup ;;
    2) do_start ;;
    3) do_stop ;;
    4) do_meolu ;;
    5) do_register ;;
    6) do_gold_gem ;;
    7) do_list_accounts ;;
    8) do_logs ;;
    0) echo -e "\n  ${C}Tạm biệt! 🐱${NC}\n"; exit 0 ;;
    *) warn_line "Không hợp lệ!"; sleep 1 ;;
  esac
done
