# Plugin 编写指南

## 什么是 Plugin

Plugin 是后台守护进程，独立于 Claude 进程树运行。适用于定时任务、事件监听等需要持续运行的场景。

**特点**：
- 有状态 — 常驻后台
- 独立运行 — 不受 Claude 会话结束影响
- 通过消息队列与 Claude 通信

## 文件结构

```
plugins/my-plugin/
├── PLUGIN.md     # 清单（必需）
├── daemon.sh     # 守护进程（必需）
├── start.sh      # 启动脚本（必需）
├── stop.sh       # 停止脚本（可选）
└── routes.js     # Express 路由（可选）
```

## PLUGIN.md 格式

```yaml
---
name: my-plugin
description: "一句话描述"
type: daemon          # daemon | listener
interval: 3600        # 秒（daemon 类型）
pid_file: /tmp/claude-my-plugin.pid
requires_env:
  - MY_API_TOKEN
---

# 详细说明
```

## daemon.sh 模板

```bash
#!/bin/bash
PROJECT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PID_FILE="/tmp/claude-my-plugin.pid"
INTERVAL=3600

# PID 防重复
if [ -f "$PID_FILE" ]; then
  kill -0 "$(cat "$PID_FILE")" 2>/dev/null && exit 0
  rm -f "$PID_FILE"
fi
echo $$ > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

while true; do
  sleep "$INTERVAL"

  # 你的业务逻辑
  RESULT="检查结果"

  # 注入消息队列
  curl -sf -X POST http://localhost:7890/api/messages \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg t "$RESULT" '{type:"plugin_report",plugin:"my-plugin",text:$t}')"
done
```

## start.sh 模板

```bash
#!/bin/bash
PROJECT_DIR="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
PID_FILE="/tmp/claude-my-plugin.pid"

# 检查环境变量
source "$PROJECT_DIR/.env" 2>/dev/null
[ -z "$MY_API_TOKEN" ] && exit 0

# 检查已运行
[ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null && exit 0

# 启动
nohup bash "$(dirname "$0")/daemon.sh" "$PROJECT_DIR" > /dev/null 2>&1 &
```

## 自定义 API 路由（可选）

如果 Plugin 需要暴露自定义 API：

```javascript
// routes.js
const express = require('express');
const router = express.Router();

router.get('/status', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = router;
// 自动挂载到 /api/plugin/my-plugin/status
```

## 生命周期

1. `session-start.sh` hook 扫描 `plugins/*/start.sh` 自动启动
2. daemon.sh 循环运行，通过 PID 文件管理实例
3. 结果通过 `POST /api/messages` 注入队列
4. Claude 通过轮询收到 `plugin_report` 消息自动处理
5. 会话结束 → daemon 继续运行
6. 下次会话 → hook 检测已运行，跳过启动

## 示例

参考 `plugins/_example/`
