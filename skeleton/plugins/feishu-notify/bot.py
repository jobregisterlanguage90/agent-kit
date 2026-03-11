#!/usr/bin/env python3
"""
飞书长连接 Bot — 消息中转
接收飞书消息 → 转换为 Dashboard 消息格式 → POST /api/messages
Claude 轮询捡到消息 → 处理 → reply.sh 回复
"""

import os
import sys
import json
import logging
import re
import requests

# 加载 .env（start.sh 已预加载，这里是备用）
_script_dir = os.path.dirname(os.path.abspath(__file__))
_project_dir = os.path.dirname(os.path.dirname(_script_dir))  # plugins/feishu-notify → project root
_env_file = os.path.join(_project_dir, ".env")
if os.path.exists(_env_file):
    with open(_env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

import lark_oapi as lark
from lark_oapi.api.im.v1.model import P2ImMessageReceiveV1

APP_ID = os.environ.get("FEISHU_APP_ID", "")
APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
DASHBOARD_PORT = os.environ.get("DASHBOARD_PORT", "7890")
DASHBOARD_URL = os.environ.get("DASHBOARD_URL", f"http://localhost:{DASHBOARD_PORT}/api/messages")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [feishu-bot] %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

# ── 实体别名列表（从 entities.yaml 动态读取）──────────────────────────────
KNOWN_ALIASES = []

def _load_aliases():
    """从 entities.yaml 加载实体别名"""
    global KNOWN_ALIASES
    entities_file = os.path.join(_project_dir, "entities.yaml")
    if not os.path.exists(entities_file):
        return
    try:
        import yaml
        with open(entities_file) as f:
            config = yaml.safe_load(f)
        if config and "entities" in config:
            KNOWN_ALIASES = [e["alias"] for e in config["entities"] if "alias" in e]
        elif config and isinstance(config, list):
            KNOWN_ALIASES = [e["alias"] for e in config if "alias" in e]
        log.info("已加载 %d 个实体别名: %s", len(KNOWN_ALIASES), KNOWN_ALIASES)
    except ImportError:
        # 无 PyYAML，尝试简单解析
        with open(entities_file) as f:
            for line in f:
                m = re.match(r'\s*-?\s*alias:\s*(.+)', line)
                if m:
                    KNOWN_ALIASES.append(m.group(1).strip().strip('"').strip("'"))
    except Exception as e:
        log.warning("加载 entities.yaml 失败: %s", e)

_load_aliases()


def extract_text(message) -> str:
    """从消息对象提取纯文本"""
    try:
        content = json.loads(message.content)
        if message.message_type == "text":
            return content.get("text", "").strip()
        return ""
    except Exception:
        return ""


def find_alias(text: str) -> str:
    """从文本中提取实体别名"""
    for alias in KNOWN_ALIASES:
        if alias in text:
            return alias
    return ""


def map_to_dashboard(text: str, sender_id: str) -> dict:
    """将飞书文本映射为 Dashboard 消息格式"""
    t = text.lower().strip()

    # 全局操作
    if re.search(r"(全部|all).*(巡检|check|检查)", t) or t in ("check-all", "巡检"):
        return {"type": "quick_action", "action": "check-all"}

    # 实体级操作
    alias = find_alias(text)
    if alias:
        if re.search(r"(日志|log)", t):
            return {"type": "server_action", "server": alias, "action": "logs"}
        if re.search(r"(部署|deploy|发布)", t):
            instructions = re.sub(r"部署|deploy|发布|\s*" + alias, "", text, flags=re.I).strip()
            return {"type": "server_action", "server": alias, "action": "deploy",
                    "instructions": instructions or "按默认流程部署"}
        # 默认：检查
        return {"type": "server_action", "server": alias, "action": "check"}

    # 通用文本 → feishu_text（Claude 自由处理）
    return {"type": "feishu_text", "text": text}


def on_message(data: P2ImMessageReceiveV1) -> None:
    """飞书消息事件处理器"""
    try:
        msg = data.event.message
        sender = data.event.sender

        text = extract_text(msg)
        if not text:
            log.info("非文本消息，跳过 (type=%s)", msg.message_type)
            return

        sender_id = sender.sender_id.open_id if sender and sender.sender_id else ""
        log.info("收到消息: [%s] %r from %s", msg.message_type, text[:80], sender_id)

        payload = map_to_dashboard(text, sender_id)
        payload["reply_to"] = {
            "message_id": msg.message_id,
            "chat_id": msg.chat_id,
            "sender_open_id": sender_id,
        }
        payload["source"] = "feishu"

        resp = requests.post(DASHBOARD_URL, json=payload, timeout=5)
        if resp.ok:
            log.info("已转发到 Dashboard: type=%s", payload["type"])
        else:
            log.warning("Dashboard 响应异常: %s %s", resp.status_code, resp.text)

    except Exception as e:
        log.error("消息处理失败: %s", e, exc_info=True)


def main():
    if not APP_ID or not APP_SECRET:
        log.error("FEISHU_APP_ID / FEISHU_APP_SECRET 未配置")
        sys.exit(1)

    log.info("飞书 Bot 启动 (App ID: %s...)", APP_ID[:12])

    event_handler = (
        lark.EventDispatcherHandler.builder("", "", lark.LogLevel.WARNING)
        .register_p2_im_message_receive_v1(on_message)
        .build()
    )

    ws_client = lark.ws.Client(
        APP_ID,
        APP_SECRET,
        event_handler=event_handler,
        log_level=lark.LogLevel.WARNING,
        auto_reconnect=True,
    )

    log.info("建立飞书 WebSocket 长连接...")

    import threading
    import time

    def _watch():
        try:
            ws_client.start()
        except Exception as e:
            log.error("WebSocket 连接失败: %s", e)
            sys.exit(1)

    t = threading.Thread(target=_watch, daemon=True)
    t.start()
    time.sleep(5)
    if t.is_alive():
        log.info("长连接已建立，Bot 在线监听中")
    else:
        log.error("连接线程已退出")
        sys.exit(1)

    t.join()


if __name__ == "__main__":
    main()
