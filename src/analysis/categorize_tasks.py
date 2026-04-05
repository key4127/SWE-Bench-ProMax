#!/usr/bin/env python3
"""
Categorize refactoring tasks in the dataset using LLM analysis.
Analyzes patches + problem statements to classify task type and required code reasoning abilities.
Supports multi-label categorization (primary + secondary) and per-category ability breakdown.
"""

import argparse
import json
import os
import sys
import time
import requests
from pathlib import Path
from collections import Counter, defaultdict

# ---- Config ----
_API_BASE = os.getenv("OPENAI_BASE_URL", "https://aihubmix.com/v1").rstrip("/")
API_URL = f"{_API_BASE}/chat/completions"
MODEL = os.getenv("OPENAI_MODEL", "claude-sonnet-4-6")

PATCH_MAX_CHARS = 3000
PROBLEM_MAX_CHARS = 1500

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


def _llm_api_key() -> str:
    return (
        (os.getenv("OPENAI_API_KEY") or "").strip()
        or (os.getenv("CLAUDE_API_KEY") or "").strip()
        or (os.getenv("QWEN_API_KEY") or "").strip()
        or (os.getenv("API_KEY") or "").strip()
    )


def call_llm(problem_statement: str, patch: str) -> dict | None:
    api_key = _llm_api_key()
    ps = problem_statement[:PROBLEM_MAX_CHARS]
    p = patch[:PATCH_MAX_CHARS]

    user_content = (
        f"## Problem Statement\n{ps}\n\n"
        f"## Code Patch (diff)\n```diff\n{p}\n```\n\n"
        "Analyze all aspects of this change and respond in the required JSON format."
    )

    for attempt in range(3):
        try:
            resp = requests.post(
                url=API_URL,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": MODEL,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": user_content},
                    ],
                    "temperature": 0.1,
                    "max_tokens": 500,
                },
                timeout=60,
            )
            resp.raise_for_status()
            content = resp.json()["choices"][0]["message"]["content"].strip()
            # Strip markdown code fences if present
            if content.startswith("```"):
                content = content.split("```")[1]
                if content.startswith("json"):
                    content = content[4:]
            # Extract first JSON object in case of extra text
            start = content.find("{")
            end = content.rfind("}") + 1
            if start != -1 and end > start:
                content = content[start:end]
            return json.loads(content)
        except Exception as e:
            wait = 2 ** attempt
            print(f"  [attempt {attempt+1}/3 failed: {e}, retrying in {wait}s]", end=" ", flush=True)
            time.sleep(wait)
    return None


def load_existing_results(output_path: str) -> dict:
    if Path(output_path).exists():
        with open(output_path) as f:
            return json.load(f)
    return {}


def save_results(results: dict, output_path: str):
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)


def print_summary(results: dict):
    valid = {k: v for k, v in results.items() if v}
    n = len(valid)
    if n == 0:
        print("No results.")
        return

    # --- Primary categories ---
    primary_counter = Counter(v["primary_category"] for v in valid.values())

    # --- All touched categories (primary + secondary combined) ---
    all_cat_counter = Counter()
    for v in valid.values():
        all_cat_counter[v["primary_category"]] += 1
        for s in v.get("secondary_categories", []):
            if s in ALL_CATEGORIES:
                all_cat_counter[s] += 1

    # --- Multi-label combos (primary + sorted secondaries) ---
    combo_counter = Counter()
    for v in valid.values():
        sec = sorted(s for s in v.get("secondary_categories", []) if s in ALL_CATEGORIES)
        key = v["primary_category"]
        if sec:
            key += " + " + " + ".join(sec)
        combo_counter[key] += 1

    # --- All reasoning abilities ---
    ability_counter = Counter()
    for v in valid.values():
        for a in v.get("reasoning_abilities", []):
            ability_counter[a] += 1

    # --- Abilities broken down by primary category ---
    cat_ability = defaultdict(Counter)
    for v in valid.values():
        cat = v["primary_category"]
        for a in v.get("primary_abilities", v.get("reasoning_abilities", [])):
            cat_ability[cat][a] += 1

    print("\n" + "=" * 65)
    print(f"TOTAL ANALYZED: {n}  (failed/skipped: {len(results) - n})")

    print("\n--- Primary Category Distribution ---")
    for cat, count in primary_counter.most_common():
        pct = count / n * 100
        print(f"  {cat:<30} {count:>3}  ({pct:5.1f}%)  {'█' * int(pct / 2.5)}")

    print("\n--- All Touched Categories (incl. secondary) ---")
    for cat, count in all_cat_counter.most_common():
        pct = count / n * 100
        print(f"  {cat:<30} {count:>3}  ({pct:5.1f}%)")

    print("\n--- Top Multi-label Combos ---")
    for combo, count in combo_counter.most_common(15):
        print(f"  {count:>3}x  {combo}")

    print("\n--- Required Reasoning Abilities (overall) ---")
    for ability, count in ability_counter.most_common():
        pct = count / n * 100
        print(f"  {ability:<30} {count:>3}  ({pct:5.1f}%)  {'█' * int(pct / 2.5)}")

    print("\n--- Top Abilities per Primary Category ---")
    for cat in primary_counter:
        top = cat_ability[cat].most_common(4)
        top_str = ", ".join(f"{a}({c})" for a, c in top)
        print(f"  {cat:<30} → {top_str}")

    print("=" * 65)


def main(data_path: str, output_path: str):
    if not _llm_api_key():
        print(
            "Error: 请设置环境变量 OPENAI_API_KEY、CLAUDE_API_KEY、QWEN_API_KEY 或 API_KEY",
            file=sys.stderr,
        )
        sys.exit(1)
    print(f"Loading dataset from {data_path}")
    with open(data_path) as f:
        data = json.load(f)
    print(f"Total items: {len(data)}")

    results = load_existing_results(output_path)
    if results:
        print(f"Resuming: {len(results)} items already processed.")

    to_process = [item for item in data if item["instance_id"] not in results]
    print(f"Items to process: {len(to_process)}")

    for i, item in enumerate(to_process):
        iid = item["instance_id"]
        print(f"[{i+1}/{len(to_process)}] {iid} ...", end=" ", flush=True)

        result = call_llm(
            problem_statement=item.get("problem_statement", ""),
            patch=item.get("patch", ""),
        )

        if result:
            results[iid] = result
            sec = result.get("secondary_categories", [])
            sec_str = f" + {', '.join(sec)}" if sec else ""
            print(f"-> {result.get('primary_category', '?')}{sec_str}")
        else:
            results[iid] = None
            print("-> FAILED")

        save_results(results, output_path)

        if i < len(to_process) - 1:
            time.sleep(0.5)

    print(f"\nDone! Results saved to {output_path}")
    print_summary(results)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="用 LLM 对数据集做任务分类")
    ap.add_argument(
        "--input",
        default="all_mkd.json",
        help="输入数据集 JSON 路径",
    )
    ap.add_argument(
        "--output",
        default="categorization_results.json",
        help="分类结果 JSON 路径（可断点续跑）",
    )
    args = ap.parse_args()
    main(args.input, args.output)
