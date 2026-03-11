# 实践真知 — 已验证的模式与反模式

> 从 server-maintenance 项目实际运行经验提炼。每条规则都经过生产验证。

## 轮询模式

- ✅ 处理完消息后立即重启轮询（run_in_background）
- ❌ 处理消息时忘记重启 → Claude 变聋，**最常见的错误**

## Daemon 模式

- ✅ nohup 独立进程 + PID 文件 + `trap EXIT` 清理
- ✅ session-start.sh 每次检活，死了自动重启
- ✅ PID 文件含项目名（多项目隔离）
- ❌ 用 run_in_background 做长期任务 → context expiry 后丢失

## Daemon 通知闭环（血泪教训）

- ✅ 消息队列注入 + 外部通知推送（双通道）
- ✅ 报告持久化到 data/（即使通知失败也有记录）
- ❌ daemon 只注入消息队列不推送通知 → **跑了 5 天没人知道结果**
- ❌ 写完 daemon 代码不测试通知通道 → "看起来在跑"但通知是断的

> daemon 生成报告后必须走两条通道：
> 1. `POST /api/messages` — Dashboard 消息队列（Claude 轮询处理）
> 2. 通知 Plugin — 飞书/Webhook 推送（人直接看到）
> 漏掉任何一条 = 通知不完整

## 功能自检

- ✅ 每个新功能完成后走自检清单（消息通道、通知推送、Dashboard 展示、memory、PID）
- ❌ 代码写完就算完 → 漏掉关键通道（如通知）可能几天都不发现

## 启动序列

- ✅ session-start.sh 注入完整步骤清单 + "不要询问用户"
- ✅ Hook 启动后台进程（Dashboard、daemon、Bot），Claude 执行初始化（实体、Team、轮询）
- ❌ Hook 注入的指令不完整 → Claude 遗漏步骤（如不创建 Team）
- ❌ 启动时问用户"要不要执行 xxx" → 应该自动执行

## PID 文件管理

- ✅ `kill -0` 检测进程（比 ps 解析更可靠）
- ✅ `trap 'rm -f "$PID_FILE"' EXIT`（保证清理）
- ✅ 文件名含项目名（多项目隔离）
- ❌ 不清理 stale PID → 误判为"已运行"

## 通知推送

- ✅ Plugin daemon 监听 → 消息队列 → Claude 分析 → 推送结果
- ✅ 报告持久化到 data/ + POST 消息队列（双保险）
- ❌ Claude 直接轮询外部 API → 浪费 context
- ❌ 只 POST 消息队列 → Dashboard 重启后丢失

## Team 模式

- ✅ Lead 只做轮询和调度，不执行 Skill → 响应快
- ✅ 同一实体的操作分配给同一 Worker → memory 文件安全
- ✅ 分配完毕后立即重启轮询，不等 Worker 完成
- ❌ Lead 执行 Skill → 阻塞轮询，无法感知新消息
- ❌ 多 Worker 同时写同一 memory 文件 → 数据丢失

## Memory 并发

- ✅ 同一实体分配给同一 Worker
- ❌ 多 Worker 同时写同一 memory 文件

## API Token 安全

- ✅ .env 不进 git + .env.example 模板
- ✅ curl 命令中变量空白去除：`CF_TOK=$(echo -n "$TOKEN" | tr -d '[:space:]')`
- ❌ Token 硬编码或 echo 到终端

## curl 调用 Dashboard

- ✅ 用 `-s`（静默），失败时能看到错误
- ❌ `-sf | jq` → `-f` 吞错误信息，jq 报错但不知道原因

## Skill 执行规范

- ✅ spawn → term → execute → status → done → memory（完整流程）
- ✅ 操作前备份配置（`cp xxx.conf xxx.conf.backup.$(date)`）
- ✅ 测试再应用（`nginx -t` 先于 reload）
- ❌ 跳过 memory 读取直接操作 → 不了解实体当前状态

## Context Expiry 恢复

- ✅ Daemon 独立进程（nohup），不受 Claude 会话影响
- ✅ Dashboard 独立 Express 进程，不受影响
- ✅ session-start.sh 自动检活 + 重启
- ❌ 轮询和 Team 依赖 Claude 进程 → 新会话必须重建
- ❌ 消息只存内存队列 → 持久化到 data/ 才安全
