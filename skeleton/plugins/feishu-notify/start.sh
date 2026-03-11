#!/bin/bash
# 启动飞书长连接 Bot（nohup daemon）
# 由 session-start.sh 自动调用

PROJECT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")
PID_FILE="/tmp/claude-${PROJECT_NAME}-feishu-bot.pid"
LOG_FILE="$PROJECT_DIR/data/feishu-bot.log"

mkdir -p "$PROJECT_DIR/data"

# 防止重复实例
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Feishu Bot already running (PID: $OLD_PID)"
    exit 0
  fi
  rm -f "$PID_FILE"
fi

# 加载 .env
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a; source "$PROJECT_DIR/.env"; set +a
fi

if [ -z "${FEISHU_APP_ID:-}" ] || [ -z "${FEISHU_APP_SECRET:-}" ]; then
  # 未配置则静默跳过（不报错）
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
nohup python3 "$SCRIPT_DIR/bot.py" >> "$LOG_FILE" 2>&1 &
BOT_PID=$!
echo "$BOT_PID" > "$PID_FILE"

sleep 1
if kill -0 "$BOT_PID" 2>/dev/null; then
  echo "Feishu Bot started (PID: $BOT_PID)"
else
  echo "Feishu Bot failed to start, check: $LOG_FILE"
  rm -f "$PID_FILE"
  exit 1
fi
