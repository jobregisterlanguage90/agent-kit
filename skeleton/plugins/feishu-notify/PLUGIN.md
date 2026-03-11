---
name: feishu-notify
type: listener
---

# Feishu Notify Plugin

飞书深度集成：长连接 Bot 监听 + 消息回复 + 多维表格汇报 + IM 直发。

## 类型

Listener（后台 daemon — 飞书 WebSocket 长连接监听消息）。

## 环境变量

| 变量 | 必须 | 说明 |
|------|------|------|
| `FEISHU_APP_ID` | 是 | 飞书应用 App ID |
| `FEISHU_APP_SECRET` | 是 | 飞书应用 App Secret |
| `FEISHU_WEBHOOK_URL` | 否 | 飞书群 Webhook（警告时发群消息） |
| `FEISHU_NOTIFY_USER_IDS` | 否 | 直发 IM 的 open_id 列表（逗号分隔） |
| `FEISHU_BITABLE_APP_TOKEN` | 否 | 多维表格文档 Token |
| `FEISHU_*_TABLE_ID` | 否 | 各数据表 ID（由 setup-bitable.py 自动生成） |

未配置 `FEISHU_APP_ID` 时 Bot 不启动（静默跳过）。

## 组件

| 文件 | 说明 |
|------|------|
| `bot.py` | 飞书 WebSocket 长连接 Bot，接收消息转为 Dashboard 消息 |
| `start.sh` | 启动 Bot daemon（nohup） |
| `stop.sh` | 停止 Bot daemon |
| `reply.sh` | 回复飞书消息（文本/卡片） |
| `report.sh` | 多维表格汇报 + IM 直发（通用子命令） |
| `setup-bitable.py` | 一次性建表脚本，自动写入 .env |
| `requirements.txt` | Python 依赖 |

## 用法

```bash
# 启动 Bot（session-start.sh 自动调用）
bash plugins/feishu-notify/start.sh

# 回复消息
bash plugins/feishu-notify/reply.sh "{message_id}" "回复内容"

# 汇报到多维表格
bash plugins/feishu-notify/report.sh <子命令> [参数...]

# 首次建表
python3 plugins/feishu-notify/setup-bitable.py --app-token <TOKEN>
```

## 消息流程

```
飞书用户发消息 → Bot (WebSocket) → POST /api/messages → Dashboard 消息队列
                                                              ↓
                                              Claude 轮询 → 处理 → reply.sh 回复
```

## 自定义

- `bot.py` 中的 `KNOWN_ALIASES` 从 `entities.yaml` 动态读取
- `report.sh` 的子命令对应 `.env` 中的 `FEISHU_{TABLE_KEY}_TABLE_ID`
- 新增子命令：在 report.sh 中添加 `cmd_xxx()` 函数和 case 分支
