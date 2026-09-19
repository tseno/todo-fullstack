#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
PIDS=()

cleanup() {
    echo ""
    echo "=== 終了処理中 ==="
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    docker compose -f "$PROJECT_ROOT/compose.yml" down
    echo "=== 完了 ==="
}
trap cleanup EXIT INT TERM

echo "=== PostgreSQL を起動中 ==="
docker compose -f "$PROJECT_ROOT/compose.yml" up -d
sleep 2

echo "=== Backend を起動中 (port: 8080) ==="
(cd "$BACKEND_DIR" && ./gradlew bootRun) &
PIDS+=($!)

echo "=== Frontend を起動中 (port: 3000) ==="
(cd "$FRONTEND_DIR" && npm run dev) &
PIDS+=($!)

echo ""
echo "=== 開発環境が起動しました ==="
echo "  Frontend:  http://localhost:3000"
echo "  Backend:   http://localhost:8080"
echo "  PostgreSQL: localhost:5432"
echo ""
echo "Ctrl+C で全て停止します"
echo ""

wait
