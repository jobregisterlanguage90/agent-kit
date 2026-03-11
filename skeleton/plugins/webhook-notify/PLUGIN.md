---
name: webhook-notify
type: utility
---

# Webhook Notify Plugin

轻量 Webhook 通知推送，支持飞书群 Bot、Slack、Discord、自定义 HTTP。

## 类型

Utility（无后台 daemon，按需调用）。

## 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `WEBHOOK_URL` | Webhook 地址 | `https://open.feishu.cn/open-apis/bot/v2/hook/xxx` |
| `WEBHOOK_TYPE` | 平台类型 | `feishu` / `slack` / `discord` / `custom` |

未配置 `WEBHOOK_URL` 时静默跳过（不报错）。

## 用法

```bash
# 基本通知
bash plugins/webhook-notify/notify.sh "标题" "内容"

# 带级别（info/warn/error）
bash plugins/webhook-notify/notify.sh "服务器告警" "CPU 超过 90%" "error"
```

## Skill 中调用

```bash
source scripts/skill-helpers.sh
skill_notify "操作完成" "实体 xxx 的操作已完成"
# skill_notify 自动检测并调用已安装的通知 Plugin
```
