#!/usr/bin/env python3
"""result/strengthen/v2/all_nl_enhanced.json + explain -> result/strengthen/v3/all_nl_fuzzy.json"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

INPUT_REL = "result/strengthen/v2/all_nl_enhanced.json"
EXPLAIN_REL = "result/strengthen/v1/explain_over_narrow_result.json"
OUTPUT_DIR_REL = "result/strengthen/v3"
OUTPUT_NAME = "all_nl_fuzzy.json"

SLEEP = 0.5
CHECKPOINT_EVERY = 5

HTTP_REQUEST_TIMEOUT_SEC = 900.0

SYSTEM_PROMPT = """\
You are producing a **fuzzied** problem statement for a **coding-agent** software-repair benchmark: \
agents read the issue and submit patches; evaluation is against tests.

**Evaluability** and **difficulty** are the trade: keep test-observable requirements and \
hardcoded expectations **clear**, while leaving **how and where to fix** vague or unstated: \
no fix recipe, no step-by-step plan, no file/module roadmap, no algorithm walkthrough. Symptoms \
and externally checkable requirements stay; the path from reading the issue to writing a patch \
stays under-specified.

The current text may have redundancy; tighten wording where you can without dropping anything \
the tests need.

Over-narrow findings list hardcoded test expectations—those observables must remain explicit.

Use the test patch to know which behaviors must still be satisfied.

Output only the new problem statement.
"""

USER_TPL = """\
## Current problem statement (v2 enhanced)
{problem_statement}

## Over-narrow findings
{over_narrow_findings}

## Test patch
{test_patch}
"""


def load_json(path: Path, optional: bool = False) -> list | dict:
    if not path.exists():
        if not optional:
            print(f"Error: 文件不存在: {path}", file=sys.stderr)
        return []
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build_index(data: list, key: str = "instance_id") -> dict:
    return {item[key]: item for item in data if key in item}


def format_over_narrow_findings(findings: list) -> str:
    if not findings:
        return "(none — no explain entries for this instance; build the observable requirement \
set from the current problem statement.)"
    lines = []
    for i, f in enumerate(findings, 1):
        lines.append(
            f"{i}. [{f.get('category', 'unknown')}] "
            f"file={f.get('file', '?')}, symbol={f.get('symbol', '?')!r}\n"
            f"   constraint: {f.get('constraint', '?')}"
        )
    return "\n".join(lines)


def call_llm(client, model: str, messages: list, stream: bool = True) -> str:
    completion = client.chat.completions.create(
        model=model,
        messages=messages,
        stream=stream,
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


def resolve_api_config():
    base_url = os.getenv("OPENAI_BASE_URL", "https://aihubmix.com/v1").rstrip("/")
    api_key = (
        (os.getenv("OPENAI_API_KEY") or "").strip()
        or (os.getenv("CLAUDE_API_KEY") or "").strip()
        or (os.getenv("QWEN_API_KEY") or "").strip()
        or (os.getenv("API_KEY") or "").strip()
    )
    model = os.getenv("OPENAI_MODEL", "claude-opus-4-6-think")
    return base_url, api_key, model


def main():
    parser = argparse.ArgumentParser(description="v3 模糊化 problem_statement 并保留测试约束")
    parser.add_argument("--dry-run", action="store_true", help="只打印计划，不调用 API")
    parser.add_argument("--limit", type=int, default=None, help="只处理前 N 条（用于试跑）")
    parser.add_argument("--output", type=str, default=None, help="输出文件名（默认 all_nl_fuzzy.json）")
    parser.add_argument("--stream", action="store_true", default=True, help="流式调用")
    parser.add_argument("--no-stream", dest="stream", action="store_false")
    args = parser.parse_args()

    base = Path(__file__).resolve().parents[3]
    input_path = base / INPUT_REL
    explain_path = base / EXPLAIN_REL
    out_dir = base / OUTPUT_DIR_REL
    out_name = args.output or OUTPUT_NAME
    out_path = out_dir / out_name

    data = load_json(input_path)
    if not isinstance(data, list) or not data:
        print("Error: 输入 JSON 应为非空数组", file=sys.stderr)
        sys.exit(1)

    explain_raw = load_json(explain_path, optional=True)
    if not explain_raw:
        print(
            "Warning: explain 文件为空或缺失，所有实例将仅依据 test_patch 推断约束",
            file=sys.stderr,
        )
    narrow_map = build_index(explain_raw if isinstance(explain_raw, list) else [])

    base_url, api_key, model = resolve_api_config()
    if not args.dry_run and not api_key:
        print(
            "Error: 未设置 API Key。请设置 OPENAI_API_KEY（或 CLAUDE_API_KEY / QWEN_API_KEY / API_KEY）。",
            file=sys.stderr,
        )
        sys.exit(1)

    done_ids: set[str] = set()
    existing_map: dict = {}
    if out_path.exists():
        existing = load_json(out_path)
        if isinstance(existing, list) and existing:
            done_ids = {
                item.get("instance_id")
                for item in existing
                if item.get("_enhance_v3")
            }
            existing_map = build_index(existing)
            if done_ids:
                print(f"发现已有输出，{len(done_ids)} 条已标记 _enhance_v3，将跳过")
                for i, item in enumerate(data):
                    iid = item.get("instance_id", "")
                    if iid in done_ids and iid in existing_map:
                        data[i] = existing_map[iid]

    total = len(data)
    processed = 0
    limit = args.limit

    if args.dry_run:
        preview_n = limit if limit is not None else 5
        key_ok = bool(api_key)
        print("=== Dry-run ===")
        print("不调用 API、不写文件，因此不会出现模型改写后的 problem_statement。")
        print("要看真实输出请去掉 --dry-run（可配合 --limit 1 试跑一条）。")
        print(f"输入: {input_path}")
        print(f"explain: {explain_path}")
        print(f"正式运行将写入: {out_path}")
        print(f"将使用的模型: {model}  base_url: {base_url}  API Key: {'已设置' if key_ok else '未设置（dry-run 不检查）'}")
        print(f"数据集共 {total} 条；explain 中有记录的 instance_id: {len(narrow_map)} 个")
        if done_ids:
            print(f"已有 checkpoint（将跳过）: {len(done_ids)} 条")
        print(f"下面预览前 {preview_n} 条数据的元信息（--limit 控制预览条数；未指定则预览 5 条）：")
        print()
        for i, item in enumerate(data[:preview_n]):
            iid = item.get("instance_id", "")
            n = len(narrow_map.get(iid, {}).get("over_narrow_findings", []))
            ps = item.get("problem_statement") or ""
            gp = item.get("patch") or ""
            print(f"  [{i+1}] {iid}")
            print(f"      over_narrow_findings: {n}  |  problem_statement: {len(ps)} 字符")
            print(f"      golden patch: {len(gp)} 字符")
        if limit is None and total > preview_n:
            print(f"  … 共省略 {total - preview_n} 条（加 --limit 可增大预览范围）")
        print()
        return

    from openai import OpenAI

    client = OpenAI(
        api_key=api_key,
        base_url=base_url,
        timeout=HTTP_REQUEST_TIMEOUT_SEC,
    )
    out_dir.mkdir(parents=True, exist_ok=True)

    for i, item in enumerate(data):
        iid = item.get("instance_id", "")
        if iid in done_ids:
            print(f"[{i+1}/{total}] {iid} -> skip (checkpoint)")
            continue

        if limit is not None and processed >= limit:
            print(f"[{i+1}/{total}] {iid} -> skip (--limit {limit})")
            break

        findings = narrow_map.get(iid, {}).get("over_narrow_findings", [])
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": USER_TPL.format(
                    problem_statement=item.get("problem_statement", ""),
                    over_narrow_findings=format_over_narrow_findings(findings),
                    test_patch=item.get("test_patch", ""),
                ),
            },
        ]

        try:
            rewritten = call_llm(client, model, messages, stream=args.stream)
            if rewritten:
                item["problem_statement"] = rewritten
                item["_enhance_v3"] = True
                item["_enhance_v3_model"] = model
                processed += 1
            print(f"[{i+1}/{total}] {iid} ✓")
        except Exception as e:
            print(f"[{i+1}/{total}] {iid} FAILED: {e}", file=sys.stderr)

        if SLEEP > 0:
            time.sleep(SLEEP)

        if processed % CHECKPOINT_EVERY == 0 and processed > 0:
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--- Checkpoint: {out_path} ({processed} new) ---")

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"\n完成: 共 {total} 条，本轮新增强 {processed} 条 -> {out_path}")


if __name__ == "__main__":
    main()
