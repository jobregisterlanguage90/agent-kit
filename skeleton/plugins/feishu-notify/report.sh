#!/bin/bash
# 飞书多维表格汇报 + IM 直发
# 通用子命令架构：每个子命令对应一张 Bitable 表
#
# 用法：
#   report.sh <子命令> [参数...]
#   report.sh record <table_key> field1=val1 field2=val2 ...
#
# 子命令由项目按需添加。通用 record 子命令支持任意表写入。
# table_key 对应 .env 中的 FEISHU_{TABLE_KEY}_TABLE_ID

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOG_FILE="$PROJECT_DIR/data/feishu-report.log"

# 加载 .env
source "$PROJECT_DIR/.env" 2>/dev/null || true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] feishu-report: $*" >> "$LOG_FILE" 2>/dev/null || true; }

# 检查必要变量
if [ -z "${FEISHU_APP_ID:-}" ] || [ -z "${FEISHU_APP_SECRET:-}" ]; then
  log "FEISHU_APP_ID / FEISHU_APP_SECRET 未配置，跳过"
  exit 0
fi

# ── 获取飞书 access token ──────────────────────────────────────────────────
get_token() {
  local resp
  resp=$(curl -sf -X POST "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
    -H "Content-Type: application/json" \
    -d "{\"app_id\":\"$FEISHU_APP_ID\",\"app_secret\":\"$FEISHU_APP_SECRET\"}" 2>/dev/null) || {
    log "获取 token 失败"
    exit 0
  }
  echo "$resp" | jq -r '.tenant_access_token // empty'
}

# ── 插入 Bitable 行 ───────────────────────────────────────────────────────
insert_record() {
  local token="$1" table_id="$2" fields_json="$3"
  local app_token="${FEISHU_BITABLE_APP_TOKEN:-}"
  if [ -z "$app_token" ] || [ -z "$table_id" ]; then
    log "Bitable APP_TOKEN 或 TABLE_ID 未配置，跳过"
    return 0
  fi
  local result
  result=$(curl -sf -X POST \
    "https://open.feishu.cn/open-apis/bitable/v1/apps/$app_token/tables/$table_id/records" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    -d "{\"fields\": $fields_json}" 2>/dev/null) || { log "插入记录失败"; return 0; }
  local code
  code=$(echo "$result" | jq -r '.code // -1')
  [ "$code" = "0" ] && log "Bitable 记录插入成功 (table: $table_id)" || log "Bitable 插入异常: $result"
}

# ── 直接给配置用户发 IM 消息卡片 ─────────────────────────────────────────
send_im_direct() {
  local token="$1" card_json="$2"
  local uids="${FEISHU_NOTIFY_USER_IDS:-}"
  [ -z "$uids" ] && return 0

  IFS=',' read -ra uid_arr <<< "$uids"
  for uid in "${uid_arr[@]}"; do
    uid="${uid// /}"
    [ -z "$uid" ] && continue
    local body
    body=$(jq -n --arg uid "$uid" --arg card "$card_json" \
      '{"receive_id":$uid,"msg_type":"interactive","content":$card}')
    local result
    result=$(curl -sf -X POST \
      "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      -d "$body" 2>/dev/null) || { log "IM 发送失败 ($uid)"; continue; }
    local code
    code=$(echo "$result" | jq -r '.code // -1')
    [ "$code" = "0" ] && log "IM 消息已发送 ($uid)" || log "IM 发送异常 ($uid): $result"
  done
}

# ── 发群消息卡片（警告时触发）─────────────────────────────────────────────
send_webhook_card() {
  local title="$1" content="$2" color="$3"
  local webhook="${FEISHU_WEBHOOK_URL:-}"
  [ -z "$webhook" ] && return 0
  local card
  card=$(jq -n \
    --arg title "$title" \
    --arg content "$content" \
    --arg color "$color" \
    '{
      msg_type: "interactive",
      card: {
        config: {wide_screen_mode: true},
        header: {
          template: $color,
          title: {tag: "plain_text", content: $title}
        },
        elements: [{
          tag: "div",
          text: {tag: "lark_md", content: $content}
        }]
      }
    }')
  curl -sf -X POST "$webhook" -H "Content-Type: application/json" -d "$card" > /dev/null 2>&1 \
    && log "群消息发送成功" || log "群消息发送失败"
}

# ── 通用子命令：record（任意表写入）────────────────────────────────────────
# 用法：report.sh record <TABLE_KEY> field1=val1 field2=val2
# TABLE_KEY 对应 .env 中的 FEISHU_{TABLE_KEY}_TABLE_ID
cmd_record() {
  local table_key="$1"; shift
  local env_var="FEISHU_${table_key}_TABLE_ID"
  local table_id="${!env_var:-}"

  if [ -z "$table_id" ]; then
    log "表 ID 未配置: $env_var"
    exit 0
  fi

  # 解析 key=value 参数为 JSON
  local fields="{}"
  for arg in "$@"; do
    local key="${arg%%=*}"
    local val="${arg#*=}"
    # 尝试数字，否则字符串
    if [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      fields=$(echo "$fields" | jq --arg k "$key" --argjson v "$val" '. + {($k): $v}')
    else
      fields=$(echo "$fields" | jq --arg k "$key" --arg v "$val" '. + {($k): $v}')
    fi
  done

  local token
  token=$(get_token) || exit 0
  [ -z "$token" ] && exit 0

  insert_record "$token" "$table_id" "$fields"
  log "通用记录写入完成: table_key=$table_key"
}

# ── 通用子命令：notify（IM 直发简单卡片）──────────────────────────────────
# 用法：report.sh notify "标题" "内容" [颜色:green|yellow|red|blue]
cmd_notify() {
  local title="$1" content="$2" color="${3:-green}"

  local token
  token=$(get_token) || exit 0
  [ -z "$token" ] && exit 0

  local im_card
  im_card=$(jq -nc \
    --arg color "$color" \
    --arg title "$title" \
    --arg content "$content" \
    '{
      config: {wide_screen_mode: true},
      header: {
        template: $color,
        title: {tag: "plain_text", content: $title}
      },
      elements: [
        {tag: "div", text: {tag: "lark_md", content: $content}}
      ]
    }')
  send_im_direct "$token" "$im_card"
  log "IM 通知已发送: $title"
}

# ── 主入口 ────────────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
  record) cmd_record "$@" ;;
  notify) cmd_notify "$@" ;;
  *)
    echo "飞书多维表格汇报工具"
    echo ""
    echo "通用子命令："
    echo "  record <TABLE_KEY> field1=val1 field2=val2   写入任意表"
    echo "  notify <标题> <内容> [颜色]                   IM 直发卡片"
    echo ""
    echo "TABLE_KEY 对应 .env 中的 FEISHU_{TABLE_KEY}_TABLE_ID"
    echo "项目可在此文件中添加自定义子命令（如 cf, health, deploy 等）"
    exit 1
    ;;
esac
