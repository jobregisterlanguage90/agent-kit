#!/bin/bash
# Agent 项目安装脚本
# 1. 环境检查（Node.js / npm / jq）
# 2. Skills symlink 到 ~/.claude/skills/
# 3. Claude Code 配置初始化（hooks + settings）
# 4. Plugin 权限设置
# 5. SSH 发现（仅 connect_via=ssh 时）
# 6. 权限确认
# 7. 项目记忆同步

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

# === Step 1: 环境检查 ===

echo "=== 环境检查 ==="
echo ""

# 检查 node
if ! command -v node &>/dev/null; then
  echo "  ❌ Node.js 未安装（需要 v18+）"
  exit 1
fi
NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
if [ "$NODE_VER" -lt 18 ]; then
  echo "  ❌ Node.js 版本过低（当前 $(node -v)，需要 v18+）"
  exit 1
fi
echo "  ✅ Node.js $(node -v)"

# 检查 npm
if command -v npm &>/dev/null; then
  echo "  ✅ npm $(npm -v)"
else
  echo "  ❌ npm 未安装"
  exit 1
fi

# 检查 jq
if command -v jq &>/dev/null; then
  echo "  ✅ jq $(jq --version)"
else
  echo "  ⚠️  jq 未安装（部分功能受限）"
fi

# === Step 2: Skills Symlink ===

echo ""
echo "=== Agent Skills 安装 ==="
echo ""

# 确保目标目录存在
mkdir -p "$TARGET_DIR"

# 遍历并 symlink 每个 skill（跳过 _example）
linked=0
for skill_dir in "$SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    [ "$skill_name" = "_example" ] && continue

    if [ -L "$TARGET_DIR/$skill_name" ]; then
        existing_target=$(readlink "$TARGET_DIR/$skill_name")
        if [ "$existing_target" = "$skill_dir" ] || [ "$existing_target" = "${skill_dir%/}" ]; then
            echo "  [跳过] $skill_name (已链接)"
            linked=$((linked + 1))
            continue
        fi
        echo "  [更新] $skill_name (重新链接)"
        rm "$TARGET_DIR/$skill_name"
    elif [ -e "$TARGET_DIR/$skill_name" ]; then
        echo "  [警告] $skill_name 已存在且非 symlink，跳过"
        continue
    fi

    ln -s "$skill_dir" "$TARGET_DIR/$skill_name"
    echo "  [安装] $skill_name -> $TARGET_DIR/$skill_name"
    linked=$((linked + 1))
done

echo ""
echo "已链接 $linked 个 Skills。"

# === Step 3: Claude Code 配置初始化 ===

echo ""
echo "=== Claude Code 配置初始化 ==="
echo ""

CLAUDE_DIR="$SCRIPT_DIR/.claude"
TEMPLATE_DIR="$SCRIPT_DIR/templates/claude"

# 创建 .claude 目录结构
mkdir -p "$CLAUDE_DIR/hooks"

# 复制 hooks（模板更新时覆盖）
for hook in session-start.sh stop-check.sh prompt-check.sh learning-reflect.sh idle-learn.sh; do
    if [ ! -f "$CLAUDE_DIR/hooks/$hook" ] || \
       [ "$TEMPLATE_DIR/hooks/$hook" -nt "$CLAUDE_DIR/hooks/$hook" ]; then
        cp "$TEMPLATE_DIR/hooks/$hook" "$CLAUDE_DIR/hooks/$hook"
        chmod +x "$CLAUDE_DIR/hooks/$hook"
        echo "  [安装] hooks/$hook"
    else
        echo "  [跳过] hooks/$hook (已存在且最新)"
    fi
done

# settings.local.json（不存在才创建）
if [ ! -f "$CLAUDE_DIR/settings.local.json" ]; then
    if [ -f "$TEMPLATE_DIR/settings.local.json" ]; then
        cp "$TEMPLATE_DIR/settings.local.json" "$CLAUDE_DIR/settings.local.json"
        echo "  [安装] settings.local.json"
    fi
else
    echo "  [跳过] settings.local.json (已存在)"
fi

# === Step 4: Plugin 权限设置 ===

echo ""
echo "=== Plugin 权限设置 ==="
echo ""

PLUGINS_DIR="$SCRIPT_DIR/plugins"
plugin_count=0
if [ -d "$PLUGINS_DIR" ]; then
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [ -d "$plugin_dir" ] || continue
        plugin_name=$(basename "$plugin_dir")
        [ "$plugin_name" = "_example" ] && continue

        # 设置脚本可执行权限
        for script in start.sh daemon.sh stop.sh; do
            if [ -f "$plugin_dir/$script" ]; then
                chmod +x "$plugin_dir/$script"
            fi
        done
        echo "  [配置] Plugin: $plugin_name"
        plugin_count=$((plugin_count + 1))
    done
fi
echo "已配置 $plugin_count 个 Plugins。"

# === Step 5: SSH 发现 ===

# 检查 entities.yaml 中的 connect_via
if grep -q 'connect_via.*ssh' "$SCRIPT_DIR/entities.yaml" 2>/dev/null; then
    echo ""
    echo "=== SSH 连接发现 ==="
    if [ -f "$SCRIPT_DIR/scripts/discover-ssh.sh" ]; then
        bash "$SCRIPT_DIR/scripts/discover-ssh.sh"
    fi
fi

# === Step 6: 权限确认 ===

echo ""
echo "=== 权限配置 ==="
if [ -f "$CLAUDE_DIR/settings.local.json" ]; then
    PERM_COUNT=$(jq '.permissions.allow | length' "$CLAUDE_DIR/settings.local.json" 2>/dev/null || echo "0")
    echo "  当前已配置 $PERM_COUNT 条权限白名单"
    echo "  包括：Dashboard API、SSH、脚本执行等"
    read -p "  查看完整列表？(y/N): " VIEW_PERMS
    if [ "$VIEW_PERMS" = "y" ] || [ "$VIEW_PERMS" = "Y" ]; then
        jq -r '.permissions.allow[]' "$CLAUDE_DIR/settings.local.json" 2>/dev/null | sed 's/^/    /'
    fi
fi

# === Step 7: 项目记忆同步 ===

echo ""
echo "=== 项目记忆同步 ==="
echo ""

PROJECT_PATH="$(cd "$SCRIPT_DIR" && pwd)"
ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's|/|-|g')
MEMORY_DIR="$HOME/.claude/projects/$ENCODED_PATH/memory"

if [ ! -f "$SCRIPT_DIR/memory/PROJECT_MEMORY.md" ]; then
    echo "  [跳过] memory/PROJECT_MEMORY.md 不存在"
else
    mkdir -p "$MEMORY_DIR"
    if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
        echo "  [跳过] Claude 记忆已存在，不覆盖"
    else
        cp "$SCRIPT_DIR/memory/PROJECT_MEMORY.md" "$MEMORY_DIR/MEMORY.md"
        echo "  [同步] 项目记忆 → Claude 自动记忆"
    fi
fi

echo ""
echo "=== 安装完成 ==="
echo "启动 Claude Code 即可开始使用。"
