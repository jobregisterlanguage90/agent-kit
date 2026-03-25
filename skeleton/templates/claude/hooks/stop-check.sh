#!/bin/bash
# Stop hook — 操作完成后自动检查 Dashboard 消息 + 中心化状态协议恢复
# 防止无限循环：stop_hook_active=true 时直接退出

INPUT=$(cat)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')

# 二次触发（已经检查过了），允许 Claude 正常停止
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT_NAME=$(basename "$PROJECT_DIR")
POLL_PID_FILE="/tmp/claude-${PROJECT_NAME}-dashboard-poll.pid"
DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"
BASE_URL="http://localhost:${DASHBOARD_PORT}"
POLL_WAS_DEAD=false

# 检查轮询进程是否存活
POLL_ALIVE=false
if [ -f "$POLL_PID_FILE" ]; then
  POLL_PID=$(cat "$POLL_PID_FILE")
  kill -0 "$POLL_PID" 2>/dev/null && POLL_ALIVE=true
fi

# Poll 死了 → 自动用 nohup DAEMON_MODE 重启（备用保活）
if [ "$POLL_ALIVE" = "false" ]; then
  nohup env DAEMON_MODE=1 DASHBOARD_PORT="$DASHBOARD_PORT" bash "$PROJECT_DIR/scripts/dashboard-poll.sh" > /tmp/claude-${PROJECT_NAME}-poll.log 2>&1 &
  POLL_WAS_DEAD=true
fi

# 直接读取消息队列（不让 Claude 自己去 curl）
MESSAGES_JSON=$(curl -sf "$BASE_URL/api/messages" 2>/dev/null || echo '{"messages":[]}')
MSG_COUNT=$(echo "$MESSAGES_JSON" | jq '.messages | length' 2>/dev/null || echo 0)

# ── 读取 Worker 文件状态（辅助 Claude 做决策）──────────────────────────────
WORKER_FILE="$PROJECT_DIR/data/worker-ids.json"
WORKER_FILE_EXISTS="false"
if [ -f "$WORKER_FILE" ]; then
  WORKER_FILE_EXISTS="true"
fi

HEALTH_JSON=$(curl -sf "$BASE_URL/api/team/health" 2>/dev/null)
WORKER_ALIVE_COUNT="unknown"
WORKER_DEAD_NAMES=""
if [ -n "$HEALTH_JSON" ]; then
  WORKER_ALIVE_COUNT=$(echo "$HEALTH_JSON" | jq -r '.alive // "unknown"' 2>/dev/null)
  WORKER_DEAD_NAMES=$(echo "$HEALTH_JSON" | jq -r '(.dead // []) | join(",")' 2>/dev/null)
fi

# ── 读取状态注册表（中心化状态协议）──────────────────────
WORKER_STATES=$(curl -sf "$BASE_URL/api/worker/states" 2>/dev/null || echo "{}")
WORKER_STATE_SUMMARY=""
EXPECTED=$(echo "$HEALTH_JSON" | jq -r '.expected // 4' 2>/dev/null)
WORKER_NAMES=$(echo "$WORKER_STATES" | jq -r 'keys[]' 2>/dev/null)
for w in $WORKER_NAMES; do
  ws=$(echo "$WORKER_STATES" | jq -r ".\"$w\".status // \"unknown\"" 2>/dev/null)
  wt=$(echo "$WORKER_STATES" | jq -r ".\"$w\".task // \"无\"" 2>/dev/null)
  WORKER_STATE_SUMMARY="$WORKER_STATE_SUMMARY  $w: status=$ws, task=$wt\n"
done

# ── 构建上下文自检指令（中心化协议版：先读账本，精准恢复）──────────────────────
STATE_CHECK="
【上下文状态自检 — 中心化状态协议】
① run_in_background poll task ID 是否存在？
  → 没有：立即 run_in_background bash scripts/dashboard-poll.sh
② Workers 状态（读账本，不盲目重建）：
    Dashboard alive=${WORKER_ALIVE_COUNT}/${EXPECTED}, dead=[${WORKER_DEAD_NAMES}]
    状态注册表：
$(echo -e "$WORKER_STATE_SUMMARY")
    恢复策略（精准恢复，仅重建确认死亡的 Worker）：
      alive=${EXPECTED} → 直接代发心跳，无需重建
      alive>0 → 只对 dead 的 Worker 执行：SendMessage ping，60s 无回复才 spawn
      alive=0 → 先代发心跳刷新，再查 health；仍为 0 才逐个 spawn
      状态=busy 的 → 不动（正在执行任务）
    禁止全量 TeamDelete + 重建所有 Worker"

if [ "$MSG_COUNT" -gt "0" ] 2>/dev/null; then
  SUMMARY=""
  while IFS= read -r msg_line; do
    msg_type=$(echo "$msg_line" | jq -r '.type' 2>/dev/null)
    msg_text=$(echo "$msg_line" | jq -r '.text // .action // "" | .[0:80]' 2>/dev/null)
    SUMMARY="${SUMMARY}  [${msg_type}] ${msg_text}
"
  done < <(echo "$MESSAGES_JSON" | jq -c '.messages[:5][]' 2>/dev/null)

  DEAD_NOTE=""
  if [ "$POLL_WAS_DEAD" = "true" ]; then
    DEAD_NOTE=" ⚠️ 轮询已死，已自动重启(nohup DAEMON_MODE)。"
  fi
  REASON="${MSG_COUNT} 条待处理消息（已读取，可直接处理）：
${SUMMARY}${DEAD_NOTE}
${STATE_CHECK}"
  jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
  exit 0
fi

# 无消息 + Poll 刚死过
if [ "$POLL_WAS_DEAD" = "true" ]; then
  REASON="⚠️ 轮询已死，已自动重启(nohup DAEMON_MODE)，当前无积压消息。
请用 run_in_background 重启 bash scripts/dashboard-poll.sh 恢复主动唤醒。
${STATE_CHECK}"
  jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
  exit 0
fi

# 无消息 + Poll 正常 → 直接退出
exit 0
