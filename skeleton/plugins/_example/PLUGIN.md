---
name: example-monitor
description: "示例插件 — 展示 Plugin 编写约定"
type: daemon
interval: 3600
pid_file: /tmp/claude-example-monitor.pid
requires_env:
  - EXAMPLE_API_TOKEN
---

# Example Monitor Plugin

## 概述

这是一个 Plugin 示例，展示如何编写后台守护进程插件。

Plugin 与 Skill 的区别：
- **Skill**：用户按需调用，执行完即结束（无状态）
- **Plugin**：后台常驻运行，定时执行或监听事件（有状态）

## 文件结构

```
plugins/example-monitor/
├── PLUGIN.md     # 清单文件（必需）— 定义名称、类型、间隔、PID 文件、依赖环境变量
├── daemon.sh     # 守护进程主循环（必需）— 包含 PID 管理 + 业务逻辑 + 消息注入
├── start.sh      # 启动脚本（必需）— 环境检查 + nohup 启动
├── stop.sh       # 停止脚本（可选）— 默认通过 PID 文件 kill
└── routes.js     # Express 路由（可选）— 挂载到 /api/plugin/{name}/
```

## 清单字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `name` | string | 插件显示名称 |
| `description` | string | 简短描述 |
| `type` | `daemon` \| `listener` | daemon=定时循环, listener=事件监听 |
| `interval` | number | 执行间隔（秒），仅 daemon 类型 |
| `pid_file` | string | PID 文件路径，用于防重复和状态检查 |
| `requires_env` | string[] | 依赖的环境变量，缺失则静默跳过 |

## 通信约定

Plugin 通过 POST /api/messages 将结果注入 Dashboard 消息队列：

```bash
curl -sf -X POST http://localhost:${DASHBOARD_PORT:-7890}/api/messages \
  -H 'Content-Type: application/json' \
  -d '{"type":"plugin_report","plugin":"example-monitor","text":"检查结果摘要"}'
```

Claude 通过后台轮询收到 `plugin_report` 消息后自动分析处理。

## 生命周期

```
session-start.sh hook → 扫描 plugins/ → 调用 start.sh
                                              ↓
                                    检查 requires_env → 缺失则 exit 0
                                    检查 PID 文件 → 已运行则 exit 0
                                    nohup daemon.sh &
                                              ↓
                                    daemon.sh 循环：
                                      sleep $INTERVAL
                                      执行业务逻辑
                                      POST /api/messages (结果)
                                      清理旧数据
                                              ↓
                                    会话结束 → daemon 独立运行（不受影响）
                                    下次会话 → session-start.sh 检测已运行，跳过
```
