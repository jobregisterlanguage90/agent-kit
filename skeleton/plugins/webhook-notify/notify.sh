#!/bin/bash
# 通用 Webhook 通知推送
# 用法: bash plugins/webhook-notify/notify.sh "标题" "内容" [级别:info|warn|error]
# 自动检测平台类型：飞书群 Bot / Slack / Discord / 自定义

TITLE="$1"; BODY="$2"; LEVEL="${3:-info}"
PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

# 加载 .env
source "$PROJECT_DIR/.env" 2>/dev/null || true

[ -z "${WEBHOOK_URL:-}" ] && exit 0  # 未配置则静默跳过

WEBHOOK_TYPE="${WEBHOOK_TYPE:-feishu}"

case "$WEBHOOK_TYPE" in
  feishu)
    # 飞书群 Webhook（卡片消息）
    COLOR="green"
    [ "$LEVEL" = "warn" ] && COLOR="yellow"
    [ "$LEVEL" = "error" ] && COLOR="red"
    curl -sf -X POST "$WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "$(jq -n --arg t "$TITLE" --arg b "$BODY" --arg c "$COLOR" \
        '{msg_type:"interactive",card:{config:{wide_screen_mode:true},header:{template:$c,title:{tag:"plain_text",content:$t}},elements:[{tag:"div",text:{tag:"lark_md",content:$b}}]}}')" \
      > /dev/null 2>&1
    ;;
  slack)
    curl -sf -X POST "$WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "$(jq -n --arg t "$TITLE" --arg b "$BODY" '{text:($t + "\n" + $b)}')" \
      > /dev/null 2>&1
    ;;
  discord)
    COLOR=3066993  # green
    [ "$LEVEL" = "warn" ] && COLOR=15844367
    [ "$LEVEL" = "error" ] && COLOR=15158332
    curl -sf -X POST "$WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "$(jq -n --arg t "$TITLE" --arg b "$BODY" --argjson c "$COLOR" \
        '{embeds:[{title:$t,description:$b,color:$c}]}')" \
      > /dev/null 2>&1
    ;;
  *)
    # 自定义 — POST JSON body
    curl -sf -X POST "$WEBHOOK_URL" \
      -H 'Content-Type: application/json' \
      -d "$(jq -n --arg t "$TITLE" --arg b "$BODY" --arg l "$LEVEL" \
        '{title:$t,body:$b,level:$l}')" \
      > /dev/null 2>&1
    ;;
esac
