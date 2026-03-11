---
name: example-skill
description: "示例技能 — 展示 Skill 编写约定"
---

# Example Skill

## 概述

这是一个 Skill 示例，展示如何编写按需调用的技能。

Skill 与 Plugin 的区别：
- **Skill**：用户按需调用，在 Claude 上下文内执行，执行完即结束
- **Plugin**：后台常驻运行，独立于 Claude 进程树

## 文件结构

```
skills/example-skill/
└── SKILL.md      # 技能定义（必需）— 包含触发条件、执行步骤、输出格式
```

只需一个 SKILL.md 文件。Claude 根据文件内容理解如何执行该技能。

## 触发条件

当用户说 "示例" 或 "example" 时调用此技能。

## 前置条件

- 目标实体的 memory 文件已存在（memory/{alias}.md）
- Dashboard 服务正在运行

## 执行步骤

1. **读取记忆** — 读取 `memory/{alias}.md` 了解目标实体当前状态
2. **派遣 Worker** — curl POST /api/worker/spawn 在 Dashboard 显示工作小人
3. **执行操作** — 通过 SSH / API / 本地命令执行实际工作
4. **更新终端** — curl POST /api/worker/:id/term 实时显示命令和输出
5. **更新状态** — curl POST /api/server/:alias/status 更新实体指标
6. **标记完成** — curl POST /api/worker/:id/done 小人完成动画
7. **更新记忆** — 将操作结果写入 memory/{alias}.md 操作历史

## Dashboard API 调用模板

```bash
# 1. 派遣小人
wId=$(curl -s -X POST http://localhost:7890/api/worker/spawn \
  -H 'Content-Type: application/json' \
  -d '{"type":"example","target":"entity-alias","label":"示例操作"}' | jq -r '.workerId')

# 2. 显示命令
curl -s -X POST http://localhost:7890/api/worker/$wId/term \
  -H 'Content-Type: application/json' -d '{"type":"command","text":"执行的命令"}'

# 3. 小人气泡
curl -s -X POST http://localhost:7890/api/worker/$wId/say \
  -H 'Content-Type: application/json' -d '{"text":"正在执行..."}'

# 4. 显示输出
curl -s -X POST http://localhost:7890/api/worker/$wId/term \
  -H 'Content-Type: application/json' -d '{"type":"output","text":"命令输出结果"}'

# 5. 更新实体状态
curl -s -X POST http://localhost:7890/api/server/entity-alias/status \
  -H 'Content-Type: application/json' -d '{"status":"ok"}'

# 6. 完成
curl -s -X POST http://localhost:7890/api/worker/$wId/done \
  -H 'Content-Type: application/json' -d '{"result":"success"}'
```

## 输出

- Dashboard 终端面板实时显示命令和输出
- 实体状态卡片更新
- memory/{alias}.md 操作历史新增记录

## 错误处理

- 连接失败 → 记录错误到 Dashboard 终端（type: "error"）
- 操作失败 → worker done 标记 result: "error"
- 所有错误都应更新 memory 文件记录
