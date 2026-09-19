#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
PIDS=()
CLEANED=0

# バックグラウンドジョブをプロセスグループ単位で起動する。
# こうすると kill -- -PID で子プロセスごと止められる（Ctrl+Cで確実に止めるため）
set -m

# そのプロセスがこのプロジェクト配下で動いているかを判定する。
# ポート番号だけで判断すると、無関係なアプリを巻き込んでしまうためcwdで確認する
is_ours() {
    local pid="$1" cwd
    cwd=$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)
    case "$cwd" in
        "$PROJECT_ROOT"/*) return 0 ;;
        *) return 1 ;;
    esac
}

# ポートを掴んでいるプロセスのうち、このプロジェクトのものだけを止める
stop_if_ours_on_port() {
    local port="$1" pid
    for pid in $(lsof -ti "tcp:${port}" 2>/dev/null || true); do
        if is_ours "$pid"; then
            kill -KILL "$pid" 2>/dev/null || true
        else
            echo "  ポート${port}は別のアプリが使用中です → そのままにします"
        fi
    done
}

cleanup() {
    [ "$CLEANED" = "1" ] && return
    CLEANED=1

    echo ""
    echo "=== 終了処理中 ==="

    # 1) 起動したジョブをプロセスグループごと止める
    #    （フロントエンドの npm→node のような子プロセスも道連れになる）
    for pid in "${PIDS[@]}"; do
        kill -TERM -- "-${pid}" 2>/dev/null || true
    done
    sleep 1
    for pid in "${PIDS[@]}"; do
        kill -KILL -- "-${pid}" 2>/dev/null || true
    done

    # 2) Gradleデーモンは別のプロセスグループで動くため明示的に止める。
    #    bootRunのアプリはデーモンの子なので、ここで一緒に落ちる。
    #    cwdがこのプロジェクトのデーモンだけを対象にする（他プロジェクトに影響させない）
    for pid in $(pgrep -f GradleDaemon 2>/dev/null || true); do
        if is_ours "$pid"; then
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    sleep 1

    # 3) それでも残っているアプリをポートから特定して止める
    stop_if_ours_on_port 8080   # バックエンド
    stop_if_ours_on_port 3000   # フロントエンド

    # 4) アプリを止めてからDBを落とす
    #    （逆順にするとコネクションが切れてHikariPoolの警告が出る）
    docker compose -f "$PROJECT_ROOT/compose.yml" down

    echo "=== 完了 ==="
}
trap 'cleanup; exit 0' INT TERM
trap cleanup EXIT

echo "=== PostgreSQL を起動中 ==="
docker compose -f "$PROJECT_ROOT/compose.yml" up -d
sleep 2

echo "=== Backend を起動中 (port: 8080) ==="
# exec でサブシェルを置き換え、記録したPIDが実際のプロセスのリーダーになるようにする
(cd "$BACKEND_DIR" && exec ./gradlew bootRun) &
PIDS+=($!)

echo "=== Frontend を起動中 (port: 3000) ==="
(cd "$FRONTEND_DIR" && exec npm run dev) &
PIDS+=($!)

echo ""
echo "=== 開発環境が起動しました ==="
echo "  Frontend:   http://localhost:3000"
echo "  Backend:    http://localhost:8080"
echo "  PostgreSQL: localhost:5432"
echo ""
echo "Ctrl+C で全て停止します"
echo ""

wait
