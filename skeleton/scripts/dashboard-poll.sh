#!/bin/bash
# Dashboard 消息轮询后台脚本
# 正常模式（DAEMON_MODE=0）：每 3 秒检查消息队列，发现消息后合并输出并退出唤醒 Claude
# 守护模式（DAEMON_MODE=1）：跳过消息轮询（不消费队列），只维持心跳 + Worker 健康检查
# 每 60 秒检查 Team Worker 心跳，缺失时注入 ping_worker 消息

PROJECT_NAME=$(basename "${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}")
POLL_PID_FILE="/tmp/claude-${PROJECT_NAME}-dashboard-poll.pid"
DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"
BASE_URL="http://localhost:${DASHBOARD_PORT}"
DAEMON_MODE="${DAEMON_MODE:-0}"

if [ -f "$POLL_PID_FILE" ]; then kill $(cat "$POLL_PID_FILE") 2>/dev/null; fi
echo $$ > "$POLL_PID_FILE"

ALL_MESSAGES="[]"
HEALTH_CHECK_INTERVAL=60
LAST_HEALTH_CHECK=$(date +%s)
LAST_PING_TIME=0
PING_COOLDOWN=3600  # 1 小时内不重复 ping 同一个 worker

while true; do

  # 仅正常模式轮询消息（DAEMON_MODE=1 时跳过，避免消费队列但无法唤醒 Claude）
  if [ "$DAEMON_MODE" != "1" ]; then
    result=$(curl -sf "$BASE_URL/api/messages" 2>/dev/null)
    count=$(echo "$result" | jq '.messages | length' 2>/dev/null)

    if [ "$count" -gt "0" ] 2>/dev/null; then
      new_msgs=$(echo "$result" | jq '.messages')
      ALL_MESSAGES=$(echo "$ALL_MESSAGES $new_msgs" | jq -s 'add')

      # 合并窗口：再等 3 秒看有没有更多消息
      sleep 3
      result2=$(curl -sf "$BASE_URL/api/messages" 2>/dev/null)
      count2=$(echo "$result2" | jq '.messages | length' 2>/dev/null)
      if [ "$count2" -gt "0" ] 2>/dev/null; then
        new_msgs2=$(echo "$result2" | jq '.messages')
        ALL_MESSAGES=$(echo "$ALL_MESSAGES $new_msgs2" | jq -s 'add')
      fi

      total=$(echo "$ALL_MESSAGES" | jq 'length')
      echo "=== Dashboard 新消息 (共 ${total} 条) ==="
      echo "$ALL_MESSAGES" | jq '.[]'

      # 退出前自启 DAEMON_MODE 副本保活（只做心跳，不消费消息队列）
      SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
      nohup env DAEMON_MODE=1 DASHBOARD_PORT="$DASHBOARD_PORT" bash "$SCRIPT_PATH" > /tmp/claude-${PROJECT_NAME}-poll.log 2>&1 &

      rm -f "$POLL_PID_FILE"
      exit 0
    fi
  fi

  # 定期检查 Team Worker 健康（两种模式都执行）
  NOW=$(date +%s)
  ELAPSED=$(( NOW - LAST_HEALTH_CHECK ))
  if [ "$ELAPSED" -ge "$HEALTH_CHECK_INTERVAL" ]; then
    LAST_HEALTH_CHECK=$NOW
    health=$(curl -sf "$BASE_URL/api/team/health" 2>/dev/null)
    if [ -n "$health" ]; then
      alive=$(echo "$health" | jq '.alive' 2>/dev/null)
      expected=$(echo "$health" | jq '.expected' 2>/dev/null)
      if [ "$alive" != "null" ] && [ "$expected" != "null" ] && [ "$alive" -lt "$expected" ] 2>/dev/null; then
        dead_workers=$(echo "$health" | jq -r '.dead[]' 2>/dev/null)
        PING_NEEDED=""
        for worker in $dead_workers; do
          # 读账本：查该 worker 最近状态
          ws=$(curl -sf "$BASE_URL/api/worker/state/$worker" 2>/dev/null)
          ws_status=$(echo "$ws" | jq -r '.status // "unknown"' 2>/dev/null)
          ws_update=$(echo "$ws" | jq -r '.lastUpdate // 0' 2>/dev/null)
          age=$(( NOW * 1000 - ws_update ))
          age_min=$(( age / 60000 ))

          # busy 且 < 30 分钟 → 正在执行任务，跳过
          if [ "$ws_status" = "busy" ] && [ "$age_min" -lt 30 ]; then
            continue
          fi

          PING_NEEDED="$PING_NEEDED $worker"
        done

        # 冷却检查：1 小时内不重复 ping
        if [ -n "$PING_NEEDED" ] && [ $(( NOW - LAST_PING_TIME )) -gt "$PING_COOLDOWN" ]; then
          LAST_PING_TIME=$NOW
          for worker in $PING_NEEDED; do
            curl -sf -X POST "$BASE_URL/api/messages" \
              -H 'Content-Type: application/json' \
              -d "{\"type\":\"ping_worker\",\"worker\":\"$worker\",\"text\":\"Worker $worker 心跳过期，请 ping 确认存活\"}" \
              > /dev/null 2>&1
          done
        fi
      fi
    fi
  fi

  sleep 3
done
