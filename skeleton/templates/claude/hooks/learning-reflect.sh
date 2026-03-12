#!/bin/bash
# Stop Hook — 每轮工作后反思知识盲区
# 事件驱动：Agent 回复完自动触发，不依赖 CLAUDE.md 规则记忆

INPUT=$(cat)
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name')

[ "$EVENT" != "Stop" ] && exit 0

# 防止无限循环：反思回复本身也会触发 Stop，第二次跳过
STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
[ "$STOP_ACTIVE" = "true" ] && exit 0

LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""')

# 只在做了实际工作时触发（过滤闲聊和简单回复）
# 可根据项目特点自定义关键词
if echo "$LAST_MSG" | grep -qiE "(ssh |curl |检查|巡检|部署|deploy|分析|报告|monitor|health|error|失败|不确定|不清楚|WebSearch)"; then
  QUEUE_FILE="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/memory/knowledge/learning-queue.md"
  PENDING=0
  [ -f "$QUEUE_FILE" ] && PENDING=$(grep -c '| pending |' "$QUEUE_FILE" 2>/dev/null || echo "0")

  cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "Stop",
    "additionalContext": "【学习反思】这轮工作中有没有遇到不确定的、回答不够好的、或不知道最佳实践的地方？如果有，用一句话写入 memory/knowledge/learning-queue.md（格式：| P1/P2 | 课题 | 来源 | 今天日期 | pending |）。当前待学 ${PENDING} 个课题。如果没有盲区就忽略这条提醒。"
  }
}
EOF
  exit 0
fi

exit 0
