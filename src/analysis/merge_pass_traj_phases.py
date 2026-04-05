#!/usr/bin/env python3
"""
基于 annotate_pass_traj_capabilities.py 输出的逐步 thought/action，
将 user+assistant 合并为「一轮」，再将多轮合并为「阶段」，每实例写一个 JSON。
"""
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

DEFAULT_CAPABILITIES_DIR_REL = "result/strengthen/v3/kimi_pass_traj_capabilities/instances"
DEFAULT_OUT_DIR_REL = "result/strengthen/v3/kimi_pass_traj_phases/instances"
HTTP_REQUEST_TIMEOUT_SEC = 900.0

PHASE_SYSTEM_PROMPT = """你是软件工程轨迹分析助手。输入为按时间顺序的多「轮」对话摘要；每一轮包含一轮次序号、user 与 assistant 的 thought_zh / action_zh（均为中文摘要）。

任务：
1. 将连续若干轮合并为「阶段」：同一阶段内目标一致或强相关（例如：探索定位、实施修改、搜索残留、验证与收尾）。相邻阶段之间应有可分辨的目标或活动切换。
2. 每个阶段需有简短标题 title_zh（4–12 字），以及 behavior_zh：用 1–3 句中文概括该阶段整体在做什么（可提及关键命令/文件/操作，避免空洞套话）。
3. 覆盖所有轮次：每个 paired_step_index 恰好出现在一个阶段中，且按轮次顺序划分（阶段内 paired_step_index 递增，阶段之间不交叉）。

只输出纯 JSON，无 Markdown：
{"phases":[{"phase_index":0,"title_zh":"...","paired_step_indices":[0,1,2],"behavior_zh":"..."},...]}"""


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


def pair_user_assistant_steps(steps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """将 annotate 的逐条 message steps 配成 user+assistant 一轮。跳过 system。"""
    filtered: list[dict[str, Any]] = []
    for s in steps:
        if not isinstance(s, dict):
            continue
        role = str(s.get("role") or "").strip().lower()
        if role == "system":
            continue
        if role not in ("user", "assistant"):
            continue
        filtered.append(s)

    pairs: list[dict[str, Any]] = []
    i = 0
    step_idx = 0
    while i < len(filtered):
        u = filtered[i]
        if str(u.get("role", "")).lower() != "user":
            pairs.append(
                {
                    "step_index": step_idx,
                    "message_indices": [int(u.get("index", -1))],
                    "user": _step_slice(u),
                    "assistant": None,
                    "note": "orphan_non_user",
                }
            )
            step_idx += 1
            i += 1
            continue
        if i + 1 >= len(filtered) or str(filtered[i + 1].get("role", "")).lower() != "assistant":
            pairs.append(
                {
                    "step_index": step_idx,
                    "message_indices": [int(u.get("index", -1))],
                    "user": _step_slice(u),
                    "assistant": None,
                    "note": "missing_assistant",
                }
            )
            step_idx += 1
            i += 1
            continue
        a = filtered[i + 1]
        pairs.append(
            {
                "step_index": step_idx,
                "message_indices": [int(u.get("index", -1)), int(a.get("index", -1))],
                "user": _step_slice(u),
                "assistant": _step_slice(a),
            }
        )
        step_idx += 1
        i += 2
    return pairs


def _step_slice(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "index": row.get("index"),
        "role": row.get("role"),
        "thought_zh": row.get("thought_zh") or "",
        "action_zh": row.get("action_zh") or "",
    }


def build_phase_user_text(paired: list[dict[str, Any]], instance_id: str) -> str:
    lines = [f"instance_id: {instance_id}", "", "以下为各轮摘要（paired_step_index 即轮次序号）：", ""]
    for p in paired:
        si = int(p["step_index"])
        u = p["user"] or {}
        a = p.get("assistant") or {}
        lines.append(f"--- paired_step_index={si} ---")
        lines.append(f"user[{u.get('index')}]: thought: {u.get('thought_zh','')}")
        lines.append(f"user[{u.get('index')}]: action: {u.get('action_zh','')}")
        if a:
            lines.append(f"assistant[{a.get('index')}]: thought: {a.get('thought_zh','')}")
            lines.append(f"assistant[{a.get('index')}]: action: {a.get('action_zh','')}")
        else:
            lines.append("assistant: （缺失）")
        lines.append("")
    return "\n".join(lines)


def validate_phases(
    phases_raw: list[dict[str, Any]],
    n_paired: int,
) -> tuple[list[dict[str, Any]] | None, str | None]:
    if n_paired == 0:
        return [], None
    seen: set[int] = set()
    ordered: list[dict[str, Any]] = []
    for i, ph in enumerate(phases_raw):
        if not isinstance(ph, dict):
            return None, f"phase {i} 非对象"
        title = str(ph.get("title_zh") or "").strip()
        behavior = str(ph.get("behavior_zh") or "").strip()
        idxs = ph.get("paired_step_indices")
        if not isinstance(idxs, list) or not idxs:
            return None, f"phase {i} 缺少 paired_step_indices"
        norm: list[int] = []
        for x in idxs:
            try:
                norm.append(int(x))
            except (TypeError, ValueError):
                return None, f"phase {i} paired_step_indices 含非法项"
        if len(norm) != len(set(norm)):
            return None, f"phase {i} paired_step_indices 含重复项"
        norm.sort()
        for j in norm:
            if j < 0 or j >= n_paired:
                return None, f"paired_step_index {j} 越界（共 {n_paired} 轮）"
            if j in seen:
                return None, f"paired_step_index {j} 重复出现"
            seen.add(j)
        ordered.append(
            {
                "title_zh": title,
                "paired_step_indices": norm,
                "behavior_zh": behavior,
            }
        )
    if seen != set(range(n_paired)):
        missing = sorted(set(range(n_paired)) - seen)
        return None, f"轮次未全覆盖: 缺失 {missing[:20]}{'...' if len(missing) > 20 else ''}"

    merged = sorted(ordered, key=lambda p: min(p["paired_step_indices"]))
    flat: list[int] = []
    for p in merged:
        flat.extend(p["paired_step_indices"])
    if flat != list(range(n_paired)):
        return None, "阶段内或阶段间轮次顺序与原始不一致"
    for pi, ph in enumerate(merged):
        ph["phase_index"] = pi
    return merged, None


def synthesize_phases_llm(
    instance_id: str,
    paired: list[dict[str, Any]],
    *,
    client: Any,
    model: str,
    stream: bool,
) -> tuple[list[dict[str, Any]] | None, str | None]:
    if not paired:
        return [], None
    user_text = build_phase_user_text(paired, instance_id)
    raw = call_llm(client, model, system=PHASE_SYSTEM_PROMPT, user=user_text, stream=stream)
    try:
        obj = extract_json_object(raw)
    except Exception as e:
        return None, f"parse_json: {e}"
    phases = obj.get("phases")
    if not isinstance(phases, list):
        return None, "响应无 phases 数组"
    fixed, err = validate_phases(phases, len(paired))
    if err:
        return None, err
    return fixed, None


def attach_phase_details(
    phases: list[dict[str, Any]],
    paired: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    pmap = {int(p["step_index"]): p for p in paired}
    for ph in phases:
        idxs = ph["paired_step_indices"]
        steps_detail = [pmap[j] for j in idxs if j in pmap]
        row = dict(ph)
        row["paired_steps"] = steps_detail
        out.append(row)
    return out


def process_one_instance(
    cap_path: Path,
    out_path: Path,
    *,
    client: Any,
    model: str,
    stream: bool,
    skip_existing: bool,
) -> tuple[str, str | None]:
    iid = cap_path.stem
    if skip_existing and out_path.is_file():
        return iid, "skipped_existing"

    try:
        rec = load_json(cap_path)
    except Exception as e:
        err_rec = {"instance_id": iid, "error": "load_failed", "detail": str(e), "source": str(cap_path)}
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(err_rec, f, ensure_ascii=False, indent=2)
        return iid, str(e)

    if not isinstance(rec, dict):
        err_rec = {"instance_id": iid, "error": "invalid_capabilities_json", "source": str(cap_path)}
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(err_rec, f, ensure_ascii=False, indent=2)
        return iid, "invalid json"

    steps = rec.get("steps")
    if not isinstance(steps, list):
        steps = []

    paired = pair_user_assistant_steps(steps)
    phases_llm, err = synthesize_phases_llm(iid, paired, client=client, model=model, stream=stream)
    if err:
        out_obj: dict[str, Any] = {
            "instance_id": rec.get("instance_id") or iid,
            "error": "phase_synthesis_failed",
            "detail": err,
            "source_capabilities_path": str(cap_path),
            "paired_steps": paired,
            "phases": [],
        }
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(out_obj, f, ensure_ascii=False, indent=2)
        return iid, err

    phases_with_detail = attach_phase_details(phases_llm or [], paired)
    out_obj = {
        "instance_id": rec.get("instance_id") or iid,
        "source_capabilities_path": str(cap_path),
        "harness_passed": rec.get("harness_passed"),
        "traj_path": rec.get("traj_path"),
        "paired_step_count": len(paired),
        "paired_steps": paired,
        "phase_count": len(phases_with_detail),
        "phases": phases_with_detail,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_obj, f, ensure_ascii=False, indent=2)
    time.sleep(0.15)
    return iid, None


def main() -> None:
    parser = argparse.ArgumentParser(description="将 capabilities 逐步注解合并为阶段 JSON（每实例一文件）")
    parser.add_argument("--capabilities-dir", type=str, default=None, help="annotate_pass_traj_capabilities instances 目录")
    parser.add_argument("--out-dir", type=str, default=None, help="输出目录（每实例 {id}.json）")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--instance-id", action="append", default=None)
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--stream", action="store_true")
    args = parser.parse_args()

    base = repo_root_from_here()
    cap_dir = base / (args.capabilities_dir or DEFAULT_CAPABILITIES_DIR_REL)
    out_dir = base / (args.out_dir or DEFAULT_OUT_DIR_REL)

    if not cap_dir.is_dir():
        print(f"Error: capabilities 目录不存在: {cap_dir}", file=sys.stderr)
        sys.exit(1)

    json_files = sorted(cap_dir.glob("*.json"))
    ids = [p.stem for p in json_files]

    if args.instance_id:
        want = {x.strip() for x in args.instance_id if x and x.strip()}
        to_run = [iid for iid in ids if iid in want]
        missing = want - set(ids)
        if missing:
            print(f"警告: 下列 id 无对应 json，将忽略: {sorted(missing)}", file=sys.stderr)
    else:
        sl = ids[args.offset :]
        if args.limit is not None:
            sl = sl[: args.limit]
        to_run = sl

    print(f"capabilities 文件数: {len(json_files)}")
    print(f"本轮将处理: {len(to_run)}")
    print(f"输出目录: {out_dir}")

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
            default_headers={"Authorization": f"Bearer {api_key}"},
            timeout=HTTP_REQUEST_TIMEOUT_SEC,
        )

    errors: list[tuple[str, str]] = []
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futs = {}
        for iid in to_run:
            cap_path = cap_dir / f"{iid}.json"
            outp = out_dir / f"{iid}.json"
            futs[ex.submit(process_one_instance, cap_path, outp, client=make_client(), model=model, stream=args.stream, skip_existing=args.skip_existing)] = iid
        done_n = 0
        for fut in as_completed(futs):
            iid = futs[fut]
            try:
                _, err = fut.result()
                done_n += 1
                if err and err != "skipped_existing":
                    errors.append((iid, err))
                if err == "skipped_existing":
                    print(f"[{done_n}/{len(to_run)}] {iid} (skip existing)")
                else:
                    print(f"[{done_n}/{len(to_run)}] {iid}" + (f" err={err}" if err else ""))
            except Exception as e:
                print(f"{iid} 未捕获异常: {e}", file=sys.stderr)
                errors.append((iid, str(e)))

    if errors:
        print(f"失败/异常 {len(errors)} 条", file=sys.stderr)


if __name__ == "__main__":
    main()
