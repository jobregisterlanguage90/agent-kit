#!/bin/bash
# 示例 Plugin 守护进程 — 定时执行业务逻辑
# 用法: nohup bash plugins/example-monitor/daemon.sh [project_dir] &

PROJECT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
[ -f "$PROJECT_DIR/.env" ] && { set -a; source "$PROJECT_DIR/.env"; set +a; }
PROJECT_NAME=$(basename "$PROJECT_DIR")
PLUGIN_NAME="example-monitor"
PID_FILE="/tmp/claude-${PROJECT_NAME}-${PLUGIN_NAME}.pid"
LOG_FILE="$PROJECT_DIR/data/reports/${PLUGIN_NAME}.log"
INTERVAL=3600
DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"

# === PID 防重复 ===
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Daemon already running (PID: $OLD_PID)"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

mkdir -p "$(dirname "$LOG_FILE")"
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
log "$PLUGIN_NAME daemon started (PID: $$, interval: ${INTERVAL}s)"

while true; do
  # sleep 在循环开头 → 启动时不立即执行
  sleep "$INTERVAL"

  log "Starting check..."

  # ========================================
  # === 在这里编写你的业务逻辑 ===
  # 例如：API 调用、数据抓取、文件检查等
  RESULT="检查完成，一切正常"
  # ========================================

  log "Check complete: $RESULT"

  # === 注入 Dashboard 消息队列 ===
  curl -sf -X POST "http://localhost:${DASHBOARD_PORT}/api/messages" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg text "$RESULT" --arg plugin "$PLUGIN_NAME" \
      '{type:"plugin_report", plugin:$plugin, text:$text}')" \
    >> "$LOG_FILE" 2>&1 || log "Dashboard unreachable, result logged only"

  # === 推送外部通知（防止漏通知！）===
  # 教训：daemon 只注入消息队列但不推送通知 = 没人知道结果
  # 如果项目安装了通知 Plugin，在这里调用：
  if [ -f "$PROJECT_DIR/plugins/webhook-notify/notify.sh" ]; then
    bash "$PROJECT_DIR/plugins/webhook-notify/notify.sh" "$PLUGIN_NAME 报告" "$RESULT" || true
  fi
  # 如果有飞书 report 需求（取消注释并修改参数）：
  # bash "$PROJECT_DIR/plugins/feishu-notify/report.sh" <table_key> <fields...> || true

  log "Sleeping ${INTERVAL}s until next check"
done
