#!/usr/bin/env python3
"""对 harness 未通过且 v3 未 discard 的实例，用 Claude Opus（OpenAI 兼容）结合 traj 分析失败原因。"""

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

FUZZY_REL = "result/strengthen/v3/all_nl_fuzzy.json"
HARNESS_REL = "result/harness_result/strengthen/v2/kimi.json"
TRAJ_DIR_REL = "result/preds_result/strengthen/v2/kimi"
DEFAULT_OUT_REL = "result/strengthen/v3/kimi_fail_traj_opus_analysis.jsonl"

HTTP_REQUEST_TIMEOUT_SEC = 900.0
SLEEP_SEC = 0.5

SYSTEM_PROMPT = """\
你是软件修复评测（coding-agent benchmark）的分析助手。你会看到：
- 该实例在 v3 模糊化后的题目描述（problem_statement）与测试补丁摘要；
- harness 上 Kimi 代理提交的补丁与评测输出摘要；
- 代理与环境交互的轨迹（对话与命令输出，可能被截断）。

请**只根据给定材料**推断：该实例为何未通过 harness（例如：补丁逻辑错误、未覆盖需求、构建/测试失败、理解偏差、过早提交等）。
输出要求：
1. 用中文简明写出「失败原因分析」（可分点，但不要编造材料中未出现的具体文件名/行号，除非轨迹里明确出现）。
2. 若信息不足以判断，说明缺什么信息，并给出最可能的 1～2 种假设。
不要输出寒暄，不要重复整段轨迹。
"""


def load_json(path: Path) -> list | dict:
    if not path.exists():
        print(f"Error: 文件不存在: {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def build_fuzzy_index(data: list) -> dict[str, dict]:
    return {item["instance_id"]: item for item in data if item.get("instance_id")}


def harness_index(data: list) -> dict[str, dict]:
    return {item["instance_id"]: item for item in data if item.get("instance_id")}


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


def truncate(s: str, max_chars: int) -> str:
    if not s or len(s) <= max_chars:
        return s or ""
    half = max(1000, max_chars // 2 - 40)
    return s[:half] + "\n\n... [truncated middle] ...\n\n" + s[-half:]


def format_messages_for_prompt(messages: list, *, max_messages: int, per_msg_cap: int) -> str:
    if not messages:
        return "(no messages)"
    tail = messages[-max_messages:]
    lines: list[str] = []
    for i, m in enumerate(tail, 1):
        if not isinstance(m, dict):
            continue
        role = m.get("role", "?")
        content = m.get("content")
        if content is None:
            content = ""
        elif not isinstance(content, str):
            content = json.dumps(content, ensure_ascii=False)
        lines.append(f"--- [{i}] role={role} ---\n{truncate(content, per_msg_cap)}")
    omitted = len(messages) - len(tail)
    header = f"(共 {len(messages)} 条消息，展示最后 {len(tail)} 条"
    if omitted > 0:
        header += f"，省略前 {omitted} 条"
    header += ")\n"
    return header + "\n\n".join(lines)


def traj_to_prompt_block(traj: dict, *, max_total_chars: int) -> str:
    parts: list[str] = []
    info = traj.get("info") or {}
    parts.append(f"exit_status: {info.get('exit_status')!r}")
    sub = info.get("submission") or ""
    if sub:
        parts.append("agent_submission_patch:\n" + truncate(sub, min(12000, max_total_chars // 4)))
    msgs = traj.get("messages") or []
    head = "\n\n".join(parts)
    budget = max(5000, max_total_chars - len(head) - 32)
    block = ""
    # 动态压缩：先少取消息、短截断，再放宽直到塞进 budget
    for max_msg, cap in ((24, 6000), (40, 10000), (60, 12000)):
        block = format_messages_for_prompt(msgs, max_messages=max_msg, per_msg_cap=cap)
        if len(block) <= budget:
            break
    else:
        block = truncate(block, budget)
    parts.append("trajectory_messages:\n" + block)
    text = "\n\n".join(parts)
    if len(text) > max_total_chars:
        text = truncate(text, max_total_chars)
    return text


def harness_model_summary(hrow: dict, *, max_stdout: int, max_stderr: int) -> str:
    m = hrow.get("model") or {}
    if not isinstance(m, dict):
        return "(no model details)"
    lines = [
        f"final_result: {m.get('final_result')!r}",
        f"raw_reason: {m.get('raw_reason')!r}",
        f"parse_reason: {m.get('parse_reason')!r}",
    ]
    so = m.get("stdout") or ""
    se = m.get("stderr") or ""
    if so:
        lines.append("stdout (truncated):\n" + truncate(so, max_stdout))
    if se:
        lines.append("stderr (truncated):\n" + truncate(se, max_stderr))
    return "\n\n".join(lines)


def build_user_content(
    fuzzy_item: dict,
    hrow: dict,
    traj: dict,
    *,
    traj_budget: int,
) -> str:
    ps = fuzzy_item.get("problem_statement") or ""
    tp = fuzzy_item.get("test_patch") or ""
    user = f"""## instance_id
{fuzzy_item.get("instance_id")}

## problem_statement (v3 fuzzy)
{truncate(ps, 24000)}

## test_patch (truncated)
{truncate(tp, 12000)}

## harness 结果（Kimi 代理侧）
passed: {hrow.get("passed")}

{harness_model_summary(hrow, max_stdout=16000, max_stderr=12000)}

## 代理轨迹（可能截断）
{traj_to_prompt_block(traj, max_total_chars=traj_budget)}
"""
    return user


def iter_candidates(
    fuzzy_list: list,
    harness_list: list,
) -> list[str]:
    fuzzy_ids = {
        item["instance_id"]
        for item in fuzzy_list
        if item.get("instance_id") and item.get("discard") is not True
    }
    failed: list[str] = []
    for item in harness_list:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if not iid:
            continue
        if item.get("passed") is True:
            continue
        if iid in fuzzy_ids:
            failed.append(iid)
    return sorted(set(failed))


def load_done_instance_ids_jsonl(path: Path) -> set[str]:
    """从 jsonl（每行一个 JSON）中提取已处理 instance_id。"""
    if not path.exists():
        return set()
    done: set[str] = set()
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(obj, dict):
                iid = obj.get("instance_id")
                if iid:
                    done.add(str(iid))
    return done


def main() -> None:
    parser = argparse.ArgumentParser(
        description="用 Opus 分析 Kimi traj：仅 all_nl_fuzzy 非 discard 且 harness 未通过",
    )
    parser.add_argument("--limit", type=int, default=5, help="最多分析多少条（默认 5）")
    parser.add_argument(
        "--traj-budget-chars",
        type=int,
        default=100_000,
        help="单条轨迹写入 prompt 的最大字符数（默认 100000）",
    )
    parser.add_argument("--dry-run", action="store_true", help="只列出将处理的 instance_id，不调用 API")
    parser.add_argument("--stream", action="store_true", default=True)
    parser.add_argument("--no-stream", dest="stream", action="store_false")
    parser.add_argument("--output", type=str, default=None, help=f"追加写入的 jsonl（默认 {DEFAULT_OUT_REL}）")
    parser.add_argument("--instance-id", type=str, default=None, help="只处理该 instance_id（须满足筛选条件）")
    args = parser.parse_args()

    base = Path(__file__).resolve().parents[3]
    fuzzy_path = base / FUZZY_REL
    harness_path = base / HARNESS_REL
    traj_root = base / TRAJ_DIR_REL
    out_path = base / (args.output or DEFAULT_OUT_REL)
    done_ids = load_done_instance_ids_jsonl(out_path)

    fuzzy_list = load_json(fuzzy_path)
    harness_list = load_json(harness_path)
    if not isinstance(fuzzy_list, list) or not isinstance(harness_list, list):
        print("Error: fuzzy 与 harness 应为 JSON 数组", file=sys.stderr)
        sys.exit(1)

    fuzzy_map = build_fuzzy_index(fuzzy_list)
    harness_map = harness_index(harness_list)

    candidates = iter_candidates(fuzzy_list, harness_list)
    if args.instance_id:
        iid = args.instance_id.strip()
        if iid not in candidates:
            print(
                f"Error: {iid} 不在候选集中（需：fuzzy 无 discard、且 harness passed=false）",
                file=sys.stderr,
            )
            sys.exit(1)
        if iid in done_ids:
            print(f"{iid} -> 跳过：{out_path} 已有输出")
            return
        to_run = [iid]
    else:
        skipped_existing = sum(1 for iid in candidates if iid in done_ids)
        to_run = [iid for iid in candidates if iid not in done_ids][: args.limit]

    print(f"候选总数（非 discard ∩ harness 未通过）: {len(candidates)}")
    if not args.instance_id:
        print(f"已有输出将跳过: {skipped_existing} 条")
    print(f"本轮将处理: {len(to_run)} 条")

    if args.dry_run:
        for iid in to_run:
            print(iid)
        return

    base_url, api_key, model = resolve_api_config()
    if not api_key:
        print("Error: 未配置 API Key", file=sys.stderr)
        sys.exit(1)

    from openai import OpenAI

    client = OpenAI(
        api_key=api_key,
        base_url=base_url,
        timeout=HTTP_REQUEST_TIMEOUT_SEC,
    )

    out_path.parent.mkdir(parents=True, exist_ok=True)

    for idx, iid in enumerate(to_run, 1):
        traj_path = traj_root / iid / f"{iid}.traj.json"
        if not traj_path.is_file():
            print(f"[{idx}/{len(to_run)}] {iid} -> 跳过：无轨迹文件 {traj_path}", file=sys.stderr)
            rec = {
                "instance_id": iid,
                "error": "traj_missing",
                "traj_path": str(traj_path.relative_to(base)),
            }
            with open(out_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
            continue

        with open(traj_path, "r", encoding="utf-8") as f:
            traj = json.load(f)

        fuzzy_item = fuzzy_map[iid]
        hrow = harness_map.get(iid) or {}

        user_content = build_user_content(
            fuzzy_item,
            hrow,
            traj,
            traj_budget=args.traj_budget_chars,
        )
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ]

        try:
            analysis = call_llm(client, model, messages, stream=args.stream)
        except Exception as e:
            print(f"[{idx}/{len(to_run)}] {iid} API 失败: {e}", file=sys.stderr)
            analysis = ""
            err = str(e)
        else:
            err = ""

        rec = {
            "instance_id": iid,
            "model": model,
            "analysis": analysis,
            "traj_path": str(traj_path.relative_to(base)),
            "harness_passed": hrow.get("passed"),
        }
        if err:
            rec["api_error"] = err

        with open(out_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")

        print(f"[{idx}/{len(to_run)}] {iid} -> 已写入 {out_path.name}")
        if SLEEP_SEC > 0:
            time.sleep(SLEEP_SEC)

    print(f"完成，结果追加写入: {out_path}")


if __name__ == "__main__":
    main()
