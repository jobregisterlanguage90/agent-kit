#!/bin/bash
# 示例 Plugin 启动脚本
# 由 session-start.sh hook 自动调用

PROJECT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PLUGIN_NAME="example-monitor"
PID_FILE="/tmp/claude-${PLUGIN_NAME}.pid"

# 检查依赖环境变量（缺失则静默跳过）
source "$PROJECT_DIR/.env" 2>/dev/null
[ -z "$EXAMPLE_API_TOKEN" ] && exit 0

# 检查是否已运行
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  exit 0
fi

# 启动守护进程
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
nohup bash "$SCRIPT_DIR/daemon.sh" "$PROJECT_DIR" > /dev/null 2>&1 &
echo "Plugin $PLUGIN_NAME started (PID: $!)"
