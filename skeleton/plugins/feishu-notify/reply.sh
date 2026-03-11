#!/bin/bash
# 通过飞书 API 回复消息（支持文本和卡片）
# 用法：
#   bash plugins/feishu-notify/reply.sh {message_id} "{回复文字}"
#   bash plugins/feishu-notify/reply.sh {message_id} --card "{卡片JSON}"

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MESSAGE_ID="${1:-}"
MODE="text"
REPLY_TEXT=""

if [ "${2:-}" = "--card" ]; then
  MODE="card"
  REPLY_TEXT="${3:-}"
else
  REPLY_TEXT="${2:-}"
fi

if [ -z "$MESSAGE_ID" ] || [ -z "$REPLY_TEXT" ]; then
  echo "用法：$0 <message_id> <回复文字>"
  echo "       $0 <message_id> --card '<卡片JSON>'"
  exit 1
fi

# 加载 .env
source "$PROJECT_DIR/.env" 2>/dev/null || true

APP_ID="${FEISHU_APP_ID:-}"
APP_SECRET="${FEISHU_APP_SECRET:-}"

if [ -z "$APP_ID" ] || [ -z "$APP_SECRET" ]; then
  exit 0
fi

# 获取 tenant_access_token
TOKEN=$(curl -sf -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | jq -r '.tenant_access_token // empty')

if [ -z "$TOKEN" ]; then
  echo "获取飞书 token 失败"
  exit 0
fi

# 构造回复内容
if [ "$MODE" = "card" ]; then
  BODY=$(jq -n --arg card "$REPLY_TEXT" '{"msg_type":"interactive","content":$card}')
else
  CONTENT=$(jq -n --arg text "$REPLY_TEXT" '{"text":$text}' | jq -c .)
  BODY=$(jq -n --arg content "$CONTENT" '{"msg_type":"text","content":$content}')
fi

RESULT=$(curl -sf -X POST \
  "https://open.feishu.cn/open-apis/im/v1/messages/${MESSAGE_ID}/reply" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" 2>/dev/null) || { echo "飞书回复请求失败"; exit 0; }

CODE=$(echo "$RESULT" | jq -r '.code // -1')
if [ "$CODE" = "0" ]; then
  echo "飞书回复成功"
else
  echo "飞书回复失败: $RESULT"
fi
