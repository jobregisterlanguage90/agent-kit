#!/bin/bash
# 停止飞书 Bot daemon

PROJECT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PROJECT_NAME=$(basename "$PROJECT_DIR")
PID_FILE="/tmp/claude-${PROJECT_NAME}-feishu-bot.pid"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    echo "Feishu Bot stopped (PID: $PID)"
  fi
  rm -f "$PID_FILE"
else
  echo "Feishu Bot not running"
fi
