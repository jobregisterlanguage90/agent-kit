#!/bin/bash
# 跨进程通信 — 发现和联络同网络的其他 Kit 实例
# 用法：
#   bash scripts/cross-process.sh discover          # 发现 peers
#   bash scripts/cross-process.sh send <port> "msg"  # 发送消息

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }

CROSS_PROCESS_ENABLED="${CROSS_PROCESS_ENABLED:-false}"
CROSS_PROCESS_PEERS="${CROSS_PROCESS_PEERS:-}"
DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"

discover_peers() {
  echo "=== 发现 Kit 实例 ==="
  local found=0

  # 从配置读取已知 peers
  if [ -n "$CROSS_PROCESS_PEERS" ]; then
    IFS=',' read -ra PORTS <<< "$CROSS_PROCESS_PEERS"
    for port in "${PORTS[@]}"; do
      port=$(echo "$port" | tr -d ' ')
      [ "$port" = "$DASHBOARD_PORT" ] && continue
      local health
      health=$(curl -sf "http://localhost:$port/api/health" 2>/dev/null)
      if [ -n "$health" ]; then
        echo "  ✅ localhost:$port — 在线"
        found=$((found + 1))
      else
        echo "  ❌ localhost:$port — 离线"
      fi
    done
  fi

  # 扫描常用端口范围
  for port in 7890 7891 7892 7893 7894 7895; do
    [ "$port" = "$DASHBOARD_PORT" ] && continue
    echo "$CROSS_PROCESS_PEERS" | grep -q "$port" && continue
    local health
    health=$(curl -sf --connect-timeout 1 "http://localhost:$port/api/health" 2>/dev/null)
    if [ -n "$health" ]; then
      echo "  🔍 localhost:$port — 发现未配置的实例"
      found=$((found + 1))
    fi
  done

  echo "  共发现 $found 个 peer"
}

send_message() {
  local target_port="$1"
  local message="$2"
  local project_name
  project_name=$(basename "$PROJECT_DIR")

  curl -sf -X POST "http://localhost:$target_port/api/messages" \
    -H 'Content-Type: application/json' \
    -d "{
      \"type\": \"cross_process\",
      \"source\": \"$project_name\",
      \"source_port\": $DASHBOARD_PORT,
      \"text\": $(echo "$message" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read().strip()))'),
      \"timestamp\": $(date +%s)000
    }"
}

case "${1:-}" in
  discover) discover_peers ;;
  send)
    [ -z "${2:-}" ] || [ -z "${3:-}" ] && { echo "用法: $0 send <port> \"message\""; exit 1; }
    send_message "$2" "$3"
    ;;
  *) echo "用法: $0 {discover|send <port> \"msg\"}"; exit 1 ;;
esac
