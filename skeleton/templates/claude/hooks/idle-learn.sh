#!/bin/bash
# TeammateIdle Hook — Worker 空闲时自动学习
# 事件驱动：Worker 完成任务即将空闲时，检查有无待学课题

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

[ "$EVENT" != "TeammateIdle" ] && exit 0

QUEUE_FILE="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/memory/knowledge/learning-queue.md"
PENDING=0
[ -f "$QUEUE_FILE" ] && PENDING=$(grep -c '| pending |' "$QUEUE_FILE" 2>/dev/null || echo "0")

if [ "$PENDING" -gt 0 ]; then
  FIRST_TOPIC=$(grep '| pending |' "$QUEUE_FILE" | head -1 | awk -F'|' '{print $3}' | xargs)
  # exit 2 = 阻止空闲，stderr 作为 reason 让 Worker 继续
  echo "有 ${PENDING} 个待学课题（优先: ${FIRST_TOPIC}）。请调用 self-study Skill 执行学习。读取 memory/knowledge/learning-queue.md 选择 pending 课题。" >&2
  exit 2
fi

exit 0
