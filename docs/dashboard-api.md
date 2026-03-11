# Dashboard API 参考

## 服务信息

- **默认端口**: 7890（可通过 `DASHBOARD_PORT` 环境变量配置）
- **WebSocket**: `ws://localhost:7890/ws`
- **静态文件**: `web/public/`

## REST API

### 通用

| 端点 | 方法 | 说明 |
|------|------|------|
| `GET /api/health` | GET | 返回 `{status, uptime, clients}` |

### 实体管理

| 端点 | 方法 | Body | 说明 |
|------|------|------|------|
| `POST /api/server/init` | POST | `[{alias, label, group, tags}]` 或 `{servers:[...]}` | 初始化实体列表 |
| `POST /api/server/:alias/status` | POST | `{status, cpu, memory, disk, ...}` | 更新实体指标 |

### Worker 管理

| 端点 | 方法 | Body | 返回 |
|------|------|------|------|
| `POST /api/worker/spawn` | POST | `{type, target, label}` | `{workerId}` |
| `POST /api/worker/:id/say` | POST | `{text}` | `{success}` |
| `POST /api/worker/:id/term` | POST | `{type: "command\|output\|error", text}` | `{success}` |
| `POST /api/worker/:id/done` | POST | `{result: "success\|error", summary?}` | `{success}` |
| `POST /api/worker/:id/cancel` | POST | — | `{success}` |
| `POST /api/worker/:id/remove` | POST | — | `{success}` |

### UI 控制

| 端点 | 方法 | Body | 说明 |
|------|------|------|------|
| `POST /api/operation` | POST | `{description, type}` 或 `{description: null}` | 顶部操作横幅 |
| `POST /api/progress` | POST | `{current, total, label}` | 进度条 |
| `POST /api/claude/status` | POST | `{status: "connected\|working\|idle"}` | Claude 状态灯 |

### 消息队列

| 端点 | 方法 | 说明 |
|------|------|------|
| `GET /api/messages` | GET | 获取并清空消息队列 |
| `POST /api/messages` | POST | 外部注入消息（Plugin 使用） |
| `DELETE /api/messages` | DELETE | 清空队列 |

### 信息查询

| 端点 | 方法 | 说明 |
|------|------|------|
| `GET /api/cron/status` | GET | Plugin 运行状态（自动发现） |
| `GET /api/memory` | GET | 实体记忆摘要列表 |
| `GET /api/memory/:alias` | GET | 单个实体完整记忆 |
| `GET /api/skills` | GET | 可用 Skill 列表 |
| `GET /api/plugins` | GET | 可用 Plugin 列表 |
| `GET /api/history` | GET | 操作历史（支持 `?server=&type=&limit=`） |

## WebSocket 消息

### 服务端 → 客户端

| type | 数据 | 说明 |
|------|------|------|
| `full_state` | `{servers, groups, workers, ...}` | 连接时发送完整状态 |
| `init_servers` | `{servers: [...]}` | 实体列表初始化 |
| `server_status` | `{alias, metrics}` | 实体指标更新 |
| `worker_spawn` | `{worker: {...}}` | 新 Worker 创建 |
| `worker_say` | `{workerId, text}` | Worker 气泡文字 |
| `term_write` | `{workerId, termType, text}` | 终端输出 |
| `worker_done` | `{workerId, result}` | Worker 完成 |
| `worker_remove` | `{workerId}` | Worker 移除 |
| `operation` | `{description, opType}` | 操作横幅 |
| `progress` | `{current, total, label}` | 进度条 |
| `claude_status` | `{status}` | Claude 状态 |
| `history_add` | `{entry}` | 新历史记录 |
| `cron_status` | `{tasks: [...]}` | Plugin 状态（每 30s） |
| `external_message` | `{data}` | 外部消息通知 |

### 客户端 → 服务端

```json
{
  "type": "user_message",
  "data": {
    "type": "quick_action|server_action|text|cancel_task",
    ...
  }
}
```

## 消息类型（Dashboard → Claude）

| type | 字段 | 触发 |
|------|------|------|
| `quick_action` | `action` | 顶部按钮 |
| `server_action` | `server, action, instructions` | 实体菜单 |
| `text` | `text` | 输入框 |
| `cancel_task` | `workerId, server, taskType` | 取消按钮 |
| `plugin_report` | `plugin, text, reportFile` | Plugin 注入 |
