#!/bin/bash
# =============================================
#  NGOC RONG SERVER - KHOI DONG
# =============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "=== Khởi động MariaDB ==="
sudo service mariadb start 2>/dev/null || sudo mysqld_safe &
sleep 3

# Kiểm tra database
DB_OK=$(sudo mysql -e "SHOW DATABASES LIKE 'team2026';" 2>/dev/null | grep team2026 || true)
if [ -z "$DB_OK" ]; then
  echo "⏳ Tạo và import database..."
  sudo mysql -e "CREATE DATABASE IF NOT EXISTS team2026 CHARACTER SET utf8mb4;"
  [ -f "$SERVER_DIR/database_team2026.sql" ] && sudo mysql team2026 < "$SERVER_DIR/database_team2026.sql"
  echo "✅ Database sẵn sàng"
fi

echo "=== Lấy IP công khai ==="
CODESPACE_HOST="${CODESPACE_NAME}-14445.app.github.dev"
echo "🌐 Host game: $CODESPACE_HOST"

# Cập nhật IP trong Config.properties
sed -i "s|server.ip=.*|server.ip=$CODESPACE_HOST|g" "$SERVER_DIR/Config.properties"
sed -i "s|database.pass=.*|database.pass=|g" "$SERVER_DIR/Config.properties"
sed -i "s|database.user=.*|database.user=root|g" "$SERVER_DIR/Config.properties"

echo "=== Khởi động Java Server ==="
cd "$SERVER_DIR"
LIB_PATH="lib/*"
nohup java -Xms256m -Xmx1g \
  -cp "NgocRongOnline.jar:$LIB_PATH" \
  Main \
  > "$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!
echo $SERVER_PID > /tmp/server.pid
echo "✅ Server đang chạy (PID: $SERVER_PID)"

echo "=== Mở tunnel bore ==="
/tmp/bore local 14445 --to bore.pub > /tmp/bore_game.log 2>&1 &
sleep 3
BORE_PORT=$(grep -o 'remote_port=[0-9]*' /tmp/bore_game.log | cut -d= -f2)

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "  ✅ NGOC RONG SERVER ĐANG CHẠY"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎮 IP Game : bore.pub"
echo "  🔌 Port    : $BORE_PORT"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📋 Điền vào game client:"
echo "  IP: bore.pub  Port: $BORE_PORT"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📋 Xem log server:"
echo "  tail -f logs/server.log"
echo "╚══════════════════════════════════════════════════╝"

echo ""
echo "🔄 Đang theo dõi server... (Ctrl+C để dừng)"
tail -f "$LOG_DIR/server.log"
