#!/bin/bash
# TeammateIdle Hook — Worker 完成任务后：反思盲区 + 自主学习
# 事件驱动：Worker 完成任务即将空闲时触发
# 双重职责：
#   1. 反思刚完成的工作中是否有知识盲区（类似主进程的 Stop hook）
#   2. 检查 learning-queue.md 有无待学课题
# 防循环：每 30 分钟最多触发一次纯反思（无学习任务时）

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

[ "$EVENT" != "TeammateIdle" ] && exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
QUEUE_FILE="$PROJECT_DIR/memory/knowledge/learning-queue.md"
REFLECT_LOCK="/tmp/claude-worker-reflect-$(echo "$INPUT" | jq -r '.teammate_name // "unknown"' | tr -cd 'a-zA-Z0-9-').last"

# 恢复 stale learning 状态（超过 24h 的 learning → pending）
curl -sf -X POST http://localhost:7890/api/learning/recover > /dev/null 2>&1 || true

PENDING=0
[ -f "$QUEUE_FILE" ] && PENDING=$(grep -c '| pending |' "$QUEUE_FILE" 2>/dev/null || echo "0")

# 有待学课题 → 反思 + 学习（始终触发）
if [ "$PENDING" -gt 0 ]; then
  FIRST_TOPIC=$(grep '| pending |' "$QUEUE_FILE" | head -1 | awk -F'|' '{print $3}' | xargs)
  date +%s > "$REFLECT_LOCK"
  cat << EOF >&2
【工作反思 + 学习】
1. 先反思：刚才的工作中有没有遇到不确定、回答不够好、或不知道最佳实践的地方？如果有，写入 memory/knowledge/learning-queue.md（格式：| P1/P2 | 课题 | 来源 | 今天日期 | pending |）。
2. 再学习：有 ${PENDING} 个待学课题（优先: ${FIRST_TOPIC}）。
   学习前必须先领取：curl -sf -X POST http://localhost:7890/api/learning/claim -H 'Content-Type: application/json' -d '{"topic":"课题名","worker_name":"你的名字"}'。
   返回 success:true 才能学，false 则选下一个。学完后 curl POST /api/learning/release 释放。
   请调用 self-study Skill 执行学习。
EOF
  exit 2
fi

# 无待学课题 → 仅反思（30 分钟冷却，防循环）
NOW=$(date +%s)
LAST=0
[ -f "$REFLECT_LOCK" ] && LAST=$(cat "$REFLECT_LOCK" 2>/dev/null | tr -d '[:space:]')
LAST="${LAST:-0}"; [[ "$LAST" =~ ^[0-9]+$ ]] || LAST=0
ELAPSED=$(( NOW - LAST ))

if [ "$ELAPSED" -ge 1800 ]; then
  date +%s > "$REFLECT_LOCK"
  cat << EOF >&2
【工作反思】刚才的工作中有没有遇到不确定、回答不够好、或不知道最佳实践的地方？如果有，用一句话写入 memory/knowledge/learning-queue.md（格式：| P1/P2 | 课题 | 来源 | 今天日期 | pending |）。如果没有盲区就说"无盲区"即可。
EOF
  exit 2
fi

# 冷却期内，允许空闲
exit 0
