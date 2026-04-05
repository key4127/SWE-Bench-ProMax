#!/usr/bin/env python3
"""
对「生成的实例」逐一判断推理能力相关标签。

默认假定已跑过 annotate_pass_traj_capabilities：从 instances 目录读逐步 thought/action，
任务描述优先来自 fuzzy 的 problem_statement。

候选集：fuzzy 中 discard 非 true，且在 harness 中有结果的实例（同时包含跑通与未跑通）。
- pass 且非 discard：判断**需要**哪些 reasoning 能力（capabilities）。
- fail 且非 discard：判断**缺少**哪些 reasoning 能力导致失败（missing_capabilities）。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Literal

AnalysisMode = Literal["pass", "fail"]

os.environ.pop("HTTP_PROXY", None)
os.environ.pop("HTTPS_PROXY", None)
os.environ.pop("http_proxy", None)
os.environ.pop("https_proxy", None)

DEFAULT_HARNESS_REL = "result/harness_result/strengthen/v3/kimi.json"
DEFAULT_FUZZY_REL = "result/strengthen/v3/all_nl_fuzzy.json"
DEFAULT_INSTANCE_JSON_DIR_REL = "result/strengthen/v3/kimi_pass_traj_capabilities/instances"
DEFAULT_OUT_DIR_REL = "result/strengthen/v3/kimi_instance_reasoning_capabilities"
HTTP_REQUEST_TIMEOUT_SEC = 900.0

# 与需求一致的能力键（固定集合，输出须覆盖每一项 true/false）
REASONING_CAPABILITY_KEYS: tuple[str, ...] = (
    "crossing_file_reasoning",
    "api_semantics",
    "interface_contract",
    "pattern_matching",
    "data_flow",
    "domain_knowledge",
    "control_flow",
    "type_system",
    "protocol_understanding",
    "concurrency",
    "memory_management",
)

CAPABILITY_DEFS_BLOCK = """可选能力（键名必须完全一致）及含义：
- crossing_file_reasoning: 在多个文件或模块之间追踪逻辑
- api_semantics: 库/框架 API 的契约与行为
- interface_contract: 调用方/被调方必须满足的约定与不变量
- pattern_matching: 识别代码模式与反模式
- data_flow: 数据如何传递、变换或修改
- domain_knowledge: 领域知识（如 YANG、Bluetooth、音频编解码等）
- control_flow: 执行路径、分支与循环
- type_system: 类型约束、检查与转换
- protocol_understanding: 网络协议、序列化格式、标准规范
- concurrency: 线程、锁、竞态、异步等
- memory_management: 堆栈、所有权、生命周期、资源释放"""

REASONING_SYSTEM_PROMPT_PASS = f"""你是软件工程研究助手。本实例 **harness 已通过**，且 fuzzy 标注为**非 discard**。

根据**任务描述**和**逐步 thought/action 摘要**，判断：要解决该任务，开发者/模型在理解与修改代码时**主要需要**哪些推理能力。

{CAPABILITY_DEFS_BLOCK}

规则：
1) 只勾选**对完成该任务实质必要**的能力，不要泛泛全选。
2) 若某能力几乎不涉及，设为 false。
3) 输出**仅**一个 JSON 对象，不要 Markdown 代码块，不要额外文字。

格式（capabilities 必须包含上述全部键，布尔值）：
{{
  "capabilities": {{
    "crossing_file_reasoning": true,
    "api_semantics": false
  }},
  "rationale_zh": "一两句中文：为何需要这些能力、最关键的是什么"
}}
"""

REASONING_SYSTEM_PROMPT_FAIL = f"""你是软件工程研究助手。本实例 **harness 未通过**（任务失败），且 fuzzy 标注为**非 discard**。

根据**任务描述**和**逐步 thought/action 摘要**，判断：从摘要可见的行为与卡点看，agent **在哪些推理能力上不足或运用错误**导致未能完成/跑通；即**缺少哪些能力**（或哪些维度明显薄弱）与失败**因果相关**。

{CAPABILITY_DEFS_BLOCK}

规则：
1) 在 missing_capabilities 中：若某维度**明显不足、误判或未正确运用**且与失败相关，设为 true；与失败无关则 false。
2) 不要泛泛全选；聚焦与逐步摘要中可见失误、卡点相关的维度。
3) 输出**仅**一个 JSON 对象，不要 Markdown 代码块，不要额外文字。

格式（missing_capabilities 必须包含上述全部键，布尔值）：
{{
  "missing_capabilities": {{
    "crossing_file_reasoning": true,
    "api_semantics": false
  }},
  "rationale_zh": "两三句中文：失败表现、为何归因于上述缺失能力"
}}
"""


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


def normalize_capabilities(raw: dict[str, Any] | None) -> dict[str, bool]:
    out: dict[str, bool] = {k: False for k in REASONING_CAPABILITY_KEYS}
    if not raw or not isinstance(raw, dict):
        return out
    for k in REASONING_CAPABILITY_KEYS:
        v = raw.get(k)
        if v is True:
            out[k] = True
        elif v is False:
            out[k] = False
        elif isinstance(v, str) and v.strip().lower() in ("true", "1", "yes"):
            out[k] = True
    return out


def build_user_text_from_instance_json(obj: dict[str, Any], instance_id: str, *, max_chars: int) -> str:
    steps = obj.get("steps")
    if not isinstance(steps, list):
        return ""
    lines: list[str] = [f"instance_id: {instance_id}", "", "## 逐步摘要（thought / action）", ""]
    for i, s in enumerate(steps):
        if not isinstance(s, dict):
            continue
        th = s.get("thought_zh") or s.get("thought") or ""
        act = s.get("action") or s.get("action_zh") or ""
        lines.append(f"### step {i}")
        lines.append(f"thought: {th}")
        lines.append(f"action: {act}")
        lines.append("")
    text = "\n".join(lines)
    return truncate(text, max_chars)


def analyze_instance_reasoning(
    instance_id: str,
    *,
    user_payload: str,
    task_text: str,
    mode: AnalysisMode,
    client: Any,
    model: str,
    stream: bool,
) -> dict[str, Any]:
    sections: list[str] = [
        f"instance_id: {instance_id}",
        "",
        "## 任务描述（PR / instructions）",
        task_text or "（未解析到任务描述，请从下节逐步摘要推断）",
        "",
        "## 逐步注解摘要（thought / action）",
        user_payload,
    ]
    full_user = "\n".join(sections)
    system = REASONING_SYSTEM_PROMPT_PASS if mode == "pass" else REASONING_SYSTEM_PROMPT_FAIL
    raw = call_llm(client, model, system=system, user=full_user, stream=stream)
    obj = extract_json_object(raw)
    rationale = obj.get("rationale_zh") or obj.get("rationale") or ""
    if mode == "pass":
        caps = normalize_capabilities(obj.get("capabilities"))
        selected = [k for k, v in caps.items() if v]
        return {
            "instance_id": instance_id,
            "capabilities": caps,
            "capabilities_selected": selected,
            "rationale_zh": str(rationale).strip(),
        }
    miss = normalize_capabilities(obj.get("missing_capabilities"))
    miss_sel = [k for k, v in miss.items() if v]
    return {
        "instance_id": instance_id,
        "missing_capabilities": miss,
        "missing_capabilities_selected": miss_sel,
        "rationale_zh": str(rationale).strip(),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="对实例标注 reasoning 能力：pass→所需能力；fail→缺失能力（默认读逐步注解 JSON）",
    )
    parser.add_argument("--harness", type=str, default=None)
    parser.add_argument("--fuzzy", type=str, default=None)
    parser.add_argument("--out-dir", type=str, default=None)
    parser.add_argument(
        "--instance-json-dir",
        type=str,
        default=None,
        help=f"annotate_pass_traj_capabilities 产出的 instances 目录（默认 {DEFAULT_INSTANCE_JSON_DIR_REL}）",
    )
    parser.add_argument(
        "--only-cohort",
        type=str,
        choices=("all", "pass_not_discard", "fail_not_discard"),
        default="all",
        help="只处理 pass 且非 discard、只处理 fail 且非 discard、或两者（默认 all）",
    )
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--instance-id", action="append", default=None)
    parser.add_argument("--task-max-chars", type=int, default=50_000)
    parser.add_argument("--instance-json-max-chars", type=int, default=200_000)
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--stream", action="store_true")
    args = parser.parse_args()

    base = repo_root_from_here()
    harness_path = base / (args.harness or DEFAULT_HARNESS_REL)
    fuzzy_path = base / (args.fuzzy or DEFAULT_FUZZY_REL)
    out_dir = base / (args.out_dir or DEFAULT_OUT_DIR_REL)
    inst_dir = out_dir / "instances"
    ij_rel = args.instance_json_dir or DEFAULT_INSTANCE_JSON_DIR_REL
    instance_json_dir = (base / ij_rel).resolve()

    if not harness_path.is_file():
        print(f"Error: harness 不存在: {harness_path}", file=sys.stderr)
        sys.exit(1)
    if not fuzzy_path.is_file():
        print(f"Error: fuzzy 不存在: {fuzzy_path}", file=sys.stderr)
        sys.exit(1)
    if not instance_json_dir.is_dir():
        print(f"Error: 逐步注解目录不存在: {instance_json_dir}", file=sys.stderr)
        sys.exit(1)

    harness_list = load_json(harness_path)
    if not isinstance(harness_list, list):
        print("Error: harness JSON 应为数组", file=sys.stderr)
        sys.exit(1)

    fuzzy_list = load_json(fuzzy_path)
    if not isinstance(fuzzy_list, list):
        print("Error: fuzzy JSON 应为数组", file=sys.stderr)
        sys.exit(1)

    fuzzy_task_by_id: dict[str, str] = {}
    for item in fuzzy_list:
        if not isinstance(item, dict) or not item.get("instance_id"):
            continue
        ps = item.get("problem_statement")
        if isinstance(ps, str) and ps.strip():
            iid_k = str(item["instance_id"])
            fuzzy_task_by_id[iid_k] = truncate(ps.strip(), args.task_max_chars)

    harness_pass_map: dict[str, bool] = {}
    for item in harness_list:
        if isinstance(item, dict) and item.get("instance_id"):
            harness_pass_map[str(item["instance_id"])] = item.get("passed") is True

    fuzzy_discard_map: dict[str, bool] = {}
    for item in fuzzy_list:
        if isinstance(item, dict) and item.get("instance_id"):
            fuzzy_discard_map[str(item["instance_id"])] = item.get("discard") is True

    fuzzy_not_discard = {iid for iid, disc in fuzzy_discard_map.items() if not disc}
    pool = sorted(fuzzy_not_discard & set(harness_pass_map.keys()))
    n_pass = sum(1 for i in pool if harness_pass_map[i])
    n_fail = len(pool) - n_pass

    candidate_ids = pool[:]
    if args.only_cohort == "pass_not_discard":
        candidate_ids = [iid for iid in candidate_ids if harness_pass_map[iid]]
    elif args.only_cohort == "fail_not_discard":
        candidate_ids = [iid for iid in candidate_ids if not harness_pass_map[iid]]

    candidate_desc = (
        "fuzzy discard 非 true 且在 harness 中有记录；"
        "含 pass_not_discard 与 fail_not_discard（可用 --only-cohort 筛选）"
    )

    if args.instance_id:
        want = {x.strip() for x in args.instance_id if x and x.strip()}
        to_run = [iid for iid in candidate_ids if iid in want]
        missing = want - set(candidate_ids)
        if missing:
            print(f"警告: 下列 id 不在候选集中，将忽略: {sorted(missing)}", file=sys.stderr)
    else:
        sl = candidate_ids[args.offset :]
        if args.limit is not None:
            sl = sl[: args.limit]
        to_run = sl

    inst_dir.mkdir(parents=True, exist_ok=True)

    print(f"harness 中有记录的实例数: {len(harness_pass_map)}")
    print(f"fuzzy discard 非 true: {len(fuzzy_not_discard)}")
    print(f"候选（非 discard 且在 harness 中）: pass≈{n_pass} fail≈{n_fail} 合计 {len(pool)}")
    print(f"候选说明: {candidate_desc}")
    print(f"本轮将处理: {len(to_run)}")
    print(f"逐步注解目录: {instance_json_dir.relative_to(base)}")
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

    def attach_cohort(rec: dict[str, Any], iid: str) -> None:
        hp = harness_pass_map.get(iid, False)
        fd = fuzzy_discard_map.get(iid, False)
        rec["harness_passed"] = hp
        rec["fuzzy_discard"] = fd
        rec["cohort"] = "pass_not_discard" if hp else "fail_not_discard"
        rec["pass_and_not_discard"] = hp and not fd
        rec["fail_and_not_discard"] = (not hp) and not fd

    def process_one(iid: str) -> tuple[str, dict[str, Any] | None, str | None]:
        out_path = inst_dir / f"{iid}.json"
        if args.skip_existing and out_path.is_file():
            return iid, None, "skipped_existing"

        harness_passed = harness_pass_map.get(iid, False)
        mode: AnalysisMode = "pass" if harness_passed else "fail"

        client = make_client()

        ij_path = instance_json_dir / f"{iid}.json"
        if not ij_path.is_file():
            err_rec = {
                "instance_id": iid,
                "error": "instance_json_missing",
                "path": str(ij_path.relative_to(base)),
            }
            attach_cohort(err_rec, iid)
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(err_rec, f, ensure_ascii=False, indent=2)
            return iid, err_rec, "missing_instance_json"

        with open(ij_path, encoding="utf-8") as f:
            inst_obj = json.load(f)

        task_text = str(inst_obj.get("task_text") or inst_obj.get("problem") or "").strip()
        if not task_text:
            task_text = fuzzy_task_by_id.get(iid, "")

        payload = build_user_text_from_instance_json(
            inst_obj if isinstance(inst_obj, dict) else {},
            iid,
            max_chars=args.instance_json_max_chars,
        )
        if not payload.strip():
            err_rec = {
                "instance_id": iid,
                "error": "empty_instance_json_context",
                "path": str(ij_path.relative_to(base)),
            }
            attach_cohort(err_rec, iid)
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(err_rec, f, ensure_ascii=False, indent=2)
            return iid, err_rec, "empty_context"

        try:
            rec = analyze_instance_reasoning(
                iid,
                user_payload=payload,
                task_text=truncate(task_text, args.task_max_chars),
                mode=mode,
                client=client,
                model=model,
                stream=args.stream,
            )
        except Exception as e:
            rec = {
                "instance_id": iid,
                "error": "api_or_parse_failed",
                "detail": str(e),
                "source_instance_json": str(ij_path.relative_to(base)),
            }
            attach_cohort(rec, iid)
            with open(out_path, "w", encoding="utf-8") as f:
                json.dump(rec, f, ensure_ascii=False, indent=2)
            return iid, rec, str(e)

        attach_cohort(rec, iid)
        rec["source_instance_json"] = str(ij_path.relative_to(base))

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
                    if err not in ("missing_instance_json", "empty_context"):
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
