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
if echo "$LAST_MSG" | grep -qiE "(ssh |curl |检查|巡检|部署|deploy|分析|报告|monitor|health|error|失败|不确定|不清楚|WebSearch|Lighthouse)"; then
  PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
  QUEUE_FILE="$PROJECT_DIR/memory/knowledge/learning-queue.md"
  PENDING=0
  [ -f "$QUEUE_FILE" ] && PENDING=$(grep -c '| pending |' "$QUEUE_FILE" 2>/dev/null || echo "0")

  # 检查是否有最近的学习成果可关联验证
  LEARN_EXTRA=""
  LATEST_REPORT=$(ls -t "$PROJECT_DIR/data/learning-reports/"*.json 2>/dev/null | head -1)
  if [ -n "$LATEST_REPORT" ]; then
    REPORT_MTIME=$(stat -f %m "$LATEST_REPORT" 2>/dev/null || stat -c %Y "$LATEST_REPORT" 2>/dev/null || echo 0)
    REPORT_AGE=$(( $(date +%s) - REPORT_MTIME ))
    if [ "$REPORT_AGE" -lt 86400 ]; then
      TOPIC=$(jq -r '.topic // "未知"' "$LATEST_REPORT" 2>/dev/null)
      LEARN_EXTRA=" 另外，你最近学习了「${TOPIC}」，如果刚才的工作涉及相关领域，反思下学到的知识是否正确应用了。"
    fi
  fi

  cat << EOF
{
  "continue": true,
  "systemMessage": "【学习反思】这轮工作中有没有遇到不确定的、回答不够好的、或不知道最佳实践的地方？如果有，用一句话写入 memory/knowledge/learning-queue.md（格式：| P1/P2 | 课题 | 来源 | 今天日期 | pending |）。当前待学 ${PENDING} 个课题。如果没有盲区就忽略这条提醒。${LEARN_EXTRA}"
}
EOF
  exit 0
fi

exit 0
