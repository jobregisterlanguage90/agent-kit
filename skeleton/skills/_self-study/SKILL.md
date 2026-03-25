---
name: self-study
description: 自主学习 Skill。收到 self_study 消息或空闲时调用。从 learning-queue.md 选课题，查资料、验证、三思沉淀、通知用户。
---

# 自主学习

## 触发条件
- TeammateIdle hook 检测到待学课题时自动触发（Worker 空闲时）
- Lead 判断当前空闲，主动分配给 Worker
- 用户直接说"去学习"

## 执行流程

### Step 1: 选题 + 领取
1. 读取 `memory/knowledge/learning-queue.md`
2. **恢复检查**：调用 `curl -sf -X POST http://localhost:7890/api/learning/recover`（自动将超过 24h 的 `learning` 状态重置为 `pending`）
3. 选优先级最高的 `pending` 课题
4. **领取课题**（防止多 Worker 重复学）:
   ```bash
   curl -sf -X POST http://localhost:7890/api/learning/claim \
     -H 'Content-Type: application/json' \
     -d '{"topic":"课题名","worker_name":"你的Worker名"}'
   ```
   - 返回 `success:true` → 继续学习
   - 返回 `success:false` → 已被领取，选下一个课题
5. 更新 learning-queue.md 状态 `pending → learning`
6. 如果没有可用课题 → 结束，告知 Lead "无待学课题"

### Step 2: 研究
1. 用 WebSearch 搜索课题相关的官方文档、最佳实践、案例
2. 重点关注：
   - 官方文档（一手资料）
   - 生产环境实践（踩坑记录）
   - 量化数据（效果评估）
3. 如果课题涉及当前管理的实体，可做实际验证
4. 至少查阅 **3 个不同来源**，交叉验证

### Step 3: 三思沉淀

学到知识后不急着写文件，先做 3 轮判断：

**第 1 思：归类 — 这属于什么？**
- 量化数据/阈值 → 更新 knowledge 基线文件
- 因果规律/模式 → 写入 knowledge patterns 文件
- 特定实体信息 → 更新对应 `memory/{alias}.md`
- 全新领域 → 创建新 knowledge 文件 + 更新 `_index.md`

**第 2 思：能力化 — 这能变成 Skill 吗？**
- 学到了可重复的操作流程 → 考虑创建新 Skill
- 判断标准：未来会重复执行 2 次以上 → 值得建 Skill
- 只是知识点不是流程 → 留在 knowledge 文件
- 决定建 Skill → 报告中标注，由用户确认后再创建

**第 3 思：关联 — 这影响什么？**
- 影响已有 Skill？ → 记录建议更新
- 影响基线标准？ → 更新阈值
- 已有知识有误？ → 修正 + 记录 incident-log
- 跨实体影响？ → 标注

**写入规则**：
- 用独立章节写入（`## 学习笔记: {topic} ({date})`），不修改已有数据段
- 内容必须可操作，标注来源 URL，关联到具体实体

### Step 4: 生成报告
创建 JSON 报告到 `data/learning-reports/{date}-{topic-slug}.json`：
```json
{
  "topic": "课题名称",
  "reason": "为什么要学",
  "learnings": ["可操作的要点"],
  "knowledge_files": ["更新的文件"],
  "impact": "对未来工作的影响",
  "sources": ["参考资料URL"],
  "suggestions": {
    "new_skill": null,
    "update_skills": [],
    "cross_entity": false
  }
}
```

### Step 5: 通知 + 更新清单 + 释放
1. 通知用户学习成果（如配置了飞书/Webhook，通过对应 Plugin 推送）
2. 更新 `learning-queue.md`：
   - 将课题从"待学清单"移到"已完成"表
   - 记录完成时间、知识沉淀位置、报告文件路径
3. **释放课题锁**：
   ```bash
   curl -sf -X POST http://localhost:7890/api/learning/release \
     -H 'Content-Type: application/json' -d '{"topic":"课题名"}'
   ```
4. 如果第 2 思建议新建 Skill → 通知中明确提出，**等用户确认后再创建**

## 学习质量标准
- 每个课题至少 **3 条可操作的要点**
- 至少引用 **2 个权威来源**
- 必须关联到当前管理的实体（不能纯理论）
- 必须完成三思判断（不能跳过）
- 知识文件更新后，下次同类报告分析时要能体现差异
