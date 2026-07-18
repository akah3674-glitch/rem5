#!/bin/bash
# =============================================================
# NRO Deploy Script — Replit → Codespace
# Dùng: bash scripts/deploy.sh [file1.java file2.java ...] [--sql file.sql] [--no-restart]
#
# Ví dụ:
#   bash scripts/deploy.sh                                  # compile tất cả file đã sửa gần đây
#   bash scripts/deploy.sh src/nro/models/mob/Mob.java      # compile 1 file cụ thể
#   bash scripts/deploy.sh --sql scripts/fix_icons.sql      # chỉ chạy SQL
#   bash scripts/deploy.sh Mob.java Map.java --no-restart   # compile không restart
# =============================================================

set -e

CODESPACE="cautious-space-halibut-p7rwgqwxrg5gfrrqg"
REMOTE_SRC="/home/codespace/nro/SRC"
LOCAL_SRC="server/src"   # monorepo path trên Replit

# Parse args
JAVA_FILES=()
SQL_FILES=()
NO_RESTART=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sql) shift; SQL_FILES+=("$1"); shift ;;
        --no-restart) NO_RESTART=true; shift ;;
        *.java) JAVA_FILES+=("$1"); shift ;;
        *.sql) SQL_FILES+=("$1"); shift ;;
        *) shift ;;
    esac
done

# Nếu không chỉ định file java, lấy các file thay đổi gần nhất
if [ ${#JAVA_FILES[@]} -eq 0 ] && [ ${#SQL_FILES[@]} -eq 0 ]; then
    echo "Không chỉ định file — lấy Java files đã sửa trong commit cuối..."
    mapfile -t JAVA_FILES < <(git diff --name-only HEAD~1 HEAD -- "$LOCAL_SRC/**/*.java" 2>/dev/null || true)
    if [ ${#JAVA_FILES[@]} -eq 0 ]; then
        echo "Không tìm thấy file Java nào. Dùng: bash scripts/deploy.sh path/to/File.java"
        exit 1
    fi
fi

echo "========================================"
echo " NRO Deploy → Codespace"
echo "========================================"

# ---- Bước 1: Copy Java files lên Codespace ----
if [ ${#JAVA_FILES[@]} -gt 0 ]; then
    echo ""
    echo "--- [1/4] Copy ${#JAVA_FILES[@]} file(s) lên Codespace ---"
    for LOCAL_FILE in "${JAVA_FILES[@]}"; do
        # Chuyển path: server/src/nro/... → src/nro/...
        REMOTE_FILE="${LOCAL_FILE#$LOCAL_SRC/}"
        REMOTE_PATH="$REMOTE_SRC/src/$REMOTE_FILE"
        echo "  → $LOCAL_FILE"
        GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh \
            -c "$CODESPACE" -- "mkdir -p $(dirname $REMOTE_PATH)" 2>/dev/null
        cat "$LOCAL_FILE" | GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh \
            -c "$CODESPACE" -- "cat > $REMOTE_PATH"
    done
    echo "Copy OK"

    # ---- Bước 2: Compile ----
    echo ""
    echo "--- [2/4] Compile ---"
    REMOTE_FILES=$(printf "src/%s " "${JAVA_FILES[@]/#$LOCAL_SRC\//}")
    GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh \
        -c "$CODESPACE" -- bash << ENDSSH
set -e
cd $REMOTE_SRC
mkdir -p /tmp/nro_out
javac -cp "NgocRongOnline.jar:lib/*" -d /tmp/nro_out $REMOTE_FILES
echo "Compile OK"

# ---- Bước 3: Update JAR ----
jar uf NgocRongOnline.jar -C /tmp/nro_out nro/
echo "JAR OK"
ENDSSH
fi

# ---- Bước 4: Chạy SQL (nếu có) ----
if [ ${#SQL_FILES[@]} -gt 0 ]; then
    echo ""
    echo "--- [3/4] Chạy SQL ---"
    for SQL_FILE in "${SQL_FILES[@]}"; do
        echo "  → $SQL_FILE"
        cat "$SQL_FILE" | GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh \
            -c "$CODESPACE" -- "mysql -u root nro1"
    done
    echo "SQL OK"
fi

# ---- Bước 5: Restart ----
if [ "$NO_RESTART" = false ]; then
    echo ""
    echo "--- [4/4] Restart server ---"
    GH_TOKEN="${GITHUB_PERSONAL_ACCESS_TOKEN}" gh codespace ssh \
        -c "$CODESPACE" -- bash << ENDSSH
cd $REMOTE_SRC
pkill -9 -f NgocRongOnline || true
sleep 3
nohup java -Xms256m -Xmx1g -jar NgocRongOnline.jar >> ~/logs/server.log 2>&1 &
sleep 10
pgrep -f NgocRongOnline && echo "✅ Server RUNNING" || echo "❌ FAILED"
tail -5 ~/logs/server.log
ENDSSH
fi

echo ""
echo "========================================"
echo " Deploy hoàn tất ✅"
echo "========================================"
