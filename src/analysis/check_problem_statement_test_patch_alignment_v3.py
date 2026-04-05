#!/usr/bin/env python3
"""
用 LLM 判断 problem_statement 是否与 test_patch 相符，
并检查 problem_statement 是否提供了 test_patch 需要的硬编码内容。
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

INPUT_REL = "result/strengthen/v3/not_cursor_fuzzy.json"
OUTPUT_DIR_REL = "result/strengthen/v3"
OUTPUT_NAME = "problem_statement_test_patch_alignment_check.json"
CHECKPOINT_EVERY = 5
SLEEP = 0.2
HTTP_REQUEST_TIMEOUT_SEC = 900.0
DEFAULT_BASE_URL = "https://aihubmix.com/v1"
DEFAULT_MODEL = "claude-opus-4-6-think"

SYSTEM_PROMPT = """你是软件修复任务一致性审核助手。你将看到同一实例的:
1) problem_statement（任务描述）
2) test_patch（用于验证修复的测试补丁）

请判断：
- problem_statement 是否与 test_patch 所验证的行为一致（alignment）
- problem_statement 是否给出了 test_patch 所需的“硬编码内容”线索（例如关键常量、字面量、精确路径/符号名、明确输入输出值、必要的固定错误文本/返回值等）

规则：
- “硬编码内容”只统计 test_patch 真正依赖且缺失后难以正确实现的关键信息。
- 如果 test_patch 只校验泛化行为，不依赖具体字面量，可判为不需要额外硬编码内容。
- 不要求逐字复述；语义等价即可。

只输出一个 JSON 对象（不要 Markdown，不要额外说明），结构必须为：
{
  "aligned": true,
  "hardcoded_content_complete": true,
  "missing_hardcoded_items": [],
  "reason_zh": "1-3句中文说明",
  "confidence": 0.0
}

约束：
- missing_hardcoded_items 必须是字符串数组；若 complete=true 则应为空数组。
- confidence ∈ [0, 1]。
"""

USER_TPL = """instance_id: {instance_id}

problem_statement:
{problem_statement}

test_patch:
{test_patch}
"""


def load_json(path: Path, optional: bool = False) -> list | dict:
    if not path.exists():
        if not optional:
            print(f"Error: 文件不存在: {path}", file=sys.stderr)
        return []
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


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
    aligned = raw_obj.get("aligned") is True
    complete = raw_obj.get("hardcoded_content_complete") is True

    missing_raw = raw_obj.get("missing_hardcoded_items")
    missing_items: list[str] = []
    if isinstance(missing_raw, list):
        for x in missing_raw:
            if isinstance(x, str):
                s = x.strip()
                if s and s not in missing_items:
                    missing_items.append(s)
    if complete:
        missing_items = []
    elif not missing_items:
        missing_items = ["<模型未明确给出缺失项>"]

    reason = str(raw_obj.get("reason_zh") or "").strip()
    conf = raw_obj.get("confidence", 0.0)
    try:
        conf_f = float(conf)
    except Exception:
        conf_f = 0.0
    conf_f = max(0.0, min(1.0, conf_f))

    return {
        "aligned": aligned,
        "hardcoded_content_complete": complete,
        "missing_hardcoded_items": missing_items,
        "reason_zh": reason,
        "confidence": conf_f,
    }


def resolve_api_config() -> tuple[str, str, str]:
    base_url = os.getenv("OPENAI_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    api_key = (
        (os.getenv("OPENAI_API_KEY") or "").strip()
        or (os.getenv("CLAUDE_API_KEY") or "").strip()
        or (os.getenv("QWEN_API_KEY") or "").strip()
        or (os.getenv("API_KEY") or "").strip()
    )
    model = os.getenv("OPENAI_MODEL", DEFAULT_MODEL)
    return base_url, api_key, model


def build_report(rows: list[dict[str, Any]], input_path: Path, out_path: Path, model: str) -> dict[str, Any]:
    total = len(rows)
    aligned_count = sum(1 for r in rows if r.get("aligned") is True)
    not_aligned_count = sum(1 for r in rows if r.get("aligned") is False)
    hardcoded_complete_count = sum(1 for r in rows if r.get("hardcoded_content_complete") is True)
    hardcoded_missing_count = sum(1 for r in rows if r.get("hardcoded_content_complete") is False)
    unknown_count = sum(
        1
        for r in rows
        if r.get("aligned") is None or r.get("hardcoded_content_complete") is None
    )

    return {
        "input": str(input_path),
        "output": str(out_path),
        "model": model,
        "summary": {
            "total": total,
            "aligned_count": aligned_count,
            "not_aligned_count": not_aligned_count,
            "aligned_ratio": round(aligned_count / total, 4) if total else 0.0,
            "hardcoded_content_complete_count": hardcoded_complete_count,
            "hardcoded_content_missing_count": hardcoded_missing_count,
            "hardcoded_content_complete_ratio": round(hardcoded_complete_count / total, 4) if total else 0.0,
            "unknown_count": unknown_count,
        },
        "rows": rows,
    }


def pick_done_ids(existing_rows: list[Any]) -> set[str]:
    done: set[str] = set()
    for item in existing_rows:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if not isinstance(iid, str) or not iid:
            continue
        if item.get("aligned") in (True, False) and item.get("hardcoded_content_complete") in (True, False):
            done.add(iid)
    return done


def main() -> None:
    parser = argparse.ArgumentParser(
        description="用 LLM 判定 problem_statement 与 test_patch 的一致性及硬编码内容覆盖度"
    )
    parser.add_argument("--input", type=str, default=INPUT_REL, help="输入 JSON（数组）")
    parser.add_argument("--output", type=str, default=OUTPUT_NAME, help="输出 JSON 文件名")
    parser.add_argument("--output-dir", type=str, default=OUTPUT_DIR_REL, help="输出目录")
    parser.add_argument("--limit", type=int, default=None, help="只处理前 N 条")
    parser.add_argument("--offset", type=int, default=0, help="从第 N 条开始")
    parser.add_argument("--instance-id", action="append", default=None, help="仅处理指定实例 id，可多次传入")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不调用 API")
    parser.add_argument("--stream", action="store_true", default=True, help="流式调用")
    parser.add_argument("--no-stream", dest="stream", action="store_false")
    parser.add_argument("--resume", action="store_true", default=True, help="若输出文件存在则断点续跑")
    parser.add_argument("--no-resume", dest="resume", action="store_false")
    args = parser.parse_args()

    base = Path(__file__).resolve().parents[3]
    input_path = base / args.input
    out_dir = base / args.output_dir
    out_path = out_dir / args.output

    data = load_json(input_path)
    if not isinstance(data, list) or not data:
        print("Error: 输入 JSON 应为非空数组", file=sys.stderr)
        sys.exit(1)

    base_url, api_key, model = resolve_api_config()
    if not args.dry_run and not api_key:
        print(
            "Error: 请设置环境变量 OPENAI_API_KEY、CLAUDE_API_KEY、QWEN_API_KEY 或 API_KEY",
            file=sys.stderr,
        )
        sys.exit(1)

    selected = data[args.offset :] if args.offset > 0 else data
    if args.instance_id:
        want = {x.strip() for x in args.instance_id if x and x.strip()}
        selected = [it for it in selected if isinstance(it, dict) and str(it.get("instance_id", "")) in want]
    if args.limit is not None:
        selected = selected[: args.limit]

    if args.dry_run:
        print("=== Dry-run ===")
        print(f"输入: {input_path}")
        print(f"输出: {out_path}")
        print(f"模型: {model}  base_url: {base_url}")
        print(f"将处理: {len(selected)} / {len(data)}")
        return

    from openai import OpenAI

    out_dir.mkdir(parents=True, exist_ok=True)
    existing_map: dict[str, dict[str, Any]] = {}
    done_ids: set[str] = set()
    if args.resume and out_path.exists():
        existing = load_json(out_path, optional=True)
        if isinstance(existing, dict) and isinstance(existing.get("rows"), list):
            for row in existing["rows"]:
                if isinstance(row, dict) and isinstance(row.get("instance_id"), str):
                    existing_map[row["instance_id"]] = row
            done_ids = pick_done_ids(existing["rows"])
            if done_ids:
                print(f"发现已有输出，{len(done_ids)} 条已完成，将跳过")

    client = OpenAI(api_key=api_key, base_url=base_url, timeout=HTTP_REQUEST_TIMEOUT_SEC)
    rows: list[dict[str, Any]] = []
    processed_new = 0

    for i, item in enumerate(selected):
        if not isinstance(item, dict):
            continue
        iid = str(item.get("instance_id", ""))
        problem_statement = item.get("problem_statement")
        test_patch = item.get("test_patch")
        ps_text = problem_statement if isinstance(problem_statement, str) else ""
        tp_text = test_patch if isinstance(test_patch, str) else ""

        if iid in done_ids and iid in existing_map:
            rows.append(existing_map[iid])
            print(f"[{i + 1}/{len(selected)}] {iid} -> skip (checkpoint)")
            continue

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": USER_TPL.format(
                    instance_id=iid,
                    problem_statement=ps_text,
                    test_patch=tp_text,
                ),
            },
        ]

        try:
            raw = call_llm(client, model, messages, stream=args.stream)
            obj = extract_json_object(raw)
            n = normalize_result(obj)
            row = {
                "instance_id": iid,
                "aligned": n["aligned"],
                "hardcoded_content_complete": n["hardcoded_content_complete"],
                "missing_hardcoded_items": n["missing_hardcoded_items"],
                "reason_zh": n["reason_zh"],
                "confidence": n["confidence"],
                "problem_statement_length": len(ps_text),
                "test_patch_length": len(tp_text),
            }
            rows.append(row)
            processed_new += 1
            print(f"[{i + 1}/{len(selected)}] {iid} ✓")
        except Exception as e:
            row = {
                "instance_id": iid,
                "aligned": None,
                "hardcoded_content_complete": None,
                "missing_hardcoded_items": [],
                "reason_zh": "",
                "confidence": 0.0,
                "problem_statement_length": len(ps_text),
                "test_patch_length": len(tp_text),
                "error": str(e),
            }
            rows.append(row)
            print(f"[{i + 1}/{len(selected)}] {iid} FAILED: {e}", file=sys.stderr)

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
