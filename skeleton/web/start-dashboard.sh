#!/bin/bash
# 启动 Dashboard 服务器（如果未运行）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/.dashboard.pid"
LOG_FILE="$SCRIPT_DIR/dashboard.log"
PORT="${DASHBOARD_PORT:-7890}"

# 检查是否已在运行
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "Dashboard 已在运行 (PID: $PID, 端口: $PORT)"
    exit 0
  else
    rm -f "$PID_FILE"
  fi
fi

# 检查端口是否被占用
if lsof -ti:"$PORT" >/dev/null 2>&1; then
  echo "端口 $PORT 已被占用"
  exit 1
fi

# 检查 node_modules
if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
  echo "安装依赖..."
  cd "$SCRIPT_DIR" && npm install --silent
fi

# 启动服务器
cd "$SCRIPT_DIR"
nohup node server.js > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "Dashboard 已启动 (PID: $!, 端口: $PORT)"
