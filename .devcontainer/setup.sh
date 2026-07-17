#!/bin/bash
set -e
echo "=== Cài packages ==="
sudo apt-get update -qq
sudo apt-get install -y -qq mariadb-server wget curl p7zip-full unrar-free 2>/dev/null || sudo apt-get install -y -qq mariadb-server wget curl p7zip-full 2>/dev/null

echo "=== Tải server từ Google Drive ==="
mkdir -p ~/nro
cd ~/nro
wget -q --no-check-certificate   "https://drive.usercontent.google.com/download?id=1uH2O2FtuGpIQfIYVAhi9wcuxfDjTQddY&export=download&confirm=t"   -O server_pkg.rar
echo "Tải xong: $(ls -lh server_pkg.rar)"

echo "=== Giải nén ==="
unrar x -y server_pkg.rar . 2>/dev/null || 7z x server_pkg.rar -o. -y 2>/dev/null || true
ls -la ~/nro/

echo "=== Cài ngrok ==="
curl -sLo /tmp/ngrok.tgz https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
sudo tar -xzf /tmp/ngrok.tgz -C /usr/local/bin/
ngrok config add-authtoken "3GctAUGxj43OBIHbY32ylzVsg6k_5uGajyhXwWXGeVWwtKEWw"
echo "✅ Setup hoàn tất"
