# Worker 生命周期策略

## 核心规则

### 1. 同名唯一
- 同名 Worker 不允许重复 spawn
- spawn 前必须检查 worker-ids.json 是否已有同名条目
- 已有则 SendMessage ping 验证存活，存活就复用

### 2. idle ≠ 可关闭
- Worker 空闲时处于待命状态，等待下一个任务
- 心跳引擎检测到 idle 不应关闭 Worker
- 只有明确的 shutdown_request 才能关闭 Worker

### 3. Lead 不执行
- Lead 只做消息解析、任务分配、结果汇总
- 所有 SSH、Skill、API 调用都交给 Worker
- Lead 执行操作 = 架构违规

### 4. spawn 时机
- 4 个 Worker 全忙 → 可以 spawn 临时 agent
- 临时 agent 完成后必须 shutdown_request 清理
- 有空闲 Worker 时禁止 spawn 新 agent

## 状态流转

```
spawn → online → busy → idle → busy → ... → shutdown
         ↑                ↑
         └── 心跳刷新 ──────┘
```

## 心跳协议
- Worker 启动时发心跳：`POST /api/team/heartbeat`
- 完成任务时发心跳（刷新存活时间）
- 30 分钟无心跳 → Dashboard 标记 dead → poll 推送 ping_worker

## 上下文压缩恢复
1. 读取 data/worker-ids.json 获取已知 Worker task ID
2. 逐个 SendMessage ping 验证存活
3. 有 pong → 恢复，代发心跳
4. 无响应 → spawn 新 Worker 替换
5. 更新 worker-ids.json
