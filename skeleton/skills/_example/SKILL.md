---
name: example-skill
description: "示例技能 — 展示 Skill 编写的完整约定"
---

# Example Skill

## 概述

这是一个 Skill 示例，展示如何编写按需调用的技能。每个 Skill 只需一个 SKILL.md 文件。

**Skill vs Plugin**：
- **Skill**：用户按需调用，在 Claude 上下文内执行，无状态
- **Plugin**：后台常驻运行，独立于 Claude 进程树，有状态

## 触发条件

当用户说 "示例" 或 "example" 时调用此技能。
Dashboard 消息触发：`{type:"server_action", action:"example"}`

## 前置步骤（每次必须）

1. **确定目标实体** — 从用户指令或 Dashboard 消息中提取 alias
2. **读取实体清单** — 读取 `entities.yaml` 确认实体存在
3. **读取实体知识** — 读取 `memory/{alias}.md` 了解当前状态和历史
4. **首次操作** — 如果 memory 文件不存在 → 先执行基础探测创建

## 执行流程

### 1. Dashboard 可视化（操作全程同步更新）

```bash
# 派遣小人
wId=$(curl -s -X POST http://localhost:7890/api/worker/spawn \
  -H 'Content-Type: application/json' \
  -d '{"type":"example","target":"entity-alias","label":"示例操作"}' | jq -r '.workerId')

# 小人气泡
curl -s -X POST http://localhost:7890/api/worker/$wId/say \
  -H 'Content-Type: application/json' -d '{"text":"正在执行..."}'
```

### 2. 执行实际操作

```bash
# 终端显示命令
curl -s -X POST http://localhost:7890/api/worker/$wId/term \
  -H 'Content-Type: application/json' -d '{"type":"command","text":"执行的命令"}'

# → 执行实际命令（SSH / API / 本地）←

# 终端显示输出
curl -s -X POST http://localhost:7890/api/worker/$wId/term \
  -H 'Content-Type: application/json' -d '{"type":"output","text":"命令输出结果"}'
```

### 3. 验证与完成

```bash
# 更新实体状态
curl -s -X POST http://localhost:7890/api/server/entity-alias/status \
  -H 'Content-Type: application/json' -d '{"status":"ok"}'

# 标记完成
curl -s -X POST http://localhost:7890/api/worker/$wId/done \
  -H 'Content-Type: application/json' -d '{"result":"success"}'
```

## 错误处理

| 错误场景 | 处理方式 |
|---------|---------|
| 连接超时 | Dashboard term 显示 error，worker done result:"error" |
| 命令执行失败 | 记录错误输出，不继续后续步骤 |
| 目标不存在 | 告知用户，建议先执行基础探测 |
| 部分成功 | 报告已完成步骤和失败步骤 |

```bash
# 错误时：
curl -s -X POST http://localhost:7890/api/worker/$wId/term \
  -H 'Content-Type: application/json' -d '{"type":"error","text":"错误信息"}'
curl -s -X POST http://localhost:7890/api/worker/$wId/done \
  -H 'Content-Type: application/json' -d '{"result":"error","summary":"失败原因"}'
```

## Memory 更新

操作完成后更新 `memory/{alias}.md`：
- 更新相关状态字段（如 CPU、版本号等）
- 追加操作历史：

```markdown
| 日期 | 操作 | 操作人 | 结果 |
|------|------|-------|------|
| 2025-01-01 | example-skill | Claude | 成功，详细信息 |
```

## 通知（可选）

如项目安装了通知 Plugin：

```bash
# Webhook 通知
bash plugins/webhook-notify/notify.sh "操作完成" "实体 {alias} 的 xxx 操作已完成"

# 飞书回复（如消息来自飞书）
bash plugins/feishu-notify/reply.sh "{message_id}" "操作完成：简要结果"
```

## 安全检查

执行前确认：
- [ ] 已读取 memory/{alias}.md 了解实体状态？
- [ ] 操作前是否备份了配置文件？
- [ ] 破坏性操作是否获得用户确认？
- [ ] 操作后是否验证了结果？
- [ ] memory 文件是否已更新操作历史？
