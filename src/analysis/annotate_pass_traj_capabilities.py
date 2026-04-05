#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

DEFAULT_HARNESS_REL = "result/harness_result/strengthen/v3/kimi.json"
DEFAULT_FUZZY_REL = "result/strengthen/v3/all_nl_fuzzy.json"
DEFAULT_TRAJ_ROOT_REL = "result/preds_result/strengthen/v3/kimi-nlf"
DEFAULT_OUT_DIR_REL = "result/strengthen/v3/kimi_pass_traj_capabilities"
HTTP_REQUEST_TIMEOUT_SEC = 900.0

THOUGHT_SYSTEM_PROMPT = """输入**只有 assistant**（index 与原始轨迹一致）。不要包含 user。
每条一项：index、role、thought_zh。概括模型本步意图（THOUGHT/正文）。
一句中文，不要分点、换行、前缀。
输出 {"steps":[...]} 纯 JSON，无 Markdown。"""

ACTION_SYSTEM_PROMPT = """输入**只有 user**（index 与原始轨迹一致）。不要包含 assistant。
每条一项：index、role、action。概括环境/shell 返回；尽量写具体命令、路径、错误片段。
一句中文，不要分点、换行、前缀。
输出 {"steps":[...]} 纯 JSON，无 Markdown。"""


def repo_root_from_here() -> Path:
    return Path(__file__).resolve().parents[3]


def load_json(path: Path) -> Any:
    with open(path, encoding="utf-8") as f:
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


def truncate(s: str, max_chars: int) -> str:
    if not s:
        return ""
    if len(s) <= max_chars:
        return s
    half = max(500, max_chars // 2 - 20)
    return s[:half] + "\n...[truncated]...\n" + s[-half:]


def _is_task_prompt_user(content: str) -> bool:
    return "<pr_description>" in content or "<instructions>" in content


def build_message_blocks(
    messages: list[dict[str, Any]],
    *,
    per_msg_cap: int,
) -> list[tuple[int, str, str]]:
    out: list[tuple[int, str, str]] = []
    first_non_system = True
    for i, m in enumerate(messages):
        if not isinstance(m, dict):
            continue
        role = str(m.get("role") or "?").strip()
        if role.lower() == "system":
            continue
        raw = m.get("content")
        if raw is None:
            raw_s = ""
        elif isinstance(raw, str):
            raw_s = raw
        else:
            raw_s = json.dumps(raw, ensure_ascii=False)
        if first_non_system:
            first_non_system = False
            if role.lower() == "user" and _is_task_prompt_user(raw_s):
                continue
        out.append((i, role, truncate(raw_s, per_msg_cap)))
    return out


def chunk_blocks_by_budget(
    blocks: list[tuple[int, str, str]],
    *,
    max_chars: int,
    header_reserve: int = 4000,
) -> list[list[tuple[int, str, str]]]:
    if not blocks:
        return []
    chunks: list[list[tuple[int, str, str]]] = []
    cur: list[tuple[int, str, str]] = []
    size = header_reserve
    for b in blocks:
        line_len = len(f"[{b[0]}] role={b[1]}\n{b[2]}\n\n")
        if cur and size + line_len > max_chars:
            chunks.append(cur)
            cur = []
            size = header_reserve
        cur.append(b)
        size += line_len
    if cur:
        chunks.append(cur)
    return chunks


def build_chunk_user_text(blocks: list[tuple[int, str, str]], instance_id: str) -> str:
    lines = [f"instance_id: {instance_id}", ""]
    for idx, role, content in blocks:
        lines.append(f"[{idx}] role={role}")
        lines.append(content)
        lines.append("")
    return "\n".join(lines)


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
        messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
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


def analyze_traj_one(
    instance_id: str,
    traj: dict[str, Any],
    *,
    client: Any,
    model: str,
    per_msg_cap: int,
    chunk_budget_chars: int,
    stream: bool,
) -> dict[str, Any]:
    messages = traj.get("messages") or []
    blocks = build_message_blocks(messages, per_msg_cap=per_msg_cap)
    if not blocks:
        return {
            "instance_id": instance_id,
            "error": "no_user_assistant_messages",
            "steps": [],
        }

    assistant_blocks = [b for b in blocks if b[1].strip().lower() == "assistant"]
    user_blocks = [b for b in blocks if b[1].strip().lower() == "user"]
    by_idx: dict[int, dict[str, Any]] = {}

    t_chunks = chunk_blocks_by_budget(assistant_blocks, max_chars=chunk_budget_chars)
    for ci, ch in enumerate(t_chunks):
        text = build_chunk_user_text(ch, instance_id)
        if len(t_chunks) > 1:
            text += f"\n\n（thought 分段 {ci + 1}/{len(t_chunks)}）"
        raw = call_llm(client, model, system=THOUGHT_SYSTEM_PROMPT, user=text, stream=stream)
        obj = extract_json_object(raw)
        want = {b[0] for b in ch}
        for item in obj.get("steps") or []:
            if not isinstance(item, dict):
                continue
            try:
                ix = int(item.get("index", -1))
            except (TypeError, ValueError):
                continue
            if ix not in want:
                continue
            by_idx[ix] = {
                "index": ix,
                "role": str(item.get("role") or "assistant"),
                "thought_zh": item.get("thought_zh") or "",
            }
        time.sleep(0.2)

    a_chunks = chunk_blocks_by_budget(user_blocks, max_chars=chunk_budget_chars)
    for ci, ch in enumerate(a_chunks):
        text = build_chunk_user_text(ch, instance_id)
        if len(a_chunks) > 1:
            text += f"\n\n（action 分段 {ci + 1}/{len(a_chunks)}）"
        raw = call_llm(client, model, system=ACTION_SYSTEM_PROMPT, user=text, stream=stream)
        obj = extract_json_object(raw)
        want = {b[0] for b in ch}
        for item in obj.get("steps") or []:
            if not isinstance(item, dict):
                continue
            try:
                ix = int(item.get("index", -1))
            except (TypeError, ValueError):
                continue
            if ix not in want:
                continue
            by_idx[ix] = {
                "index": ix,
                "role": str(item.get("role") or "user"),
                "action": str(item.get("action") or item.get("action_zh") or ""),
            }
        time.sleep(0.2)

    ordered = [by_idx[i] for i in sorted(by_idx.keys())]
    return {"instance_id": instance_id, "steps": ordered}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--harness", type=str, default=None)
    parser.add_argument("--fuzzy", type=str, default=None)
    parser.add_argument("--traj-root", type=str, default=None)
    parser.add_argument("--out-dir", type=str, default=None)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--instance-id", action="append", default=None)
    parser.add_argument("--per-msg-cap", type=int, default=12000)
    parser.add_argument("--chunk-budget-chars", type=int, default=100_000)
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--stream", action="store_true")
    parser.add_argument(
        "--fuzzy-not-passed",
        action="store_true",
        help="处理 fuzzy 中 discard 非 true 且 harness 未通过（passed 非 true）的实例；默认仅处理 harness 通过 ∩ fuzzy 非 discard",
    )
    args = parser.parse_args()

    base = repo_root_from_here()
    harness_path = base / (args.harness or DEFAULT_HARNESS_REL)
    fuzzy_path = base / (args.fuzzy or DEFAULT_FUZZY_REL)
    traj_root = base / (args.traj_root or DEFAULT_TRAJ_ROOT_REL)
    out_dir = base / (args.out_dir or DEFAULT_OUT_DIR_REL)
    inst_dir = out_dir / "instances"

    if not harness_path.is_file():
        print(f"Error: harness 不存在: {harness_path}", file=sys.stderr)
        sys.exit(1)
    if not fuzzy_path.is_file():
        print(f"Error: fuzzy 不存在: {fuzzy_path}", file=sys.stderr)
        sys.exit(1)
    if not traj_root.is_dir():
        print(f"Error: traj 根目录不存在: {traj_root}", file=sys.stderr)
        sys.exit(1)

    harness_list = load_json(harness_path)
    if not isinstance(harness_list, list):
        print("Error: harness JSON 应为数组", file=sys.stderr)
        sys.exit(1)

    fuzzy_list = load_json(fuzzy_path)
    if not isinstance(fuzzy_list, list):
        print("Error: fuzzy JSON 应为数组", file=sys.stderr)
        sys.exit(1)

    fuzzy_ok = {
        str(item["instance_id"])
        for item in fuzzy_list
        if isinstance(item, dict)
        and item.get("instance_id")
        and item.get("discard") is not True
    }

    harness_passed = {
        str(item["instance_id"])
        for item in harness_list
        if isinstance(item, dict) and item.get("passed") is True and item.get("instance_id")
    }
    if args.fuzzy_not_passed:
        candidate_ids = sorted(fuzzy_ok - harness_passed)
        candidate_desc = "fuzzy discard 非 true 且 harness 未通过"
    else:
        candidate_ids = sorted(harness_passed & fuzzy_ok)
        candidate_desc = "harness 通过 ∩ fuzzy discard 非 true"

    if args.instance_id:
        want = {x.strip() for x in args.instance_id if x and x.strip()}
        to_run = [iid for iid in candidate_ids if iid in want]
        missing = want - set(candidate_ids)
        if missing:
            print(f"警告: 下列 id 不在候选集（{candidate_desc}）中，将忽略: {sorted(missing)}", file=sys.stderr)
    else:
        sl = candidate_ids[args.offset :]
        if args.limit is not None:
            sl = sl[: args.limit]
        to_run = sl

    inst_dir.mkdir(parents=True, exist_ok=True)

    print(f"harness 通过: {len(harness_passed)}")
    print(f"fuzzy discard 非 true: {len(fuzzy_ok)}")
    print(f"候选集（{candidate_desc}）: {len(candidate_ids)}")
    print(f"本轮将处理: {len(to_run)}")
    if args.dry_run:
        for iid in to_run:
            print(iid)
        return

    api_key = (
        (os.getenv("OPENAI_API_KEY") or "").strip()
        or (os.getenv("API_KEY") or "").strip()
    )
    if not api_key:
        print("Error: 请设置环境变量 OPENAI_API_KEY 或 API_KEY", file=sys.stderr)
        sys.exit(1)
    base_url = os.getenv("OPENAI_BASE_URL", "http://dlrrrrbs.tcp01.cn:13007/v1").rstrip("/")
    model = os.getenv("OPENAI_MODEL", "openai/kimi-k25")

    from openai import OpenAI

    def make_client() -> Any:
        return OpenAI(
            api_key=api_key,
            base_url=base_url,
            default_headers={"Authorization": "Bearer " + api_key},
            timeout=HTTP_REQUEST_TIMEOUT_SEC,
        )

    def process_one(iid: str) -> tuple[str, dict[str, Any] | None, str | None]:
        out_path = inst_dir / f"{iid}.json"
        if args.skip_existing and out_path.is_file():
            return iid, None, "skipped_existing"

        traj_path = traj_root / iid / f"{iid}.traj.json"
        if not traj_path.is_file():
            err_rec = {
                "instance_id": iid,
                "error": "traj_missing",
                "traj_path": str(traj_path.relative_to(base)),
            }
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(err_rec, f, ensure_ascii=False, indent=2)
            return iid, err_rec, "missing_traj"

        with open(traj_path, encoding="utf-8") as f:
            traj = json.load(f)

        client = make_client()
        try:
            rec = analyze_traj_one(
                iid,
                traj,
                client=client,
                model=model,
                per_msg_cap=args.per_msg_cap,
                chunk_budget_chars=args.chunk_budget_chars,
                stream=args.stream,
            )
        except Exception as e:
            rec = {
                "instance_id": iid,
                "error": "api_or_parse_failed",
                "detail": str(e),
                "traj_path": str(traj_path.relative_to(base)),
            }
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(rec, f, ensure_ascii=False, indent=2)
            return iid, rec, str(e)

        rec["harness_passed"] = iid in harness_passed
        rec["traj_path"] = str(traj_path.relative_to(base))
        rec["trajectory_format"] = traj.get("trajectory_format")

        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(rec, f, ensure_ascii=False, indent=2)

        return iid, rec, None

    errors: list[tuple[str, str]] = []
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futs = {ex.submit(process_one, iid): iid for iid in to_run}
        done_n = 0
        for fut in as_completed(futs):
            iid = futs[fut]
            try:
                _, _, err = fut.result()
                done_n += 1
                if err and err not in ("skipped_existing",):
                    if err != "missing_traj":
                        errors.append((iid, err))
                if err == "skipped_existing":
                    print(f"[{done_n}/{len(to_run)}] {iid} (skip existing)")
                else:
                    print(f"[{done_n}/{len(to_run)}] {iid}" + (f" err={err}" if err else ""))
            except Exception as e:
                print(f"{iid} 未捕获异常: {e}", file=sys.stderr)
                errors.append((iid, str(e)))

    if errors:
        print(f"失败/异常 {len(errors)} 条（详见各实例 json 的 error 字段）", file=sys.stderr)


if __name__ == "__main__":
    main()
