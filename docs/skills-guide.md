# Skill 编写指南

## 什么是 Skill

Skill 是按需调用的技能定义文件。Claude 根据 SKILL.md 的内容理解如何执行该技能。

**特点**：
- 无状态 — 执行完即结束
- 在 Claude 上下文内执行
- 用户通过 `/{skill-name}` 或自然语言触发

## 文件结构

```
skills/my-skill/
└── SKILL.md    # 唯一必需文件
```

## SKILL.md 格式

```yaml
---
name: my-skill
description: "一句话描述这个 Skill 做什么"
---

# Skill 名称

## 触发条件
描述什么时候应该调用这个 Skill

## 前置条件
- 需要什么环境或配置

## 执行步骤
1. 步骤一
2. 步骤二
3. ...

## Dashboard 集成
展示如何调用 Dashboard API 更新 UI

## 输出
描述执行结果和产出物

## 错误处理
描述各种失败场景的处理方式
```

## Dashboard 集成模板

每个 Skill 执行时应该更新 Dashboard UI：

```bash
# 派遣小人
wId=$(curl -s -X POST http://localhost:7890/api/worker/spawn \
  -H 'Content-Type: application/json' \
  -d '{"type":"my-skill","target":"entity-alias","label":"操作描述"}' | jq -r '.workerId')

# 执行过程中实时更新终端
curl -s -X POST http://localhost:7890/api/worker/$wId/term \
  -d '{"type":"command","text":"执行的命令"}'

# 完成
curl -s -X POST http://localhost:7890/api/worker/$wId/done \
  -d '{"result":"success"}'
```

## 注册

运行 `bash setup.sh` 后，Skill 会被 symlink 到 `~/.claude/skills/`，Claude 自动发现。

## 示例

参考 `skills/_example/SKILL.md`
