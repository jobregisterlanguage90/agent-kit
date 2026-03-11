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

read -p "目标目录 [$HOME/Documents/code/$PROJECT_NAME]: " TARGET_DIR
TARGET_DIR="${TARGET_DIR:-$HOME/Documents/code/$PROJECT_NAME}"

echo ""
echo "=== 配置确认 ==="
echo "  项目名称: $PROJECT_NAME"
echo "  Agent 角色: $AGENT_ROLE"
echo "  实体类型: $ENTITY_TYPE ($ENTITY_LABEL)"
echo "  连接方式: $CONNECT_VIA"
echo "  Dashboard 端口: $DASHBOARD_PORT"
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
      "$tmpl" > "$dest"
  rm "$tmpl"
  echo "  [生成] $(basename "$dest")"
done

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
