# Claude Agent Kit

可复制的 Claude Code Agent 底层框架。基于 7 个可复用原语，快速搭建具备 Dashboard 可视化、Skills 技能、Plugin 守护进程、Memory 记忆系统的智能 Agent。

## 核心概念

| 原语 | 说明 | 目录 |
|------|------|------|
| **Agent 定义** | CLAUDE.md — 角色、行为、安全规则 | `CLAUDE.md` |
| **Dashboard** | 等距像素风可视化面板 + REST/WebSocket | `web/` |
| **Skills** | 按需调用的技能（无状态） | `skills/` |
| **Plugins** | 后台守护进程（有状态，独立运行） | `plugins/` |
| **Memory** | 每实体 Markdown 知识文件 | `memory/` |
| **Hooks** | 会话生命周期自动化 | `.claude/hooks/` |
| **Config** | .env 密钥 + entities.yaml 实体清单 | 项目根目录 |

## Quick Start

```bash
# 1. 创建新 Agent 项目
bash create-agent.sh

# 2. 进入项目目录
cd ~/Documents/code/your-project

# 3. 配置实体
# 编辑 entities.yaml 添加你的管理对象

# 4. 创建环境变量
cp .env.example .env
# 编辑 .env 填入实际值

# 5. 安装（Skills symlink + Hooks + 记忆同步）
bash setup.sh

# 6. 启动 Claude Code
# 自动执行启动序列 → Dashboard 打开 → 进入工作循环
```

## Skill vs Plugin

| | Skill（技能） | Plugin（插件） |
|---|---|---|
| 触发 | 用户按需调用 | 自动定时 / 事件驱动 |
| 生命周期 | 无状态，执行完即结束 | 常驻后台 daemon |
| 进程 | 在 Claude 上下文内 | 独立于 Claude 进程树 |
| 通信 | 直接执行 + curl Dashboard | POST /api/messages 注入队列 |
| 注册 | `skills/{name}/SKILL.md` | `plugins/{name}/PLUGIN.md` |

### 创建 Skill

```
skills/my-skill/
└── SKILL.md    # 定义触发条件、执行步骤、输出格式
```

参考 `skills/_example/SKILL.md`

### 创建 Plugin

```
plugins/my-plugin/
├── PLUGIN.md   # 清单（name, interval, pid_file, requires_env）
├── daemon.sh   # 守护进程主循环
└── start.sh    # 启动脚本（PID 管理）
```

参考 `plugins/_example/`

## Dashboard API

| 端点 | 方法 | 用途 |
|------|------|------|
| `/api/health` | GET | 健康检查 |
| `/api/server/init` | POST | 初始化实体列表 |
| `/api/server/:alias/status` | POST | 更新实体指标 |
| `/api/worker/spawn` | POST | 派遣工作小人 |
| `/api/worker/:id/say` | POST | 小人气泡文字 |
| `/api/worker/:id/term` | POST | 终端输出 |
| `/api/worker/:id/done` | POST | 标记完成 |
| `/api/messages` | GET | 获取消息队列 |
| `/api/messages` | POST | 注入消息（Plugin 用） |
| `/api/cron/status` | GET | Plugin 状态 |
| `/api/memory` | GET | 实体记忆列表 |
| `/api/skills` | GET | 可用技能列表 |
| `/api/plugins` | GET | 可用插件列表 |

完整 API 参考见 `docs/dashboard-api.md`

## 通信架构

```
用户终端 ──────────┐
                   ├──→ Claude Code ──→ 执行 Skill ──→ 更新 Dashboard
Dashboard 浏览器 ──┤         ↑
                   │    后台轮询（3s）
Plugin 守护进程 ───┘    ← /api/messages
```

## 可选能力

`create-agent.sh` 交互时可选启用：

| 能力 | 说明 |
|------|------|
| **Team 模式** | Lead + N Worker 并行架构，适合多实体批量操作 |
| **飞书通知** | Bot 长连接监听 + 消息回复 + 多维表格汇报 + IM 直发 |
| **Webhook 通知** | 轻量推送（飞书群/Slack/Discord/自定义 HTTP） |

## 内置 Plugin

| Plugin | 类型 | 说明 |
|--------|------|------|
| `feishu-notify` | listener | 飞书 WebSocket 长连接 + API 全套 |
| `webhook-notify` | utility | 通用 Webhook 推送（无 daemon） |

## 文档

- [架构详解](docs/architecture.md)
- [Skill 编写指南](docs/skills-guide.md)
- [Plugin 编写指南](docs/plugins-guide.md)
- [Dashboard API 参考](docs/dashboard-api.md)
- [实践真知](docs/proven-patterns.md) — 已验证的模式与反模式
