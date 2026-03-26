# 项目记忆

## 概述
此文件由 setup.sh 同步到 Claude 自动记忆目录。
Claude Code 启动时自动加载，跨会话持久。

## Claude 记忆机制说明
- **项目记忆位置**：`~/.claude/projects/{encoded_path}/memory/MEMORY.md`
- **路径编码规则**：`/` 替换为 `-`（如 `/Users/lizi/code/xxx` → `-Users-lizi-code-xxx`）
- **同步方式**：`bash setup.sh` 自动复制到 Claude 目录
- **重要**：此文件为可开源的项目级记忆，不含隐私信息

## 架构
- `CLAUDE.md` — Agent 角色定义 + 行为规范
- `entities.yaml` — 实体清单（服务器/网站/数据集等）
- `skills/` — 技能目录（symlink 到 `~/.claude/skills/`）
- `plugins/` — 后台插件（飞书/Webhook 等）
- `memory/` — 实体知识文件（git 追踪）
  - `memory/knowledge/` — 可开源的领域知识
  - `memory/private/` — 隐私数据（gitignore 排除）
- `web/` — Dashboard 可视化面板
- `data/` — 运行时数据（gitignore 排除）
- `scripts/` — 自动化脚本

## 隐私边界

### 不应写入此文件（机器级/隐私）
- SSH 密钥、密码、API Token
- `.env` 中的密钥和凭证
- `~/.ssh/config` 具体内容
- 服务器 IP 地址和端口
- 用户个人信息

### 适合写入此文件（项目知识）
- 架构决策和设计原因
- 实体分组逻辑和职责分工
- 已知问题和 workaround
- 运维/运营约定和流程
- Worker 分工策略

## 重要决策

（在此记录项目级别的重要决策）
