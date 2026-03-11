#!/bin/bash
# Agent 项目安装脚本
# 1. Skills symlink 到 ~/.claude/skills/
# 2. Claude Code 配置初始化（hooks + settings）
# 3. Plugin 权限设置
# 4. 项目记忆同步

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_DIR="$HOME/.claude/skills"

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

echo ""
echo "=== Claude Code 配置初始化 ==="
echo ""

CLAUDE_DIR="$SCRIPT_DIR/.claude"
TEMPLATE_DIR="$SCRIPT_DIR/templates/claude"

# 创建 .claude 目录结构
mkdir -p "$CLAUDE_DIR/hooks"

# 复制 hooks（模板更新时覆盖）
for hook in session-start.sh stop-check.sh prompt-check.sh; do
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
