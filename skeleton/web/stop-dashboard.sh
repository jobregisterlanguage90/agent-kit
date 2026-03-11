#!/bin/bash
# 停止 Dashboard 服务器
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/.dashboard.pid"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    rm -f "$PID_FILE"
    echo "Dashboard 已停止 (PID: $PID)"
  else
    rm -f "$PID_FILE"
    echo "进程已不存在，已清理 PID 文件"
  fi
else
  echo "Dashboard 未在运行"
fi
