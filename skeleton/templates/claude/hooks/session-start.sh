#!/bin/bash
# SessionStart hook — 通用 Agent 自动启动
# 1. 检测首次运行（.env 不存在）
# 2. 启动 Dashboard 服务
# 3. 自动扫描并启动所有 Plugin

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // empty')

if [ "$SOURCE" != "startup" ]; then
  exit 0
fi

# === 首次运行检测 ===
if [ ! -f "$CLAUDE_PROJECT_DIR/.env" ]; then
  cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "【首次运行检测】检测到 .env 文件不存在，这是首次运行或新环境。请执行 CLAUDE.md 中的首次运行引导流程，帮助用户完成初始化配置。不要执行正常启动序列。"
  }
}
EOF
  exit 0
fi

# === 正常启动 ===

# 启动 Dashboard 服务器（如果未运行）
DASHBOARD_SCRIPT="$CLAUDE_PROJECT_DIR/web/start-dashboard.sh"
if [ -f "$DASHBOARD_SCRIPT" ]; then
  bash "$DASHBOARD_SCRIPT" >/dev/null 2>&1
fi

# === 自动发现并启动所有 Plugin ===
PLUGINS_DIR="$CLAUDE_PROJECT_DIR/plugins"
PLUGIN_STATUS=""
if [ -d "$PLUGINS_DIR" ]; then
  for plugin_dir in "$PLUGINS_DIR"/*/; do
    [ -d "$plugin_dir" ] || continue
    plugin_name=$(basename "$plugin_dir")
    [ "$plugin_name" = "_example" ] && continue

    start_script="$plugin_dir/start.sh"
    if [ -f "$start_script" ]; then
      bash "$start_script" "$CLAUDE_PROJECT_DIR" >/dev/null 2>&1 || true
      PLUGIN_STATUS="${PLUGIN_STATUS}\n- ${plugin_name}: started"
    fi
  done
fi

cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "【Agent 启动】请按 CLAUDE.md 启动序列自动执行，不要询问用户：\n1. 检查 Dashboard 服务: curl -sf http://localhost:7890/api/health，如未运行: bash web/start-dashboard.sh\n2. 打开浏览器: open http://localhost:7890\n3. 读取 entities.yaml → curl POST http://localhost:7890/api/server/init 初始化实体\n4. 读取 memory/*.md → curl POST /api/server/:alias/status 加载已知状态\n5. curl POST http://localhost:7890/api/claude/status -d '{\"status\":\"connected\"}'\n6. 如 CLAUDE.md 定义了 Team 模式 → 创建 Team + spawn Workers（参照 CLAUDE.md 中 Team 段落）\n7. 启动后台轮询: bash scripts/dashboard-poll.sh（run_in_background, timeout 600000）\n8. Plugin 巡检 — curl -sf http://localhost:7890/api/cron/status 检查各 plugin daemon 状态\n9. 报告就绪\n\n【轮询重启铁律】每次处理完 Dashboard 消息后，必须立即重新启动后台轮询，不重启 = Claude 变聋。\n【plugin_report 消息】收到 plugin_report 时：读取摘要 → 有异常则深入分析 → 如配置了通知则推送结果。"
  }
}
EOF
