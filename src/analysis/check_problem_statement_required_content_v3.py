#!/usr/bin/env python3
"""
分析 result/strengthen/v3/all_nl_fuzzy_not_discard_all_models_failed_sorted.json 中
每条 problem_statement 是否包含“必需内容”，并输出 JSON。

判定维度（固定，不改名）:
- non_empty
- has_change_intent
- has_change_location
- has_verifiable_constraints
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

INPUT_REL = "result/strengthen/v3/all_nl_fuzzy_not_discard_all_models_failed_sorted.json"
OUTPUT_DIR_REL = "result/strengthen/v3"
OUTPUT_NAME = "problem_statement_required_content_check.json"
SLEEP = 0.2
CHECKPOINT_EVERY = 5
HTTP_REQUEST_TIMEOUT_SEC = 900.0

SYSTEM_PROMPT = """你是软件修复任务描述审核助手。请判断给定 problem_statement 是否包含以下必需内容：
1) non_empty: 文本非空且不是无意义占位内容；
2) has_change_intent: 明确描述“要改什么/修什么/目标行为”；
3) has_change_location: 提供改动定位线索（文件路径、模块、类、函数、符号、组件等任一）；
4) has_verifiable_constraints: 提供可验证约束（期望/错误/返回值/测试可观察行为等）。

输出要求：
- 只输出一个 JSON 对象，不要 Markdown，不要额外解释。
- JSON 结构必须是：
{
  "checks": {
    "non_empty": true,
    "has_change_intent": true,
    "has_change_location": true,
    "has_verifiable_constraints": true
  },
  "complete": true,
  "missing_items": [],
  "reason_zh": "1-2句中文说明",
  "confidence": 0.0
}
- missing_items 只能从:
  ["non_empty","has_change_intent","has_change_location","has_verifiable_constraints"]
- complete 必须与 checks 一致：四项全 true 才能为 true。
- confidence ∈ [0,1]。
"""

USER_TPL = """instance_id: {instance_id}

problem_statement:
{problem_statement}
"""

_VALID_KEYS = (
    "non_empty",
    "has_change_intent",
    "has_change_location",
    "has_verifiable_constraints",
)


def load_json(path: Path, optional: bool = False) -> list | dict:
    if not path.exists():
        if not optional:
            print(f"Error: 文件不存在: {path}", file=sys.stderr)
        return []
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build_index(data: list, key: str = "instance_id") -> dict:
    return {item[key]: item for item in data if isinstance(item, dict) and key in item}


def extract_json_object(text: str) -> dict[str, Any]:
    t = (text or "").strip()
    if not t:
        raise ValueError("empty model response")
    fence = re.match(r"^```(?:json)?\s*([\s\S]*?)\s*```\s*$", t)
    if fence:
        t = fence.group(1).strip()
    start = t.find("{")
    end = t.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("no JSON object in response")
    return json.loads(t[start : end + 1])


def call_llm(client: Any, model: str, messages: list[dict[str, str]], stream: bool = True) -> str:
    completion = client.chat.completions.create(
        model=model,
        messages=messages,
        stream=stream,
        timeout=HTTP_REQUEST_TIMEOUT_SEC,
    )
    if not stream:
        return (completion.choices[0].message.content or "").strip()
    content = ""
    for chunk in completion:
        if not chunk.choices:
            continue
        delta = chunk.choices[0].delta
        if hasattr(delta, "content") and delta.content:
            content += delta.content
    return content.strip()


def normalize_result(raw_obj: dict[str, Any]) -> dict[str, Any]:
    checks_raw = raw_obj.get("checks") if isinstance(raw_obj.get("checks"), dict) else {}
    checks: dict[str, bool] = {}
    for k in _VALID_KEYS:
        checks[k] = checks_raw.get(k) is True

    missing_raw = raw_obj.get("missing_items")
    missing_items: list[str] = []
    if isinstance(missing_raw, list):
        for x in missing_raw:
            if isinstance(x, str) and x in _VALID_KEYS and x not in missing_items:
                missing_items.append(x)

    derived_missing = [k for k, ok in checks.items() if not ok]
    if not missing_items:
        missing_items = derived_missing
    else:
        missing_items = sorted(set(missing_items) | set(derived_missing))

    complete = len(derived_missing) == 0

    conf = raw_obj.get("confidence", 0.0)
    try:
        conf_f = float(conf)
    except Exception:
        conf_f = 0.0
    conf_f = max(0.0, min(1.0, conf_f))

    return {
        "checks": checks,
        "complete": complete,
        "missing_items": missing_items,
        "reason_zh": str(raw_obj.get("reason_zh") or "").strip(),
        "confidence": conf_f,
    }


def resolve_api_config() -> tuple[str, str, str]:
    base_url = os.getenv("OPENAI_BASE_URL", "https://aihubmix.com/v1")
    api_key = os.getenv("OPENAI_API_KEY", "")
    model = os.getenv("OPENAI_MODEL", "claude-sonnet-4-20250514")
    return base_url, api_key, model


def build_report(rows: list[dict[str, Any]], input_path: Path, out_path: Path, model: str) -> dict[str, Any]:
    total = len(rows)
    complete_count = sum(1 for r in rows if r.get("complete") is True)
    incomplete_count = sum(1 for r in rows if r.get("complete") is False)
    unknown_count = sum(1 for r in rows if r.get("complete") is None)

    missing_stats = {k: 0 for k in _VALID_KEYS}
    for r in rows:
        miss = r.get("missing_items") or []
        for k in miss:
            if k in missing_stats:
                missing_stats[k] += 1

    return {
        "input": str(input_path),
        "output": str(out_path),
        "model": model,
        "summary": {
            "total": total,
            "complete_count": complete_count,
            "incomplete_count": incomplete_count,
            "unknown_count": unknown_count,
            "complete_ratio": round(complete_count / total, 4) if total else 0.0,
            "missing_stats": missing_stats,
        },
        "rows": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="用 LLM 判定 problem_statement 是否包含必需内容")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不调用 API")
    parser.add_argument("--limit", type=int, default=None, help="只处理前 N 条（用于试跑）")
    parser.add_argument("--output", type=str, default=None, help="输出文件名")
    parser.add_argument("--stream", action="store_true", default=True, help="流式调用")
    parser.add_argument("--no-stream", dest="stream", action="store_false")
    args = parser.parse_args()

    base = Path(__file__).resolve().parents[3]
    input_path = base / INPUT_REL
    out_dir = base / OUTPUT_DIR_REL
    out_name = args.output or OUTPUT_NAME
    out_path = out_dir / out_name

    data = load_json(input_path)
    if not isinstance(data, list) or not data:
        print("Error: 输入 JSON 应为非空数组", file=sys.stderr)
        sys.exit(1)

    base_url, api_key, model = resolve_api_config()
    if not args.dry_run and not api_key:
        print("Error: 未设置 OPENAI_API_KEY", file=sys.stderr)
        sys.exit(1)

    rows: list[dict[str, Any]] = []
    done_ids: set[str] = set()
    existing_map: dict = {}
    if out_path.exists():
        existing = load_json(out_path, optional=True)
        if isinstance(existing, dict) and isinstance(existing.get("rows"), list):
            existing_rows = existing["rows"]
            done_ids = {
                str(item.get("instance_id"))
                for item in existing_rows
                if isinstance(item, dict) and item.get("complete") in (True, False)
            }
            existing_map = build_index(existing_rows)
            if done_ids:
                print(f"发现已有输出，{len(done_ids)} 条已完成，将跳过")

    total = len(data)
    to_process = data
    if args.limit is not None:
        to_process = data[: args.limit]

    if args.dry_run:
        print("=== Dry-run ===")
        print(f"输入: {input_path}")
        print(f"输出: {out_path}")
        print(f"模型: {model}  base_url: {base_url}")
        print(f"将处理: {len(to_process)} / {total}")
        return

    from openai import OpenAI

    client = OpenAI(api_key=api_key, base_url=base_url, timeout=HTTP_REQUEST_TIMEOUT_SEC)
    out_dir.mkdir(parents=True, exist_ok=True)

    processed_new = 0
    for i, item in enumerate(to_process):
        if not isinstance(item, dict):
            continue
        iid = str(item.get("instance_id", ""))
        ps = item.get("problem_statement")
        ps_text = ps if isinstance(ps, str) else ""

        if iid in done_ids and iid in existing_map:
            rows.append(existing_map[iid])
            print(f"[{i+1}/{len(to_process)}] {iid} -> skip (checkpoint)")
            continue

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": USER_TPL.format(instance_id=iid, problem_statement=ps_text)},
        ]

        try:
            raw = call_llm(client, model, messages, stream=args.stream)
            obj = extract_json_object(raw)
            n = normalize_result(obj)
            row = {
                "instance_id": iid,
                "checks": n["checks"],
                "complete": n["complete"],
                "missing_items": n["missing_items"],
                "reason_zh": n["reason_zh"],
                "confidence": n["confidence"],
                "problem_statement_length": len(ps_text),
            }
            rows.append(row)
            processed_new += 1
            print(f"[{i+1}/{len(to_process)}] {iid} ✓")
        except Exception as e:
            row = {
                "instance_id": iid,
                "checks": {k: None for k in _VALID_KEYS},
                "complete": None,
                "missing_items": [],
                "reason_zh": "",
                "confidence": 0.0,
                "problem_statement_length": len(ps_text),
                "error": str(e),
            }
            rows.append(row)
            print(f"[{i+1}/{len(to_process)}] {iid} FAILED: {e}", file=sys.stderr)

        if SLEEP > 0:
            time.sleep(SLEEP)

        if processed_new > 0 and processed_new % CHECKPOINT_EVERY == 0:
            report = build_report(rows, input_path, out_path, model)
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
            print(f"--- Checkpoint: {out_path} ({processed_new} new) ---")

    report = build_report(rows, input_path, out_path, model)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    print(f"\n完成: 总 {report['summary']['total']} 条，新增处理 {processed_new} 条 -> {out_path}")


if __name__ == "__main__":
    main()
