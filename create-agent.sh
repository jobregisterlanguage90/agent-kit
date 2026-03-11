#!/bin/bash
# Claude Agent Kit — 交互式创建新 Agent 项目
# 用法: bash create-agent.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKELETON_DIR="$SCRIPT_DIR/skeleton"

echo "╔══════════════════════════════════════╗"
echo "║    Claude Agent Kit — 创建新 Agent    ║"
echo "╚══════════════════════════════════════╝"
echo ""

# === 收集配置 ===
read -p "项目名称 (如 server-maintenance): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo "错误: 项目名称不能为空"
  exit 1
fi

read -p "Agent 角色描述 (如 本地多服务器运维助手): " AGENT_ROLE
AGENT_ROLE="${AGENT_ROLE:-Agent Assistant}"

read -p "实体类型 (如 server/dataset/website): " ENTITY_TYPE
ENTITY_TYPE="${ENTITY_TYPE:-entity}"

read -p "实体显示标签 (如 服务器/数据集/网站): " ENTITY_LABEL
ENTITY_LABEL="${ENTITY_LABEL:-实体}"

read -p "连接方式 (ssh/api/local) [ssh]: " CONNECT_VIA
CONNECT_VIA="${CONNECT_VIA:-ssh}"

read -p "Dashboard 端口 [7890]: " DASHBOARD_PORT
DASHBOARD_PORT="${DASHBOARD_PORT:-7890}"

read -p "Team 模式 Worker 数量 (0=不启用) [0]: " TEAM_SIZE
TEAM_SIZE="${TEAM_SIZE:-0}"

read -p "启用飞书通知? (y/n) [n]: " ENABLE_FEISHU
ENABLE_FEISHU="${ENABLE_FEISHU:-n}"

read -p "启用 Webhook 通知? (y/n) [n]: " ENABLE_WEBHOOK
ENABLE_WEBHOOK="${ENABLE_WEBHOOK:-n}"

read -p "目标目录 [$HOME/Documents/code/$PROJECT_NAME]: " TARGET_DIR
TARGET_DIR="${TARGET_DIR:-$HOME/Documents/code/$PROJECT_NAME}"

echo ""
echo "=== 配置确认 ==="
echo "  项目名称: $PROJECT_NAME"
echo "  Agent 角色: $AGENT_ROLE"
echo "  实体类型: $ENTITY_TYPE ($ENTITY_LABEL)"
echo "  连接方式: $CONNECT_VIA"
echo "  Dashboard 端口: $DASHBOARD_PORT"
echo "  Team 模式: ${TEAM_SIZE} Workers"
echo "  飞书通知: $ENABLE_FEISHU"
echo "  Webhook 通知: $ENABLE_WEBHOOK"
echo "  目标目录: $TARGET_DIR"
echo ""
read -p "确认创建? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "已取消"
  exit 0
fi

# === 检查目标目录 ===
if [ -d "$TARGET_DIR" ]; then
  echo "警告: 目录已存在 $TARGET_DIR"
  read -p "覆盖? (y/N): " OVERWRITE
  if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
    echo "已取消"
    exit 0
  fi
fi

# === 复制骨架 ===
echo ""
echo "=== 创建项目 ==="
mkdir -p "$TARGET_DIR"
cp -r "$SKELETON_DIR/"* "$TARGET_DIR/"
cp "$SKELETON_DIR/.gitignore" "$TARGET_DIR/.gitignore"

# === 变量替换 .tmpl 文件 ===
echo "  处理模板文件..."
find "$TARGET_DIR" -name "*.tmpl" | while read tmpl; do
  dest="${tmpl%.tmpl}"
  sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
      -e "s|{{AGENT_ROLE}}|$AGENT_ROLE|g" \
      -e "s|{{ENTITY_TYPE}}|$ENTITY_TYPE|g" \
      -e "s|{{ENTITY_LABEL}}|$ENTITY_LABEL|g" \
      -e "s|{{CONNECT_VIA}}|$CONNECT_VIA|g" \
      -e "s|{{DASHBOARD_PORT}}|$DASHBOARD_PORT|g" \
      -e "s|{{TEAM_SIZE}}|$TEAM_SIZE|g" \
      "$tmpl" > "$dest"
  rm "$tmpl"
  echo "  [生成] $(basename "$dest")"
done

# === Team 模式条件渲染 ===
if [ "$TEAM_SIZE" = "0" ] || [ -z "$TEAM_SIZE" ]; then
  # 删除 TEAM_MODE 段落
  if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    sed -i '' '/<!-- IF TEAM_MODE -->/,/<!-- ENDIF -->/d' "$TARGET_DIR/CLAUDE.md"
    echo "  [跳过] Team 模式（未启用）"
  fi
else
  # 保留段落，删除条件标记
  if [ -f "$TARGET_DIR/CLAUDE.md" ]; then
    sed -i '' '/<!-- IF TEAM_MODE -->/d;/<!-- ENDIF -->/d' "$TARGET_DIR/CLAUDE.md"
    echo "  [启用] Team 模式（$TEAM_SIZE Workers）"
  fi
fi

# === 可选 Plugin 处理 ===
if [ "$ENABLE_FEISHU" != "y" ] && [ "$ENABLE_FEISHU" != "Y" ]; then
  rm -rf "$TARGET_DIR/plugins/feishu-notify"
  echo "  [跳过] 飞书通知 Plugin"
else
  chmod +x "$TARGET_DIR/plugins/feishu-notify/"*.sh
  # 追加 .env.example 飞书变量
  if [ -f "$TARGET_DIR/.env.example" ]; then
    cat >> "$TARGET_DIR/.env.example" << 'FEISHU_EOF'

# === 飞书通知（可选）===
FEISHU_APP_ID=""
FEISHU_APP_SECRET=""
FEISHU_WEBHOOK_URL=""
FEISHU_NOTIFY_USER_IDS=""
FEISHU_BITABLE_APP_TOKEN=""
FEISHU_EOF
  fi
  echo "  [启用] 飞书通知 Plugin"
  echo "  提示: pip install -r plugins/feishu-notify/requirements.txt"
fi

if [ "$ENABLE_WEBHOOK" != "y" ] && [ "$ENABLE_WEBHOOK" != "Y" ]; then
  rm -rf "$TARGET_DIR/plugins/webhook-notify"
  echo "  [跳过] Webhook 通知 Plugin"
else
  chmod +x "$TARGET_DIR/plugins/webhook-notify/"*.sh
  # 追加 .env.example Webhook 变量
  if [ -f "$TARGET_DIR/.env.example" ]; then
    cat >> "$TARGET_DIR/.env.example" << 'WEBHOOK_EOF'

# === Webhook 通知（可选）===
WEBHOOK_URL=""
WEBHOOK_TYPE="feishu"    # feishu | slack | discord | custom
WEBHOOK_EOF
  fi
  echo "  [启用] Webhook 通知 Plugin"
fi

# === 设置脚本权限 ===
echo "  设置权限..."
chmod +x "$TARGET_DIR/setup.sh"
chmod +x "$TARGET_DIR/web/start-dashboard.sh"
chmod +x "$TARGET_DIR/web/stop-dashboard.sh"
chmod +x "$TARGET_DIR/scripts/dashboard-poll.sh"
chmod +x "$TARGET_DIR/templates/claude/hooks/"*.sh
chmod +x "$TARGET_DIR/plugins/_example/daemon.sh"
chmod +x "$TARGET_DIR/plugins/_example/start.sh"

# === 创建 .gitkeep 文件 ===
for dir in data/logs data/snapshots data/reports; do
  touch "$TARGET_DIR/$dir/.gitkeep"
done

# === 安装 Dashboard 依赖 ===
echo ""
echo "=== 安装 Dashboard 依赖 ==="
cd "$TARGET_DIR/web" && npm install --silent 2>/dev/null
echo "  依赖安装完成"

# === 初始化 Git ===
echo ""
echo "=== 初始化 Git ==="
cd "$TARGET_DIR"
if [ ! -d ".git" ]; then
  git init -q
  echo "  Git 仓库已初始化"
else
  echo "  Git 仓库已存在"
fi

echo ""
echo "╔══════════════════════════════════════╗"
echo "║          项目创建完成!                ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "下一步:"
echo "  1. cd $TARGET_DIR"
echo "  2. 编辑 entities.yaml — 添加你的实体"
echo "  3. 创建 .env — 参考 .env.example"
echo "  4. bash setup.sh — 安装 hooks 和 skills"
echo "  5. 在 skills/ 下创建你的技能"
echo "  6. 在 plugins/ 下创建你的插件"
echo "  7. 启动 Claude Code — 自动进入工作模式"
echo ""
echo "Dashboard UI 将在首次启动时自动打开: http://localhost:$DASHBOARD_PORT"
