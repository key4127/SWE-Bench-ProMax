#!/usr/bin/env python3
"""
使用 Claude/OPUS 对数据集中的 refactoring task 进行多标签分类。
分析每个 instance 的 patch + problem_statement，输出：
  - primary_category / secondary_categories（任务类型）
  - reasoning_abilities（需要的推理能力）

数据源: result/strengthen/v3/all_nl_fuzzy.json（过滤 discard != true 的项）

依赖: pip install openai
运行前: conda activate all
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

from openai import OpenAI

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

API_URL = os.getenv("OPENAI_BASE_URL", "https://aihubmix.com/v1").rstrip("/")
MODEL = os.getenv("OPENAI_MODEL", "claude-sonnet-4-6")

PATCH_MAX_CHARS = 3000
PROBLEM_MAX_CHARS = 1500
SLEEP = 0.5
CHECKPOINT_EVERY = 10

ALL_CATEGORIES = [
    "bug_fix",
    "security_patch",
    "performance_optimization",
    "new_feature",
    "api_interface_change",
    "refactoring_cleanup",
    "error_handling",
    "dependency_integration",
    "test_improvement",
    "documentation_nl",
]

ALL_ABILITIES = [
    "type_system",
    "control_flow",
    "data_flow",
    "api_semantics",
    "memory_management",
    "concurrency",
    "security_reasoning",
    "protocol_understanding",
    "cross_file_reasoning",
    "interface_contract",
    "pattern_matching",
    "domain_knowledge",
]

SYSTEM_PROMPT = """You are a software engineering researcher analyzing code patches and issue descriptions.
Many patches serve multiple purposes at once (e.g., fix a bug AND change an API signature, or refactor AND improve error handling).

Step 1: Identify ALL aspects of this change (there may be 1–4).
Step 2: Pick the single most important one as primary_category.
Step 3: List the rest as secondary_categories (can be empty).
Step 4: List ALL reasoning abilities a developer needs to understand and resolve this issue.
Step 5: For the primary category, list which abilities are most central to it.

Respond ONLY with a valid JSON object in this exact format (no markdown, no extra text):
{
  "all_aspects": ["<aspect1>", "<aspect2>"],
  "primary_category": "<most important category>",
  "secondary_categories": ["<other categories if any>"],
  "reasoning_abilities": ["<all abilities needed>"],
  "primary_abilities": ["<abilities most central to the primary category>"],
  "brief_explanation": "<2-3 sentences: what the change does, why it's categorized this way, what reasoning is hardest>"
}

Valid categories:
- "bug_fix": Fixing incorrect behavior, logic errors, crashes, or data corruption
- "security_patch": Fixing security vulnerabilities (CVE, injection, overflow, auth bypass, etc.)
- "performance_optimization": Improving speed, memory usage, or resource efficiency
- "new_feature": Adding new functionality that didn't exist before
- "api_interface_change": Changing function signatures, APIs, protocols, or data structures
- "refactoring_cleanup": Restructuring/deduplicating code without changing external behavior
- "error_handling": Improving error handling, validation, or robustness
- "dependency_integration": Updating dependencies, integrations, or third-party library usage
- "test_improvement": Adding or fixing tests
- "documentation_nl": Improving comments, documentation, or natural language descriptions

Valid reasoning abilities:
- "type_system": Type constraints, type checking, type conversions
- "control_flow": Execution paths, conditionals, loops
- "data_flow": How data is passed, transformed, or mutated
- "api_semantics": Library/framework API contracts and behavior
- "memory_management": Heap/stack, ownership, lifetimes, resource cleanup
- "concurrency": Threads, locks, races, async patterns
- "security_reasoning": Attack surfaces, trust boundaries, input validation
- "protocol_understanding": Network protocols, serialization formats, standards
- "cross_file_reasoning": Tracing logic across multiple files or modules
- "interface_contract": Invariants that callers/callees must satisfy
- "pattern_matching": Recognizing code patterns and anti-patterns
- "domain_knowledge": Domain-specific knowledge (YANG, Bluetooth, audio codecs, etc.)
"""


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


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


def call_llm(
    client: Any,
    model: str,
    *,
    system: str,
    user: str,
    stream: bool = False,
) -> str:
    completion = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        temperature=0.1,
        max_tokens=500,
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


def load_and_filter_data(data_path: Path) -> list[dict]:
    """加载 all_nl_fuzzy.json 并过滤掉 discard == true 的项。"""
    with open(data_path, encoding="utf-8") as f:
        data = json.load(f)
    return [item for item in data if not item.get("discard", False)]


def main():
    parser = argparse.ArgumentParser(
        description="用 Claude/OPUS 对 refactoring task 进行多标签分类"
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=repo_root() / "result" / "strengthen" / "v3" / "all_nl_fuzzy.json",
        help="数据源 JSON 路径（默认: result/strengthen/v3/all_nl_fuzzy.json）",
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="输出结果 JSON 路径（默认: 同目录下 categorization_results.json）",
    )
    parser.add_argument("--limit", type=int, default=None, help="只处理前 N 个 instance（用于测试）")
    parser.add_argument("--offset", type=int, default=0, help="跳过前 N 个 instance")
    parser.add_argument("--dry-run", action="store_true", help="只列将要处理的 instance，不调 API")
    args = parser.parse_args()

    data_path = args.input.resolve()
    if not data_path.is_file():
        print(f"Error: 数据文件不存在: {data_path}", file=sys.stderr)
        sys.exit(1)

    items = load_and_filter_data(data_path)
    print(f"加载 {data_path.name}: 共 {len(items)} 条（已过滤 discard=true）")

    items = items[args.offset:]
    if args.limit is not None:
        items = items[:args.limit]

    if args.dry_run:
        print(f"dry-run: 将处理 {len(items)} 个 instance")
        for item in items[:20]:
            print(f"  {item['instance_id']}")
        if len(items) > 20:
            print(f"  ... 共 {len(items)} 个")
        return

    api_key = (
        (os.getenv("OPENAI_API_KEY") or "").strip()
        or (os.getenv("CLAUDE_API_KEY") or "").strip()
        or (os.getenv("QWEN_API_KEY") or "").strip()
        or (os.getenv("API_KEY") or "").strip()
    )
    if not api_key:
        print(
            "Error: 请设置环境变量 OPENAI_API_KEY、CLAUDE_API_KEY、QWEN_API_KEY 或 API_KEY",
            file=sys.stderr,
        )
        sys.exit(1)
    client = OpenAI(api_key=api_key, base_url=API_URL)
    model = MODEL
    print(f"模型: {model}  base_url: {API_URL}")

    out_path = args.output
    if out_path is None:
        out_path = data_path.parent / "categorization_results.json"
    out_path = out_path.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    results: dict[str, Any] = {}
    if out_path.is_file():
        try:
            with open(out_path, encoding="utf-8") as f:
                results = json.load(f)
            if isinstance(results, dict):
                print(f"已加载已有结果: {len(results)} 条，将跳过并追加")
            else:
                results = {}
        except Exception:
            results = {}

    to_process = [item for item in items if item["instance_id"] not in results]
    total = len(to_process)
    print(f"待分析: {total} 个 instance，结果写入 {out_path}")

    for idx, item in enumerate(to_process, 1):
        iid = item["instance_id"]
        ps = (item.get("problem_statement") or "")[:PROBLEM_MAX_CHARS]
        patch = (item.get("patch") or "")[:PATCH_MAX_CHARS]

        user_content = (
            f"## Problem Statement\n{ps}\n\n"
            f"## Code Patch (diff)\n```diff\n{patch}\n```\n\n"
            "Analyze all aspects of this change and respond in the required JSON format."
        )

        print(f"[{idx}/{total}] {iid} ...", end=" ", flush=True)

        try:
            raw = call_llm(client, model, system=SYSTEM_PROMPT, user=user_content)
            result = extract_json_object(raw)
            results[iid] = result
            sec = result.get("secondary_categories", [])
            sec_str = f" + {', '.join(sec)}" if sec else ""
            print(f"-> {result.get('primary_category', '?')}{sec_str}")
        except Exception as e:
            results[iid] = None
            print(f"-> FAILED ({e})")

        if idx % CHECKPOINT_EVERY == 0 or idx == total:
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(results, f, ensure_ascii=False, indent=2)

        if idx < total:
            time.sleep(SLEEP)

    valid = {k: v for k, v in results.items() if v}
    print(f"\n完成! 成功: {len(valid)}/{len(results)}，结果已写入: {out_path}")


if __name__ == "__main__":
    main()
