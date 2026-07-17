#!/bin/bash
set -e
echo "=== Cài đặt MariaDB ==="
sudo apt-get update -qq
sudo apt-get install -y -qq mariadb-server wget unzip

echo "=== Khởi động MariaDB ==="
sudo service mariadb start
sleep 2

echo "=== Tạo database ==="
sudo mysql -e "CREATE DATABASE IF NOT EXISTS team2026 CHARACTER SET utf8mb4;"
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY ''; FLUSH PRIVILEGES;"

if [ -f server/database_team2026.sql ]; then
  echo "=== Import database ==="
  sudo mysql team2026 < server/database_team2026.sql
  echo "✅ Database imported"
fi

echo "=== Tải bore tunnel ==="
wget -qO ~/bore https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz
# fallback nếu là tar
file ~/bore | grep -q gzip && tar -xzf ~/bore -C ~/ && rm ~/bore && mv ~/bore-* ~/bore 2>/dev/null || true
wget -qO ~/bore "https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz"
tar -xzf ~/bore -C ~/ bore 2>/dev/null || true
rm -f ~/bore 2>/dev/null
wget -qO ~/bore "https://github.com/ekzhang/bore/releases/latest/download/bore-v0.5.1-x86_64-unknown-linux-musl"  2>/dev/null || true
# Thử cách khác
curl -sLo /tmp/bore.tar.gz "https://github.com/ekzhang/bore/releases/download/v0.5.1/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz"
tar -xzf /tmp/bore.tar.gz -C /tmp/
chmod +x /tmp/bore
echo "✅ Setup hoàn tất! Chạy: bash start.sh"
