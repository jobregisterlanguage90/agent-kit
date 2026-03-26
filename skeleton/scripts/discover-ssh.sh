#!/bin/bash
# SSH Config 发现 — 解析 ~/.ssh/config 提取 Host 别名
# 用法：bash scripts/discover-ssh.sh

SSH_CONFIG="$HOME/.ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
  echo "  ⚠️  ~/.ssh/config 不存在，跳过 SSH 发现"
  exit 0
fi

# 提取 Host 别名（排除通配符 * 和特殊条目）
HOSTS=$(grep -E '^Host\s+' "$SSH_CONFIG" | awk '{print $2}' | grep -v '\*' | sort)

if [ -z "$HOSTS" ]; then
  echo "  未发现 SSH 别名"
  exit 0
fi

echo "  发现以下 SSH 别名："
echo "$HOSTS" | while read -r host; do
  echo "    - $host"
done

echo ""
read -p "  测试连通性？(y/N): " TEST
if [ "$TEST" = "y" ] || [ "$TEST" = "Y" ]; then
  echo "$HOSTS" | while read -r host; do
    printf "    %-20s" "$host"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" "echo OK" 2>/dev/null; then
      echo "✅"
    else
      echo "❌ (连接失败)"
    fi
  done
fi
