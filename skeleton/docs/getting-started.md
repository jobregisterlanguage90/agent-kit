# 快速理解 — 3 分钟上手

## 核心概念

### 角色
- **Lead** = Claude Code 主进程。只做决策和调度，不亲自执行任务
- **Worker** = Lead 创建的子 Agent。真正执行 SSH/API 操作、更新 Dashboard
- **Entity** = 你管理的目标（服务器、网站、数据集、手机等）

### 基础设施
- **Dashboard** = 本地 Web 面板（localhost:PORT），双通道交互
- **Skill** = 可复用的操作模板（健康检查、部署、日志分析等）
- **Plugin** = 后台常驻服务（飞书通知、Webhook 等）

## 数据流

```
用户指令（终端/Dashboard）
    ↓
Lead 解析意图
    ↓
SendMessage 分配给 Worker
    ↓
Worker 执行（SSH/API/本地命令）
    ↓
Worker 更新 Dashboard（curl API）
    ↓
Worker 回报 Lead（SendMessage）
    ↓
Lead 汇总展示给用户
```

## 首次启动后会发生什么

1. `session-start.sh` hook 自动触发
2. Dashboard 启动并在浏览器打开
3. Team 创建（N 个 Worker 待命）
4. 后台轮询开始（Dashboard ↔ Claude 实时联动）
5. 你可以通过终端或 Dashboard 操作

## 两个交互通道

| 通道 | 方式 | 响应速度 |
|------|------|---------|
| 终端 | 直接打字 | 即时 |
| Dashboard | 点击按钮/输入框 | 3 秒内（轮询） |

## 常见问题

**Q: Worker 和 Lead 的区别？**
Lead 是大脑（决策），Worker 是手脚（执行）。Lead 不应该直接 SSH 到服务器。

**Q: 什么时候会创建新 Worker？**
只有现有 Worker 全忙时才创建临时 Worker，完成后清理。不要无脑 spawn。

**Q: Dashboard 关了怎么办？**
`bash web/start-dashboard.sh` 重新启动，数据不会丢失。

**Q: 上下文压缩后 Worker 丢了？**
stop-check.sh 会自动注入恢复指令，读取 worker-ids.json 恢复连接。
