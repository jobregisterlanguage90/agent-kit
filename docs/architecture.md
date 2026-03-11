# Claude Agent Kit 架构

## 7 个可复用原语

### 1. Agent 定义（CLAUDE.md）

Agent 的"灵魂"。定义：
- 角色和职责
- 启动序列（自动执行）
- Skill 分发表（用户意图 → Skill 映射）
- 安全规则和操作约定
- Dashboard API 调用模式

### 2. Dashboard（web/）

Express + WebSocket 服务器，提供：
- REST API（Claude 通过 curl 调用）
- WebSocket（浏览器实时更新）
- 等距像素风 Canvas UI
- Worker 小人可视化（spawn → walk → work → done）
- Terminal Dock（多 Tab，可调高度，文本可选）
- 消息队列（Dashboard ↔ Claude 双向通信）

### 3. Skills（skills/）

按需技能，约定：
- 每个 Skill 一个目录：`skills/{name}/SKILL.md`
- YAML frontmatter 定义 `name` 和 `description`
- Markdown 正文描述触发条件、执行步骤、输出格式
- 通过 `setup.sh` symlink 到 `~/.claude/skills/` 注册
- 在 Claude 中用 `/{skill-name}` 调用

### 4. Plugins（plugins/）

后台守护进程，约定：
- 每个 Plugin 一个目录：`plugins/{name}/`
- `PLUGIN.md` — 清单（name, type, interval, pid_file, requires_env）
- `daemon.sh` — 守护进程主循环（PID 管理 + sleep + 业务 + 消息注入）
- `start.sh` — 启动脚本（环境检查 + nohup 启动）
- 可选 `routes.js` — Express 路由挂载到 `/api/plugin/{name}/`
- session-start.sh hook 自动扫描并启动

### 5. Memory（memory/）

实体知识持久化：
- 每个实体一个文件：`memory/{alias}.md`
- `_template.md` 定义知识文件结构
- 首次操作自动创建（auto-discovery）
- `PROJECT_MEMORY.md` — 项目级记忆（git 追踪，可移植）
- `setup.sh` 同步到 Claude 自动记忆目录

### 6. Hooks（.claude/hooks/）

会话生命周期自动化：
- `session-start.sh` — 启动 Dashboard + 扫描 Plugin + 输出启动指令
- `stop-check.sh` — 退出前检查未处理消息
- `prompt-check.sh` — 空输入触发消息检查

### 7. Config（.env + entities.yaml）

配置分离：
- `.env` — 敏感信息（API Token、密码），不进 git
- `entities.yaml` — 实体清单（别名、标签、分组），进 git
- `.env.example` — 配置模板，进 git

## 通信流

```
┌──────────────┐     ┌──────────────────┐     ┌────────────┐
│ Dashboard UI │────→│ Express+WS :7890 │←────│ Plugin     │
│ (浏览器)      │ WS  │   消息队列        │ POST│ (nohup)    │
└──────────────┘     └────────┬─────────┘     └────────────┘
                              │ curl GET /api/messages
                              ↓
                     ┌────────────────┐
                     │  Claude Code   │
                     │  后台轮询(3s)   │
                     │                │
                     │ 解析消息 → Skill│
                     │ curl POST /api │
                     └────────────────┘
```

## 启动序列

```
1. SessionStart hook 触发
2. session-start.sh:
   a. 检测 .env（首次引导 or 正常启动）
   b. 启动 Dashboard 服务
   c. 扫描 plugins/ 启动所有 daemon
3. Claude 收到启动指令，执行：
   a. 验证 Dashboard 健康
   b. 初始化实体（entities.yaml → /api/server/init）
   c. 加载记忆（memory/*.md → /api/server/:alias/status）
   d. 设置连接状态
   e. 启动后台轮询
   f. Plugin 巡检
   g. 报告就绪
4. 进入消息轮询循环
```

## 扩展模式

### 添加新实体
1. `entities.yaml` 添加条目
2. 首次操作自动创建 `memory/{alias}.md`

### 添加新 Skill
1. 创建 `skills/my-skill/SKILL.md`
2. 运行 `bash setup.sh` 注册
3. CLAUDE.md Skill 表添加映射

### 添加新 Plugin
1. 创建 `plugins/my-plugin/` 目录
2. 编写 PLUGIN.md + daemon.sh + start.sh
3. 下次 session 自动启动

## 内置 Plugin 架构

### feishu-notify（飞书深度集成）

```
飞书用户 → WebSocket → bot.py → POST /api/messages → 消息队列
                                                          ↓
                                        Claude 轮询 → 处理 → reply.sh 回复
                                                    → report.sh 写入多维表格
                                                    → send_im_direct 直发 IM
```

组件：
- `bot.py` — WebSocket 长连接，从 entities.yaml 动态加载别名
- `start.sh` / `stop.sh` — nohup daemon 管理（PID 含项目名）
- `reply.sh` — 回复飞书消息（文本/卡片）
- `report.sh` — 多维表格写入 + IM 直发（通用子命令架构）
- `setup-bitable.py` — 一次性建表，自动写入 .env

### webhook-notify（轻量 Webhook）

```
Skill/Daemon 完成 → bash notify.sh "标题" "内容" → 自动检测平台 → POST Webhook
```

支持：飞书群 Bot、Slack、Discord、自定义 HTTP。
无 daemon，utility 类型，按需调用。

### 通知闭环原则

daemon 生成报告后**必须**走两条通道：
1. `POST /api/messages` — Dashboard 消息队列（Claude 轮询处理）
2. 通知 Plugin — 飞书/Webhook 推送（人直接看到）

> 教训：某 daemon 跑了 5 天报告正常生成，但通知完全没推送 —
> 因为只做了消息队列注入，没调用通知 Plugin。

### Skill 辅助函数

`scripts/skill-helpers.sh` 提供标准 Dashboard API 封装：

```bash
source scripts/skill-helpers.sh
wId=$(skill_spawn "check" "entity-1" "检查操作")
skill_term "$wId" "command" "执行的命令"
skill_term "$wId" "output" "命令输出"
skill_done "$wId" "success" "操作完成"
skill_notify "操作完成" "实体 entity-1 状态正常"
```

## Team 模式架构

可选的 Lead + Worker 并行架构：

```
轮询发现消息 → Lead 解析 → SendMessage 分发 → Worker 独立执行
                                   ↓                    ↓
                          立即重启轮询          完成后回报 Lead
```

规则：
- Lead **不执行** Skill，只做调度和汇总
- 同一实体分配给同一 Worker（memory 安全）
- Team 跟随会话生命周期，新会话自动重建

## Context Expiry 恢复

| 组件 | 影响 | 恢复机制 |
|------|------|---------|
| Plugin daemon | 不受影响（nohup） | session-start.sh 自动检活 |
| Dashboard | 不受影响（Express） | 持续运行 |
| 后台轮询 | 丢失 | 启动序列自动重启 |
| Team | 丢失 | 启动序列自动重建 |
| 消息队列 | 内存队列可能丢失 | 报告持久化到 data/ |
