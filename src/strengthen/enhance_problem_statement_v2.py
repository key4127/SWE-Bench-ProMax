#!/usr/bin/env python3
"""
对 result/strengthen/v1/all_nl.json 中的 problem_statement 做增强。
结合 judge_result.json、explain_over_narrow_result.json、judge_fail_only_result.json 的判定结果，
针对三类问题分别采用不同增强策略：
  - 过宽用例：让描述和 test_patch 对齐，去除无关内容或补充描述不到位的部分
  - 过窄测试：在描述中补充测试硬编码的信息（精确字符串、API 名等），让模型拿到正确解决问题的必要条件
  - 描述不清：根据 patch / test_patch 重新生成清晰的描述

用法:
  export OPENAI_API_KEY='sk-xxx'          # 或 QWEN_API_KEY / API_KEY
  # 可选: export OPENAI_BASE_URL='...'  export OPENAI_MODEL='...'
  python enhance_problem_statement_v2.py [--dry-run]
"""

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

# ── 路径配置 ──────────────────────────────────────────────
INPUT_REL = "result/strengthen/v1/all_nl.json"
OUTPUT_DIR_REL = "result/strengthen/v2"
OUTPUT_NAME = "all_nl_enhanced.json"
JUDGE_RESULT_REL = "src/test/patch/judge_result.json"
JUDGE_FAIL_ONLY_REL = "src/test/patch/judge_fail_only_result.json"
EXPLAIN_OVER_NARROW_REL = "src/test/patch/explain_over_narrow_result.json"

SLEEP = 0.5
CHECKPOINT_EVERY = 5

# ── 增强类型 ──────────────────────────────────────────────
ENHANCE_OVER_WIDE = "over_wide"
ENHANCE_OVER_NARROW = "over_narrow"
ENHANCE_BOTH_WIDE_NARROW = "both_wide_narrow"
ENHANCE_UNCLEAR = "unclear_description"
ENHANCE_SKIP = "skip"

# ── System Prompts ────────────────────────────────────────

OVER_WIDE_SYSTEM_PROMPT = """\
You are a technical writer specializing in precise software issue descriptions.

Context — "over-wide test":
The test patch verifies behaviors that the current problem statement does NOT mention. \
In other words, the test is WIDER than the description — some things the test checks are \
missing from the description. The description needs to be EXPANDED so it covers everything \
the test actually validates.

You are given:
1. The current problem statement (which is incomplete — it does not cover all behaviors \
   the test patch checks)
2. The test patch (the ground truth of what the fix must satisfy)
3. The golden patch (the actual code fix, for reference)
4. The "over-wide reason" explaining exactly what the test covers but the description misses

Your task: Rewrite the problem statement so it ALIGNS with the test patch. Specifically:
- KEEP everything in the current description that is relevant to the test.
- ADD the missing aspects that the test covers but the description omits \
  (as identified in the over-wide reason).
- Do NOT introduce genuinely irrelevant content — only add what the test actually verifies.
- Do NOT reveal the specific implementation of the fix or reference line numbers / diff hunks.
- Keep technical accuracy: describe expected behaviors, error conditions, or interfaces \
  that the test validates.
- Additionally, the description itself may be unclear or poorly structured \
  (if a "Description Quality Issue" section is provided). In that case, also fix the \
  clarity and structure while performing the alignment.
- Use a professional, narrative style (no markdown headers, no bullet points). \
  Write as if authoring a thorough GitHub issue.
- Output ONLY the rewritten problem statement text.
"""

OVER_NARROW_SYSTEM_PROMPT = """\
You are a technical writer specializing in precise software issue descriptions.

Context — "over-narrow test":
The test patch hardcodes specific values — exact strings, error codes, API names, class names, \
enum values, etc. A correct fix MUST produce exactly these values to pass the test, but the \
current problem statement does not mention them. Without this information, a developer could \
write a functionally correct fix that still fails the test because it uses different wording, \
naming, or return codes.

You are given:
1. The current problem statement
2. A list of "over-narrow findings" — each one describes a specific hardcoded constraint \
   in the test (category, file, symbol, and what exactly is hardcoded)
3. The test patch and golden patch for reference

Your task: Enhance the problem statement by naturally incorporating the hardcoded constraints \
so a developer has ALL the information needed to produce a test-passing fix:
- For each hardcoded constraint, weave it into the narrative. \
  Example: if the test expects error message "Missing date-and-time fractions after '.'.", \
  the description should state that this exact error wording is required.
- Do NOT dump constraints as a raw list. Integrate them naturally into the narrative flow.
- KEEP all existing correct information from the current description.
- Do NOT reveal the specific implementation of the fix.
- Additionally, the description itself may be unclear or poorly structured \
  (if a "Description Quality Issue" section is provided). In that case, also fix the \
  clarity and structure while incorporating the constraints.
- Use a professional, narrative style (no markdown headers, no bullet points).
- Output ONLY the enhanced problem statement text.
"""

BOTH_WIDE_NARROW_SYSTEM_PROMPT = """\
You are a technical writer specializing in precise software issue descriptions.

Context — the test has BOTH "over-wide" and "over-narrow" issues relative to the description:
1. Over-wide: The test covers behaviors the description does NOT mention. \
   The description must be EXPANDED to cover those missing aspects.
2. Over-narrow: The test hardcodes specific values (exact strings, error codes, API names, etc.) \
   that the description does not mention. These must be added so the developer knows the \
   exact constraints a correct fix must satisfy.

You are given:
1. The current problem statement (incomplete AND lacking hardcoded constraint details)
2. The test patch and golden patch
3. The "over-wide reason" (what the test covers but the description misses)
4. A list of "over-narrow findings" (hardcoded values/strings the test expects)

Your task: Rewrite the problem statement to:
(a) EXPAND the description to cover all behaviors the test verifies (fix the over-wide gap)
(b) Incorporate the hardcoded constraints so a developer has all necessary details \
    (fix the over-narrow gap)

Follow these rules:
- KEEP existing correct content. ADD missing coverage and hardcoded details.
- Do NOT introduce genuinely irrelevant content.
- Weave hardcoded constraints naturally into the narrative.
- Do NOT reveal the specific implementation of the fix.
- Additionally, the description itself may be unclear or poorly structured \
  (if a "Description Quality Issue" section is provided). In that case, also fix the \
  clarity and structure while performing the expansion.
- Use a professional, narrative style (no markdown headers, no bullet points).
- Output ONLY the rewritten problem statement text.
"""

UNCLEAR_SYSTEM_PROMPT = """\
You are a technical writer specializing in precise software issue descriptions.

Context — the current problem statement is unclear, incomplete, or poorly structured. \
It does not serve as a useful guide for a developer trying to understand and fix the issue.

You are given:
1. The current problem statement (unclear or unreasonable)
2. The test patch (defines what the fix must satisfy)
3. The golden patch (the actual code fix)
4. The reason why the description is considered unreasonable or unclear

Your task: Rewrite the problem statement from scratch to create a clear, accurate description:
- Clearly explain the context of where and when the issue occurs.
- Describe the discrepancy between expected and actual behavior.
- Ensure the description contains sufficient information for a developer to understand \
  what needs to be fixed AND what the test expects.
- Do NOT reveal the specific implementation of the fix.
- Use a professional, narrative style (no markdown headers, no bullet points). \
  Write as if authoring a clear GitHub issue.
- Output ONLY the rewritten problem statement text.
"""

# ── User Prompt 模板 ──────────────────────────────────────

OVER_WIDE_USER_TPL = """\
## Current Problem Statement
{problem_statement}

## Test Patch
{test_patch}

## Golden Patch
{patch}

## Over-Wide Reason
{over_wide_reason}
"""

OVER_NARROW_USER_TPL = """\
## Current Problem Statement
{problem_statement}

## Over-Narrow Findings (hardcoded constraints in the test)
{over_narrow_findings}

## Test Patch
{test_patch}

## Golden Patch
{patch}
"""

BOTH_WIDE_NARROW_USER_TPL = """\
## Current Problem Statement
{problem_statement}

## Over-Wide Reason
{over_wide_reason}

## Over-Narrow Findings (hardcoded constraints in the test)
{over_narrow_findings}

## Test Patch
{test_patch}

## Golden Patch
{patch}
"""

UNCLEAR_USER_TPL = """\
## Current Problem Statement
{problem_statement}

## Reason Description Is Unreasonable
{unreasonable_reason}

## Test Patch
{test_patch}

## Golden Patch
{patch}
"""


def load_json(path: Path) -> list:
    if not path.exists():
        print(f"Warning: 文件不存在: {path}", file=sys.stderr)
        return []
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build_index(data: list, key: str = "instance_id") -> dict:
    return {item[key]: item for item in data if key in item}


def format_over_narrow_findings(findings: list) -> str:
    if not findings:
        return "(none)"
    lines = []
    for i, f in enumerate(findings, 1):
        lines.append(
            f"{i}. [{f.get('category', 'unknown')}] "
            f"File: {f.get('file', '?')}, "
            f"Symbol: \"{f.get('symbol', '?')}\"\n"
            f"   Constraint: {f.get('constraint', '?')}"
        )
    return "\n".join(lines)


def determine_enhance_type(
    instance_id: str,
    judge_map: dict,
    fail_only_map: dict,
) -> tuple[str, dict]:
    """返回 (enhance_type, merged_judge_info)。
    跳过条件：模型已通过的案例 或 过宽/过窄/描述不清均不存在。"""
    judge = judge_map.get(instance_id, {})
    fail_only = fail_only_map.get(instance_id, {})

    test_passed = judge.get("test_passed", fail_only.get("test_passed"))

    over_wide = judge.get("over_wide_test", False)
    over_narrow = (
        fail_only.get("over_narrow_test")
        if instance_id in fail_only_map
        else judge.get("over_narrow_test", False)
    )
    desc_reasonable = (
        fail_only.get("problem_description_reasonable")
        if instance_id in fail_only_map
        else judge.get("problem_description_reasonable", True)
    )

    merged = {
        "over_wide_test": over_wide,
        "over_wide_reason": judge.get("over_wide_reason", ""),
        "over_narrow_test": over_narrow,
        "over_narrow_reason": (
            fail_only.get("over_narrow_reason", "")
            or judge.get("over_narrow_reason", "")
        ),
        "problem_description_reasonable": desc_reasonable,
        "problem_description_reason": (
            fail_only.get("problem_description_reason", "")
            or judge.get("problem_description_reason", "")
        ),
        "test_passed": test_passed,
    }

    if test_passed:
        return ENHANCE_SKIP, merged

    if over_wide and over_narrow:
        return ENHANCE_BOTH_WIDE_NARROW, merged
    if over_wide:
        return ENHANCE_OVER_WIDE, merged
    if over_narrow:
        return ENHANCE_OVER_NARROW, merged
    if not desc_reasonable:
        return ENHANCE_UNCLEAR, merged
    return ENHANCE_SKIP, merged


UNCLEAR_ADDON_TPL = """
## Description Quality Issue
The current description is also considered unclear or unreasonable for the following reason:
{unreasonable_reason}
Please also address this clarity issue in your rewrite.
"""


def build_messages(
    enhance_type: str,
    item: dict,
    judge_info: dict,
    narrow_findings: list,
) -> list[dict]:
    ps = item.get("problem_statement", "")
    tp = item.get("test_patch", "")
    p = item.get("patch", "")
    desc_reasonable = judge_info.get("problem_description_reasonable", True)
    desc_reason = judge_info.get("problem_description_reason", "")

    unclear_addon = ""
    if not desc_reasonable and enhance_type != ENHANCE_UNCLEAR:
        unclear_addon = UNCLEAR_ADDON_TPL.format(unreasonable_reason=desc_reason)

    if enhance_type == ENHANCE_OVER_WIDE:
        return [
            {"role": "system", "content": OVER_WIDE_SYSTEM_PROMPT},
            {"role": "user", "content": OVER_WIDE_USER_TPL.format(
                problem_statement=ps,
                test_patch=tp,
                patch=p,
                over_wide_reason=judge_info.get("over_wide_reason", ""),
            ) + unclear_addon},
        ]

    if enhance_type == ENHANCE_OVER_NARROW:
        return [
            {"role": "system", "content": OVER_NARROW_SYSTEM_PROMPT},
            {"role": "user", "content": OVER_NARROW_USER_TPL.format(
                problem_statement=ps,
                over_narrow_findings=format_over_narrow_findings(narrow_findings),
                test_patch=tp,
                patch=p,
            ) + unclear_addon},
        ]

    if enhance_type == ENHANCE_BOTH_WIDE_NARROW:
        return [
            {"role": "system", "content": BOTH_WIDE_NARROW_SYSTEM_PROMPT},
            {"role": "user", "content": BOTH_WIDE_NARROW_USER_TPL.format(
                problem_statement=ps,
                over_wide_reason=judge_info.get("over_wide_reason", ""),
                over_narrow_findings=format_over_narrow_findings(narrow_findings),
                test_patch=tp,
                patch=p,
            ) + unclear_addon},
        ]

    if enhance_type == ENHANCE_UNCLEAR:
        return [
            {"role": "system", "content": UNCLEAR_SYSTEM_PROMPT},
            {"role": "user", "content": UNCLEAR_USER_TPL.format(
                problem_statement=ps,
                unreasonable_reason=desc_reason,
                test_patch=tp,
                patch=p,
            )},
        ]

    return []


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


def main():
    parser = argparse.ArgumentParser(description="增强 problem_statement")
    parser.add_argument("--dry-run", action="store_true", help="只分析不调用 LLM")
    parser.add_argument("--limit", type=int, default=None, help="只增强前 N 条（用于测试）")
    parser.add_argument("--output", type=str, default=None, help="输出文件名")
    parser.add_argument("--stream", action="store_true", default=True, help="使用流式调用")
    parser.add_argument("--no-stream", dest="stream", action="store_false")
    args = parser.parse_args()

    base = Path(__file__).resolve().parents[3]

    data = load_json(base / INPUT_REL)
    judge_data = load_json(base / JUDGE_RESULT_REL)
    fail_only_data = load_json(base / JUDGE_FAIL_ONLY_REL)
    narrow_data = load_json(base / EXPLAIN_OVER_NARROW_REL)

    if not data:
        print("Error: 输入数据为空", file=sys.stderr)
        sys.exit(1)

    judge_map = build_index(judge_data)
    fail_only_map = build_index(fail_only_data)
    narrow_map = build_index(narrow_data)

    # 统计各类型数量
    type_counts = {
        ENHANCE_OVER_WIDE: 0,
        ENHANCE_OVER_NARROW: 0,
        ENHANCE_BOTH_WIDE_NARROW: 0,
        ENHANCE_UNCLEAR: 0,
        ENHANCE_SKIP: 0,
    }
    enhance_plan = []
    for item in data:
        iid = item.get("instance_id", "")
        etype, info = determine_enhance_type(iid, judge_map, fail_only_map)
        narrow_findings = narrow_map.get(iid, {}).get("over_narrow_findings", [])
        enhance_plan.append((etype, info, narrow_findings))
        type_counts[etype] += 1

    print("=== 增强计划统计 ===")
    for t, c in type_counts.items():
        print(f"  {t}: {c}")
    print(f"  总计: {len(data)}, 需增强: {len(data) - type_counts[ENHANCE_SKIP]}")

    if args.dry_run:
        limit = args.limit
        shown = 0
        print("\n=== Dry-run 模式，以下为需增强的实例 ===")
        for i, (item, (etype, info, _)) in enumerate(zip(data, enhance_plan)):
            if etype == ENHANCE_SKIP:
                continue
            if limit is not None and shown >= limit:
                break
            print(f"  [{i+1}] {item.get('instance_id')} -> {etype}")
            if info.get("over_wide_reason"):
                print(f"       过宽原因: {info['over_wide_reason'][:80]}...")
            if info.get("over_narrow_reason"):
                print(f"       过窄原因: {info['over_narrow_reason'][:80]}...")
            if not info.get("problem_description_reasonable"):
                print(f"       描述问题: {info.get('problem_description_reason', '')[:80]}...")
            shown += 1
        if limit is not None:
            print(f"\n  (--limit {limit}, 仅展示前 {shown} 条)")
        return

    from openai import OpenAI

    base_url = "https://aihubmix.com/v1"
    api_key = os.getenv("CLAUDE_API_KEY").strip()
    model = "claude-opus-4-6-think"

    if not api_key:
        print(
            "Error: 未设置 API Key。请设置环境变量 OPENAI_API_KEY、QWEN_API_KEY 或 API_KEY。",
            file=sys.stderr,
        )
        sys.exit(1)

    client = OpenAI(api_key=api_key, base_url=base_url)
    out_dir = base / OUTPUT_DIR_REL
    out_dir.mkdir(parents=True, exist_ok=True)
    out_name = args.output or OUTPUT_NAME
    out_path = out_dir / out_name

    # 加载已有 checkpoint（如有）
    done_ids = set()
    if out_path.exists():
        existing = load_json(out_path)
        if existing:
            done_ids = {
                item.get("instance_id")
                for item in existing
                if item.get("_enhanced")
            }
            if done_ids:
                print(f"发现已有 checkpoint，{len(done_ids)} 条已增强，将跳过")
                existing_map = build_index(existing)
                for i, item in enumerate(data):
                    iid = item.get("instance_id", "")
                    if iid in done_ids and iid in existing_map:
                        data[i] = existing_map[iid]

    total = len(data)
    enhanced_count = 0
    limit = args.limit

    if limit is not None:
        print(f">>> 测试模式: 只增强前 {limit} 条需增强的实例")

    for i, (item, (etype, info, narrow_findings)) in enumerate(zip(data, enhance_plan)):
        iid = item.get("instance_id", "")

        if etype == ENHANCE_SKIP:
            reason = "测试已通过" if info.get("test_passed") else "无过宽/过窄/描述不清"
            print(f"[{i+1}/{total}] {iid} -> skip ({reason})")
            continue

        if iid in done_ids:
            print(f"[{i+1}/{total}] {iid} -> skip (checkpoint 已增强)")
            continue

        if limit is not None and enhanced_count >= limit:
            print(f"[{i+1}/{total}] {iid} -> skip (已达 --limit {limit})")
            continue

        messages = build_messages(etype, item, info, narrow_findings)
        if not messages:
            continue

        try:
            enhanced = call_llm(client, model, messages, stream=args.stream)
            if enhanced:
                item["problem_statement"] = enhanced
                item["_enhanced"] = True
                item["_enhance_type"] = etype
                enhanced_count += 1
            print(f"[{i+1}/{total}] {iid} -> {etype} ✓")
        except Exception as e:
            print(f"[{i+1}/{total}] {iid} -> {etype} FAILED: {e}", file=sys.stderr)

        if SLEEP > 0:
            time.sleep(SLEEP)

        if (enhanced_count) % CHECKPOINT_EVERY == 0 and enhanced_count > 0:
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"--- Checkpoint: 已保存 {out_path} ({enhanced_count} enhanced) ---")

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"\n完成: 共 {total} 条，增强 {enhanced_count} 条 -> {out_path}")


if __name__ == "__main__":
    main()
