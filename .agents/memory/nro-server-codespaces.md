---
name: NRO Server trên Codespaces
description: Thông tin kết nối, deploy, và cấu trúc server NRO chạy trên GitHub Codespaces
---

# NRO Server — GitHub Codespaces

**Why:** Server game chạy trên Codespace, không phải Replit. Mỗi phiên cần SSH vào để compile + restart.

## Kết nối Codespace

```
Codespace name: cautious-space-halibut-p7rwgqwxrg5gfrrqg
SSH command:    GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh -c "cautious-space-halibut-p7rwgqwxrg5gfrrqg" -- bash << 'REMOTE'
```

## Cấu trúc thư mục

```
/home/codespace/nro/SRC/
  NgocRongOnline.jar   ← JAR chạy server
  src/                 ← Source Java
    nro/models/...
  lib/                 ← Dependencies
~/logs/server.log      ← Log server
```

## Deploy nhanh (4 bước)

```bash
# 1. Compile
javac -cp "NgocRongOnline.jar:lib/*" -d /tmp/nro_out <file.java>

# 2. Update JAR
jar uf NgocRongOnline.jar -C /tmp/nro_out nro/

# 3. Restart
pkill -9 -f NgocRongOnline; sleep 3
nohup java -Xms256m -Xmx1g -jar NgocRongOnline.jar >> ~/logs/server.log 2>&1 &

# 4. Verify
sleep 10 && pgrep -f NgocRongOnline && tail -5 ~/logs/server.log
```

## GitHub Repo

```
Repo:   akah3674-glitch/rem5
Remote: github (không phải origin)
Push:   git push github main
Token:  Replit Secret GITHUB_PERSONAL_ACCESS_TOKEN
```

## Game Server Info

```
IP/Port game: bore.pub:5798 (tunnel qua frp.freefrp.net:21445)
Admin:        username=admin / pass=12345678 / char=memeiue
DB:           nro1 (MariaDB local trên Codespace)
```

## Phase keepalive đã hoàn thành: 1→16 ✅
- Phase 16: cai_trang 351 bộ + items INSERT IGNORE
- Phase 15: fix Map.java spawn offset (mobs bay trên trời)
- Xem chi tiết tại: `docs/NRO_UPGRADE_PLAN_TEAMOBI2026.md`
