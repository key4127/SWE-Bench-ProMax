#!/usr/bin/env python3
"""
对 v2 结果中被判为「过窄测试」的实例做二次评判（利用 cursor-agent CLI）。

在原文件上就地修改：只覆盖 over_narrow_test=True 的记录，其余记录原样保留。
prompt 增加豁免条件：若问题描述中已明确说明了测试所硬编码的细节，则不视为过窄测试。

默认处理文件：result/strengthen/v2/test/judge_fail_only_result_v2.json
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

_SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = _SCRIPT_DIR.parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

DEFAULT_ENHANCED_SWE = PROJECT_ROOT / "result/strengthen/v2/all_nl_enhanced.json"
DEFAULT_PREDS_DIR = PROJECT_ROOT / "result/preds_result/kimi/nl"
DEFAULT_HARNESS_RESULT = PROJECT_ROOT / "result/harness_result/strengthen/kimi/nl.json"
DEFAULT_V2_RESULT = PROJECT_ROOT / "result/strengthen/v2/test/judge_fail_only_result_v2.json"
TMP_DIR = _SCRIPT_DIR / "tmp"

DEFAULT_CURSOR_AGENT_CMD = "cursor-agent"
CHECKPOINT_EVERY = 10
RETRIED_MARKER = "__retried__"


def _load_json(path: Path) -> Any:
    if not path or not path.exists():
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_enhanced_swe(path: Path | None) -> list[dict]:
    path = path or DEFAULT_ENHANCED_SWE
    data = _load_json(path)
    if data is None:
        return []
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        return list(data.values())
    return []


def load_harness_by_id(path: Path | None) -> dict[str, dict]:
    path = path or DEFAULT_HARNESS_RESULT
    data = _load_json(path)
    if data is None or not isinstance(data, list):
        return {}
    return {item["instance_id"]: item for item in data if item.get("instance_id")}


def load_pred_patch(instance_id: str, preds_dir: Path | None) -> str | None:
    preds_dir = preds_dir or DEFAULT_PREDS_DIR
    traj_path = preds_dir / instance_id / f"{instance_id}.traj.json"
    if not traj_path.exists():
        return None
    data = _load_json(traj_path)
    if not data or not isinstance(data, dict):
        return None
    info = data.get("info") or {}
    return info.get("submission") or None


def build_instance(it: dict, harness: dict, preds_dir: Path | None) -> dict | None:
    """为单个 enhanced_swe 条目构建实例。"""
    iid = it.get("instance_id")
    if not iid:
        return None
    raw = harness.get(iid) or {}
    model_obj = raw.get("model") or {}
    golden_obj = raw.get("golden") or {}
    model_final = (model_obj.get("final_result") or "").strip()
    golden_final = (golden_obj.get("final_result") or "").strip()
    test_passed = raw.get("passed") is True
    pred_patch = load_pred_patch(iid, preds_dir)
    return {
        "instance_id": iid,
        "repo": it.get("repo", ""),
        "base_commit": it.get("base_commit", ""),
        "problem_statement": it.get("problem_statement", ""),
        "golden_patch": it.get("patch", ""),
        "test_patch": it.get("test_patch", ""),
        "pred_patch": pred_patch or "",
        "test_passed": test_passed,
        "model_final_result": model_final,
        "golden_final_result": golden_final,
    }


def write_tmp_files(inst: dict) -> None:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    (TMP_DIR / "problem.txt").write_text(inst.get("problem_statement", ""), encoding="utf-8")
    (TMP_DIR / "golden_patch.diff").write_text(inst.get("golden_patch", ""), encoding="utf-8")
    (TMP_DIR / "test_patch.diff").write_text(inst.get("test_patch", ""), encoding="utf-8")


def build_judge_prompt(inst: dict) -> str:
    return """你是一个代码补丁与测试质量评判专家。请仅根据当前目录下的以下文件做结构化判断，不要推测或分析具体某次运行/某份提交的失败原因。

## 参考文件
- problem.txt       : 问题描述（problem statement）
- golden_patch.diff : 标准答案补丁（golden patch）
- test_patch.diff   : 测试用例补丁（test patch）

## 重要概念说明

1. **问题描述与 test patch 的关系**
   问题描述应当给出 test patch 的**充要条件**（即：满足描述当且仅当能通过测试）。
   - 若问题描述**不足**（缺少实现时应满足的约束或场景），导致按描述正确实现仍可能无法通过测试，则属**问题描述不清**。
   - 若问题描述**过于**添加了与通过测试无关的内容（多余约束、无关实现细节等），导致理解偏差或误判，也属**问题描述不清**。

2. **过窄测试**
   **过窄测试**指：使用了**过于严格的测试用例**，**强行限定具体实现细节**（例如硬编码新导入，要求代码更改必须使用某个特定名称等），导致许多在**功能上完全正确的**提交被判为无效。

   **重要豁免**：如果问题描述中已经**明确说明**了测试所检查的具体细节（如指定了函数名、变量名、错误信息格式、导入路径等），那么测试对这些细节做硬编码验证**不算过窄测试**——因为这些细节已经是需求的一部分，测试只是在如实验证问题描述中明确要求的行为。只有当测试硬编码了**问题描述中未提及的**实现细节时，才构成过窄测试。

## 需要判断的维度

1. **问题描述是否合理**
   - 问题描述是否构成 test patch 的充要条件？是否存在描述不足或描述中过多添加不需要内容的情况？是/否及简短理由。

2. **是否存在过窄测试**
   - 根据上述定义（含豁免条件）：测试是否过于严格、限定了**问题描述中未提及的**实现细节，导致功能正确的提交被误判为无效？是/否及简短说明。

请**仅**输出一个合法 JSON 对象，不要其他解释，格式如下（布尔用 true/false）：
{
  "problem_description_reasonable": true或false,
  "problem_description_reason": "一句话理由",
  "over_narrow_test": true或false,
  "over_narrow_reason": "一句话说明或空"
}
"""


def call_judge_via_cursor_agent(
    inst: dict,
    cursor_agent_cmd: str | None = None,
    verbose: bool = False,
) -> dict | None:
    write_tmp_files(inst)
    prompt_text = build_judge_prompt(inst)
    cmd = (cursor_agent_cmd or DEFAULT_CURSOR_AGENT_CMD).strip()

    if verbose:
        print(f"  [cursor-agent] cwd: {TMP_DIR}, cmd: {cmd}, prompt len: {len(prompt_text)}", file=sys.stderr)

    for attempt in range(3):
        try:
            proc = subprocess.run(
                [cmd, "--print", "--yolo", prompt_text],
                capture_output=True,
                text=True,
                timeout=120,
                cwd=TMP_DIR,
            )
            if proc.returncode != 0:
                print(
                    f"  [cursor-agent] exit {proc.returncode} (attempt {attempt+1}): {proc.stderr[:300]}",
                    file=sys.stderr,
                )
                if attempt < 2:
                    time.sleep(2 ** attempt)
                    continue
                return None
            text = proc.stdout.strip()
            if verbose:
                print(f"  [cursor-agent] reply (first 300): {text[:300]}", file=sys.stderr)
            result = parse_judge_response(text)
            if result is None and text:
                print(f"  [cursor-agent] JSON parse failed, raw:\n{text}", file=sys.stderr)
            return result
        except subprocess.TimeoutExpired:
            print(f"  [cursor-agent] timeout (attempt {attempt+1})", file=sys.stderr)
            if attempt < 2:
                time.sleep(2 ** attempt)
            else:
                return None
        except Exception as e:
            print(f"  [cursor-agent] error (attempt {attempt+1}): {type(e).__name__}: {e}", file=sys.stderr)
            if attempt < 2:
                time.sleep(2 ** attempt)
            else:
                return None
    return None


def _should_skip_instance(inst: dict) -> tuple[bool, str | None]:
    raw = inst.get("test_patch") or ""
    if len(raw) > 100000:
        return True, f"test_patch too large ({len(raw)} chars)"
    return False, None


def parse_judge_response(text: str) -> dict | None:
    text = (text or "").strip()
    m = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text)
    if m:
        text = m.group(1).strip()
    m = re.search(r"\{[\s\S]*\}", text)
    if m:
        text = m.group(0)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="对 v2 中被判为过窄测试的实例做二次评判（增加豁免条件），就地覆盖原文件"
    )
    parser.add_argument("--enhanced-swe", type=Path, default=None, help="增强 swe JSON 路径")
    parser.add_argument("--harness", type=Path, default=None, help="harness 结果 JSON（如 nl.json）")
    parser.add_argument("--preds-dir", type=Path, default=None, help="preds 轨迹目录")
    parser.add_argument("--v2-result", type=Path, default=None,
                        help="v2 评判结果 JSON（默认 result/strengthen/v2/test/judge_fail_only_result_v2.json）")
    parser.add_argument("--instance-ids", nargs="*", help="额外过滤：只重跑这些 instance_id（仍须是 over_narrow）")
    parser.add_argument("--cursor-agent-cmd", type=str, default=DEFAULT_CURSOR_AGENT_CMD)
    parser.add_argument("--limit", type=int, default=0, help="最多处理条数，0 表示不限制")
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("--no-resume", action="store_true", help="忽略已 retry 标记，对所有过窄实例重跑")
    args = parser.parse_args()

    enhanced_swe_path = args.enhanced_swe or DEFAULT_ENHANCED_SWE
    harness_path = args.harness or DEFAULT_HARNESS_RESULT
    preds_dir = args.preds_dir or DEFAULT_PREDS_DIR
    v2_path = args.v2_result or DEFAULT_V2_RESULT

    # 加载完整的 v2 结果列表
    all_records: list[dict] = _load_json(v2_path)
    if not isinstance(all_records, list) or not all_records:
        print(f"无法加载 v2 结果或为空: {v2_path}", file=sys.stderr)
        sys.exit(1)
    print(f"已加载 v2 结果共 {len(all_records)} 条", file=sys.stderr)

    # 找出需要重跑的 over_narrow 实例的索引
    narrow_indices: list[int] = []
    for idx, rec in enumerate(all_records):
        if rec.get("over_narrow_test") is not True:
            continue
        if not args.no_resume and rec.get(RETRIED_MARKER):
            continue
        if args.instance_ids and rec.get("instance_id") not in args.instance_ids:
            continue
        narrow_indices.append(idx)

    if args.limit > 0:
        narrow_indices = narrow_indices[: args.limit]

    if not narrow_indices:
        already_retried = sum(1 for r in all_records if r.get(RETRIED_MARKER))
        print(f"没有需要重跑的过窄实例（已 retry: {already_retried}）", file=sys.stderr)
        sys.exit(0)

    print(f"共 {len(narrow_indices)} 条过窄实例待二次评判", file=sys.stderr)

    # 构建 enhanced_swe 查找表
    swe_items = load_enhanced_swe(enhanced_swe_path)
    swe_by_id = {it["instance_id"]: it for it in swe_items if it.get("instance_id")}
    harness = load_harness_by_id(harness_path)

    def save_checkpoint() -> None:
        with open(v2_path, "w", encoding="utf-8") as f:
            json.dump(all_records, f, ensure_ascii=False, indent=2)

    total = len(narrow_indices)
    processed = 0
    try:
        for i, rec_idx in enumerate(narrow_indices):
            rec = all_records[rec_idx]
            iid = rec["instance_id"]

            swe_item = swe_by_id.get(iid)
            if not swe_item:
                print(f"[{i+1}/{total}] {iid} 跳过: enhanced_swe 中未找到", file=sys.stderr)
                continue

            inst = build_instance(swe_item, harness, preds_dir)
            if not inst:
                print(f"[{i+1}/{total}] {iid} 跳过: 构建实例失败", file=sys.stderr)
                continue

            skip, skip_reason = _should_skip_instance(inst)
            if skip:
                print(f"[{i+1}/{total}] {iid} 跳过: {skip_reason}", file=sys.stderr)
                continue

            print(f"[{i+1}/{total}] {iid} ...")
            judge = call_judge_via_cursor_agent(
                inst,
                cursor_agent_cmd=args.cursor_agent_cmd,
                verbose=args.verbose,
            )

            if judge is not None:
                rec["over_narrow_test"] = judge.get("over_narrow_test") is True
                rec["over_narrow_reason"] = judge.get("over_narrow_reason", "")
                rec["problem_description_reasonable"] = judge.get("problem_description_reasonable")
                rec["problem_description_reason"] = judge.get("problem_description_reason", "")
            rec[RETRIED_MARKER] = True

            processed += 1
            save_checkpoint()
            if processed % CHECKPOINT_EVERY == 0:
                print(f"  [checkpoint] 已处理 {processed}/{total} 条", file=sys.stderr)
    finally:
        save_checkpoint()

    print(f"完成：共处理 {processed}/{total} 条过窄实例，结果已写回 {v2_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
