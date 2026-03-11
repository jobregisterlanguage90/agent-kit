#!/bin/bash
# UserPromptSubmit hook — 空输入时检查 Dashboard 消息
# 空输入 / "." / "check" → 触发 Dashboard 消息检查

INPUT=$(cat)
USER_INPUT=$(echo "$INPUT" | jq -r '.userInput // empty' | xargs)

# 非空正常输入 → 直接放行
if [ -n "$USER_INPUT" ] && [ "$USER_INPUT" != "." ] && [ "$USER_INPUT" != "check" ]; then
  exit 0
fi

# 空输入或 check → 检查 Dashboard 消息
result=$(curl -sf http://localhost:${DASHBOARD_PORT:-7890}/api/messages 2>/dev/null)
count=$(echo "$result" | jq '.messages | length' 2>/dev/null)

if [ "$count" -gt "0" ] 2>/dev/null; then
  cat << CONTEXT
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Dashboard 有 ${count} 条消息待处理:\n$(echo "$result" | jq -c '.messages[]')"
  }
}
CONTEXT
fi
