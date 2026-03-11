#!/usr/bin/env python3
"""
飞书多维表格建表脚本（通用版）
在现有 Bitable 文档中创建数据表 + 字段
运行后自动将 table_id 写入 .env

表 schema 在 TABLES_SCHEMA 中定义，项目按需修改。

用法：
  python3 plugins/feishu-notify/setup-bitable.py
  python3 plugins/feishu-notify/setup-bitable.py --app-token <BITABLE_APP_TOKEN>
"""

import os
import sys
import json
import argparse
import requests

_script_dir = os.path.dirname(os.path.abspath(__file__))
_project_dir = os.path.dirname(os.path.dirname(_script_dir))  # plugins/feishu-notify → project root
_env_file = os.path.join(_project_dir, ".env")

# 加载 .env
if os.path.exists(_env_file):
    with open(_env_file) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, _, v = line.partition("=")
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

APP_ID = os.environ.get("FEISHU_APP_ID", "")
APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
BASE_URL = "https://open.feishu.cn/open-apis"

# ══════════════════════════════════════════════════════════════════════════
# 表结构定义 — 项目按需修改此处
# field_type: 1=Text, 2=Number, 3=SingleSelect, 4=MultiSelect,
#             5=Date(Datetime), 7=Checkbox, 11=Person
# ══════════════════════════════════════════════════════════════════════════
TABLES_SCHEMA = [
    # 示例表 — 项目按需替换
    {
        "name": "操作记录",
        "env_key": "FEISHU_OPS_TABLE_ID",
        "fields": [
            {"field_name": "操作时间", "type": 5,
             "property": {"date_formatter": "yyyy/MM/dd HH:mm"}},
            {"field_name": "实体", "type": 1},
            {"field_name": "操作类型", "type": 3,
             "property": {"options": [{"name": "检查"}, {"name": "部署"}, {"name": "配置"}]}},
            {"field_name": "结果", "type": 3,
             "property": {"options": [{"name": "成功"}, {"name": "失败"}]}},
            {"field_name": "详情", "type": 1},
        ]
    },
]


def get_token() -> str:
    resp = requests.post(f"{BASE_URL}/auth/v3/tenant_access_token/internal",
                         json={"app_id": APP_ID, "app_secret": APP_SECRET}, timeout=10)
    data = resp.json()
    token = data.get("tenant_access_token", "")
    if not token:
        print(f"获取 token 失败: {data}")
        sys.exit(1)
    return token


def create_table(token: str, app_token: str, table_name: str) -> str:
    resp = requests.post(
        f"{BASE_URL}/bitable/v1/apps/{app_token}/tables",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"table": {"name": table_name}},
        timeout=10
    )
    data = resp.json()
    if data.get("code") != 0:
        print(f"创建表 '{table_name}' 失败: {data}")
        return ""
    return data["data"]["table_id"]


def list_tables(token: str, app_token: str) -> dict:
    resp = requests.get(
        f"{BASE_URL}/bitable/v1/apps/{app_token}/tables",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    data = resp.json()
    if data.get("code") != 0:
        return {}
    return {t["name"]: t["table_id"] for t in data.get("data", {}).get("items", [])}


def add_field(token: str, app_token: str, table_id: str, field: dict):
    body = {"field_name": field["field_name"], "type": field["type"]}
    if "property" in field:
        body["property"] = field["property"]
    resp = requests.post(
        f"{BASE_URL}/bitable/v1/apps/{app_token}/tables/{table_id}/fields",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json=body,
        timeout=10
    )
    data = resp.json()
    if data.get("code") != 0:
        print(f"  添加字段 '{field['field_name']}' 失败: {data.get('msg')}")
    else:
        print(f"  + {field['field_name']}")


def list_fields(token: str, app_token: str, table_id: str) -> list:
    resp = requests.get(
        f"{BASE_URL}/bitable/v1/apps/{app_token}/tables/{table_id}/fields",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10
    )
    data = resp.json()
    return [f["field_name"] for f in data.get("data", {}).get("items", [])]


def update_env(key: str, value: str):
    if not os.path.exists(_env_file):
        return
    with open(_env_file, "r") as f:
        lines = f.readlines()
    updated = False
    new_lines = []
    for line in lines:
        if line.startswith(f"{key}="):
            new_lines.append(f"{key}={value}\n")
            updated = True
        else:
            new_lines.append(line)
    if not updated:
        new_lines.append(f"{key}={value}\n")
    with open(_env_file, "w") as f:
        f.writelines(new_lines)


def main():
    parser = argparse.ArgumentParser(description="飞书多维表格建表脚本")
    parser.add_argument("--app-token", default=os.environ.get("FEISHU_BITABLE_APP_TOKEN", ""),
                        help="Bitable 文档 Token")
    args = parser.parse_args()

    app_token = args.app_token.strip()
    if not app_token:
        print("错误：需要 FEISHU_BITABLE_APP_TOKEN")
        print("  .env 设置或 --app-token 传入")
        sys.exit(1)

    if not APP_ID or not APP_SECRET:
        print("错误：FEISHU_APP_ID / FEISHU_APP_SECRET 未配置")
        sys.exit(1)

    print(f"App ID: {APP_ID[:12]}...")
    print(f"Bitable: {app_token[:12]}...")
    print()

    token = get_token()
    existing_tables = list_tables(token, app_token)
    print(f"现有表格: {list(existing_tables.keys()) or '(空)'}")
    print()

    results = {}
    for schema in TABLES_SCHEMA:
        table_name = schema["name"]
        env_key = schema["env_key"]

        print(f"── {table_name} ──")

        if table_name in existing_tables:
            table_id = existing_tables[table_name]
            print(f"  已存在 table_id: {table_id}")
        else:
            table_id = create_table(token, app_token, table_name)
            if not table_id:
                continue
            print(f"  创建成功 table_id: {table_id}")

        existing_fields = list_fields(token, app_token, table_id)
        for field in schema["fields"]:
            if field["field_name"] not in existing_fields:
                add_field(token, app_token, table_id, field)
            else:
                print(f"  ✓ {field['field_name']} (已存在)")

        results[env_key] = table_id
        update_env(env_key, table_id)
        print()

    print("=== 完成 ===")
    print("已写入 .env：")
    for k, v in results.items():
        print(f"  {k}={v}")

    if not os.environ.get("FEISHU_BITABLE_APP_TOKEN"):
        update_env("FEISHU_BITABLE_APP_TOKEN", app_token)


if __name__ == "__main__":
    main()
