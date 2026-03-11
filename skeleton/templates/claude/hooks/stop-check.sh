#!/bin/bash
# Stop hook — 退出前检查 Dashboard 消息
# 第一次调用：阻止退出，提醒检查
# 第二次调用：允许退出

INPUT=$(cat)

# 检查 Dashboard 是否有待处理消息
result=$(curl -sf http://localhost:${DASHBOARD_PORT:-7890}/api/messages 2>/dev/null)
count=$(echo "$result" | jq '.messages | length' 2>/dev/null)

if [ "$count" -gt "0" ] 2>/dev/null; then
  echo "Dashboard 有 ${count} 条未处理消息，请先处理再退出。"
  echo "$result" | jq '.messages[]'
fi
