#!/bin/bash
# Skill 执行辅助函数 — source 后使用
# 用法: source scripts/skill-helpers.sh

DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"
DASHBOARD_URL="http://localhost:${DASHBOARD_PORT}"

# 派遣 Worker 小人 → 返回 workerId
skill_spawn() {
  local type="$1" target="$2" label="$3"
  curl -s -X POST "$DASHBOARD_URL/api/worker/spawn" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$type" --arg tg "$target" --arg l "$label" \
      '{type:$t, target:$tg, label:$l}')" | jq -r '.workerId'
}

# 终端输出（type: command/output/error）
skill_term() {
  local wid="$1" type="$2" text="$3"
  curl -s -X POST "$DASHBOARD_URL/api/worker/$wid/term" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$type" --arg tx "$text" '{type:$t, text:$tx}')" >/dev/null
}

# 气泡文字
skill_say() {
  local wid="$1" text="$2"
  curl -s -X POST "$DASHBOARD_URL/api/worker/$wid/say" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$text" '{text:$t}')" >/dev/null
}

# 标记完成（result: success/error）
skill_done() {
  local wid="$1" result="${2:-success}" summary="$3"
  curl -s -X POST "$DASHBOARD_URL/api/worker/$wid/done" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg r "$result" --arg s "$summary" '{result:$r, summary:$s}')" >/dev/null
}

# 更新实体状态
skill_status() {
  local alias="$1"; shift
  curl -s -X POST "$DASHBOARD_URL/api/server/$alias/status" \
    -H 'Content-Type: application/json' \
    -d "$*" >/dev/null
}

# 通知推送（自动检测已安装的通知 Plugin）
skill_notify() {
  local title="$1" body="$2" level="${3:-info}"
  local project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  # 飞书 Bot reply（如消息来自飞书）
  if [ -n "$FEISHU_REPLY_MSG_ID" ] && [ -f "$project_dir/plugins/feishu-notify/reply.sh" ]; then
    bash "$project_dir/plugins/feishu-notify/reply.sh" "$FEISHU_REPLY_MSG_ID" "$body"
  fi
  # Webhook 通知
  if [ -f "$project_dir/plugins/webhook-notify/notify.sh" ]; then
    bash "$project_dir/plugins/webhook-notify/notify.sh" "$title" "$body" "$level"
  fi
}
