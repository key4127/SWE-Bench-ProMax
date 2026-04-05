#!/usr/bin/env python3
"""对 bash_only 预测目录中 resolved 的实例做轨迹能力标注（thought/action），输出到 strengthen/v3/bash_only。

输入：result/preds_result/bash_only（per_instance_details.json + by_instance/.../traj.json）
输出：result/strengthen/v3/bash_only/instances/<instance_id>.json
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any

for _k in ("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy"):
    os.environ.pop(_k, None)

DEFAULT_BASH_ONLY_ROOT_REL = "result/preds_result/bash_only"
DEFAULT_OUT_DIR_REL = "result/strengthen/v3/bash_only"

ACTION_SYSTEM_PROMPT_BASH = """输入**只有 user 与 tool**（index 与原始轨迹一致）。不要包含 assistant。
每条一项：index、role、action。概括环境/shell 返回；尽量写具体命令、路径、错误片段。
一句中文，不要分点、换行、前缀。
输出 {"steps":[...]} 纯 JSON，无 Markdown。"""


def repo_root_from_here() -> Path:
    return Path(__file__).resolve().parents[3]


def load_json(path: Path) -> Any:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _load_aptc():
    here = Path(__file__).resolve().parent / "annotate_pass_traj_capabilities.py"
    spec = importlib.util.spec_from_file_location("annotate_pass_traj_capabilities", here)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load annotate_pass_traj_capabilities")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def resolve_traj_path(bash_root: Path, instance_id: str) -> Path | None:
    inst_dir = bash_root / "by_instance" / instance_id
    if not inst_dir.is_dir():
        return None
    summary_path = inst_dir / "summary.json"
    if summary_path.is_file():
        summary = load_json(summary_path)
        models = summary.get("models") or []
        if models:
            m0 = models[0]
            model_dir = m0.get("model_dir") or m0.get("submission")
            rel = m0.get("traj_json") or "traj.json"
            if model_dir and rel:
                p = inst_dir / str(model_dir) / rel
                if p.is_file():
                    return p
    for sub in sorted(inst_dir.iterdir()):
        if sub.is_dir():
            cand = sub / "traj.json"
            if cand.is_file():
                return cand
    return None


def analyze_traj_one_bash(
    instance_id: str,
    traj: dict[str, Any],
    *,
    client: Any,
    model: str,
    per_msg_cap: int,
    chunk_budget_chars: int,
    stream: bool,
    aptc: Any,
) -> dict[str, Any]:
    messages = traj.get("messages") or []
    blocks = aptc.build_message_blocks(messages, per_msg_cap=per_msg_cap)
    if not blocks:
        return {
            "instance_id": instance_id,
            "error": "no_user_assistant_messages",
            "steps": [],
        }

    assistant_blocks = [b for b in blocks if b[1].strip().lower() == "assistant"]
    action_blocks = [b for b in blocks if b[1].strip().lower() in ("user", "tool")]
    by_idx: dict[int, dict[str, Any]] = {}

    t_chunks = aptc.chunk_blocks_by_budget(assistant_blocks, max_chars=chunk_budget_chars)
    for ci, ch in enumerate(t_chunks):
        text = aptc.build_chunk_user_text(ch, instance_id)
        if len(t_chunks) > 1:
            text += f"\n\n（thought 分段 {ci + 1}/{len(t_chunks)}）"
        raw = aptc.call_llm(
            client, model, system=aptc.THOUGHT_SYSTEM_PROMPT, user=text, stream=stream
        )
        obj = aptc.extract_json_object(raw)
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

    a_chunks = aptc.chunk_blocks_by_budget(action_blocks, max_chars=chunk_budget_chars)
    for ci, ch in enumerate(a_chunks):
        text = aptc.build_chunk_user_text(ch, instance_id)
        if len(a_chunks) > 1:
            text += f"\n\n（action 分段 {ci + 1}/{len(a_chunks)}）"
        raw = aptc.call_llm(
            client, model, system=ACTION_SYSTEM_PROMPT_BASH, user=text, stream=stream
        )
        obj = aptc.extract_json_object(raw)
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
            block_role = next((b[1] for b in ch if b[0] == ix), "user")
            by_idx[ix] = {
                "index": ix,
                "role": str(item.get("role") or block_role),
                "action": str(item.get("action") or item.get("action_zh") or ""),
            }
        time.sleep(0.2)

    ordered = [by_idx[i] for i in sorted(by_idx.keys())]
    return {"instance_id": instance_id, "steps": ordered}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="bash_only resolved 轨迹 → pass_traj_capabilities（instances/*.json）"
    )
    parser.add_argument("--bash-only-root", type=str, default=None)
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
        "--all-with-traj",
        action="store_true",
        help="处理 per_instance_details 中所有在磁盘上存在 traj 的实例（不限 resolved）",
    )
    args = parser.parse_args()

    base = repo_root_from_here()
    bash_root = base / (args.bash_only_root or DEFAULT_BASH_ONLY_ROOT_REL)
    out_dir = base / (args.out_dir or DEFAULT_OUT_DIR_REL)
    inst_dir = out_dir / "instances"
    details_path = bash_root / "per_instance_details.json"

    if not bash_root.is_dir():
        print(f"Error: bash_only 根目录不存在: {bash_root}", file=sys.stderr)
        sys.exit(1)
    if not details_path.is_file():
        print(f"Error: 不存在: {details_path}", file=sys.stderr)
        sys.exit(1)

    details = load_json(details_path)
    if not isinstance(details, dict):
        print("Error: per_instance_details.json 应为对象", file=sys.stderr)
        sys.exit(1)

    aptc = _load_aptc()

    if args.all_with_traj:
        candidate_ids: list[str] = []
        for iid in sorted(details.keys()):
            if resolve_traj_path(bash_root, iid):
                candidate_ids.append(iid)
        desc = "存在 traj（--all-with-traj）"
    else:
        candidate_ids = sorted(
            iid
            for iid, rec in details.items()
            if isinstance(rec, dict) and rec.get("resolved") is True
        )
        desc = "per_instance_details resolved=true"

    if args.instance_id:
        want = {x.strip() for x in args.instance_id if x and x.strip()}
        to_run = [iid for iid in candidate_ids if iid in want]
        missing = want - set(candidate_ids)
        if missing:
            print(f"警告: 下列 id 不在候选集（{desc}）中，将忽略: {sorted(missing)}", file=sys.stderr)
    else:
        sl = candidate_ids[args.offset :]
        if args.limit is not None:
            sl = sl[: args.limit]
        to_run = sl

    inst_dir.mkdir(parents=True, exist_ok=True)

    print(f"候选（{desc}）: {len(candidate_ids)}")
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
            timeout=aptc.HTTP_REQUEST_TIMEOUT_SEC,
        )

    def process_one(iid: str) -> tuple[str, dict[str, Any] | None, str | None]:
        out_path = inst_dir / f"{iid}.json"
        if args.skip_existing and out_path.is_file():
            # 仅跳过“成功/无 error”的已存在结果；失败(error)的实例需要重新跑。
            try:
                existing = load_json(out_path)
            except Exception:
                existing = None
            if isinstance(existing, dict):
                err = existing.get("error", None)
                if err is None or err == "":
                    return iid, None, "skipped_existing"
            else:
                # 既不是 dict，或无法解析：为了避免误跳过，选择重新跑。
                pass

        traj_path = resolve_traj_path(bash_root, iid)
        if traj_path is None or not traj_path.is_file():
            err_rec = {
                "instance_id": iid,
                "error": "traj_missing",
                "traj_path": str(traj_path) if traj_path else None,
            }
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(err_rec, f, ensure_ascii=False, indent=2)
            return iid, err_rec, "missing_traj"

        with open(traj_path, encoding="utf-8") as f:
            traj = json.load(f)

        client = make_client()
        try:
            rec = analyze_traj_one_bash(
                iid,
                traj,
                client=client,
                model=model,
                per_msg_cap=args.per_msg_cap,
                chunk_budget_chars=args.chunk_budget_chars,
                stream=args.stream,
                aptc=aptc,
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

        rec["bash_resolved"] = (
            details.get(iid, {}).get("resolved") if isinstance(details.get(iid), dict) else None
        )
        rec["harness_passed"] = rec.get("bash_resolved") is True
        rec["traj_path"] = str(traj_path.relative_to(base))
        rec["trajectory_format"] = traj.get("trajectory_format")
        rec["source"] = "preds_result/bash_only"

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
