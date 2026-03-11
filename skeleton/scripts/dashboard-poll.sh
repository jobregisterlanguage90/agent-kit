#!/bin/bash
# Dashboard 消息轮询后台脚本
# 每 3 秒检查消息队列，发现消息后合并输出并退出

POLL_PID_FILE="/tmp/claude-dashboard-poll.pid"
DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"

if [ -f "$POLL_PID_FILE" ]; then kill $(cat "$POLL_PID_FILE") 2>/dev/null; fi
echo $$ > "$POLL_PID_FILE"

ALL_MESSAGES="[]"

while true; do
  result=$(curl -sf http://localhost:${DASHBOARD_PORT}/api/messages 2>/dev/null)
  count=$(echo "$result" | jq '.messages | length' 2>/dev/null)

  if [ "$count" -gt "0" ] 2>/dev/null; then
    new_msgs=$(echo "$result" | jq '.messages')
    ALL_MESSAGES=$(echo "$ALL_MESSAGES $new_msgs" | jq -s 'add')

    # 合并窗口：再等 3 秒看有没有更多消息
    sleep 3
    result2=$(curl -sf http://localhost:${DASHBOARD_PORT}/api/messages 2>/dev/null)
    count2=$(echo "$result2" | jq '.messages | length' 2>/dev/null)
    if [ "$count2" -gt "0" ] 2>/dev/null; then
      new_msgs2=$(echo "$result2" | jq '.messages')
      ALL_MESSAGES=$(echo "$ALL_MESSAGES $new_msgs2" | jq -s 'add')
    fi

    total=$(echo "$ALL_MESSAGES" | jq 'length')
    echo "=== Dashboard 新消息 (共 ${total} 条) ==="
    echo "$ALL_MESSAGES" | jq '.[]'
    rm -f "$POLL_PID_FILE"
    exit 0
  fi

  sleep 3
done
