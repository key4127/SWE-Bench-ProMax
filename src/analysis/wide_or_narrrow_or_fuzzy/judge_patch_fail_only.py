#!/usr/bin/env python3
"""
仅对 pred patch 未通过的实例做评判（利用 cursor-agent CLI）。

与 judge_patch 的区别：
  - 只处理 test_passed=False 的实例。
  - 去掉「过宽测试」判断。
  - 「过窄测试」正确定义：使用了过于严格的测试用例，强行限定具体实现细节，
    导致许多在功能上完全正确的提交被判为无效（而非“测试与问题描述覆盖关系”）。
  - 问题描述应是 test patch 的充要条件：描述不足或过于添加不需要的内容，
    都视为问题描述不清。

输入/数据源：与 src/test/patch/judge_patch.py 一致。
输出 JSON：不含 over_wide，仅含 over_narrow 及问题描述相关字段。
"""

import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

# 项目根：脚本在 src/test/patch，parents[2] 为项目根
_SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = _SCRIPT_DIR.parents[2]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

DEFAULT_ENHANCED_SWE = PROJECT_ROOT / "result/strengthen/v2/all_nl_enhanced.json"
DEFAULT_PREDS_DIR = PROJECT_ROOT / "result/preds_result/kimi/nl"
DEFAULT_HARNESS_RESULT = PROJECT_ROOT / "result/harness_result/strengthen/kimi/nl.json"
DEFAULT_OUTPUT_DIR = _SCRIPT_DIR
TMP_DIR = _SCRIPT_DIR / "tmp"

DEFAULT_CURSOR_AGENT_CMD = "cursor-agent"
CHECKPOINT_EVERY = 10


def _load_json(path: Path) -> Any:
    if not path or not path.exists():
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_enhanced_swe(path: Path | None) -> list[dict]:
    """加载增强 swe：列表项含 instance_id, problem_statement, patch, test_patch。"""
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
    """加载 harness 结果（nl.json 等），instance_id -> 原始结果。"""
    path = path or DEFAULT_HARNESS_RESULT
    data = _load_json(path)
    if data is None or not isinstance(data, list):
        return {}
    return {item["instance_id"]: item for item in data if item.get("instance_id")}


def load_pred_patch(instance_id: str, preds_dir: Path | None) -> str | None:
    """从 preds 目录加载该 instance 的模型 patch。"""
    preds_dir = preds_dir or DEFAULT_PREDS_DIR
    traj_path = preds_dir / instance_id / f"{instance_id}.traj.json"
    if not traj_path.exists():
        return None
    data = _load_json(traj_path)
    if not data or not isinstance(data, dict):
        return None
    info = data.get("info") or {}
    return info.get("submission") or None


def build_instances(
    enhanced_swe_path: Path | None = None,
    harness_path: Path | None = None,
    preds_dir: Path | None = None,
    instance_ids: list[str] | None = None,
    fail_only: bool = True,
) -> list[dict]:
    """
    构建待评判实例列表。每条含：
    instance_id, problem_statement, golden_patch, test_patch, pred_patch,
    test_passed, model_final_result, golden_final_result
    若 fail_only=True，仅保留 pred patch 未通过（test_passed=False）的实例。
    """
    items = load_enhanced_swe(enhanced_swe_path)
    harness = load_harness_by_id(harness_path)
    if instance_ids:
        items = [it for it in items if it.get("instance_id") in instance_ids]
    out = []
    for it in items:
        iid = it.get("instance_id")
        if not iid:
            continue
        raw = harness.get(iid) or {}
        model_obj = raw.get("model") or {}
        golden_obj = raw.get("golden") or {}
        model_final = (model_obj.get("final_result") or "").strip()
        golden_final = (golden_obj.get("final_result") or "").strip()
        test_passed = raw.get("passed") is True
        if fail_only and test_passed:
            continue
        pred_patch = load_pred_patch(iid, preds_dir)
        out.append({
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
        })
    return out


def write_tmp_files(inst: dict) -> None:
    """将当前实例的关键文件写入 TMP_DIR，供 cursor-agent 读取。不写入 pred 或任何运行结果，避免误导。"""
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    (TMP_DIR / "problem.txt").write_text(inst.get("problem_statement", ""), encoding="utf-8")
    (TMP_DIR / "golden_patch.diff").write_text(inst.get("golden_patch", ""), encoding="utf-8")
    (TMP_DIR / "test_patch.diff").write_text(inst.get("test_patch", ""), encoding="utf-8")


def build_judge_prompt(inst: dict) -> str:
    """
    构建评判 prompt。不包含任何 pred/运行结果信息，仅基于问题描述、golden、test patch 做客观评判。
    """
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
   
## 需要判断的维度

1. **问题描述是否合理**
   - 问题描述是否构成 test patch 的充要条件？是否存在描述不足或描述中过多添加不需要内容的情况？是/否及简短理由。

2. **是否存在过窄测试**
   - 根据上述定义：测试是否过于严格、限定实现细节，导致功能正确的提交被误判为无效？是/否及简短说明。

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
    """通过 cursor-agent CLI 发起一次评判，返回解析后的 JSON，失败返回 None。"""
    write_tmp_files(inst)
    prompt_text = build_judge_prompt(inst)
    cmd = (cursor_agent_cmd or DEFAULT_CURSOR_AGENT_CMD).strip()

    if verbose:
        print(f"  [cursor-agent] cwd: {TMP_DIR}，命令: {cmd}，prompt 长度: {len(prompt_text)} 字符", file=sys.stderr)

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
                    f"  [cursor-agent] 退出码 {proc.returncode}（第{attempt+1}次）: {proc.stderr[:300]}",
                    file=sys.stderr,
                )
                if attempt < 2:
                    time.sleep(2 ** attempt)
                    continue
                return None
            text = proc.stdout.strip()
            if verbose:
                print(f"  [cursor-agent] 回复（前 300 字符）: {text[:300]}", file=sys.stderr)
            result = parse_judge_response(text)
            if result is None and text:
                print(f"  [cursor-agent] JSON 解析失败，原始全文:\n{text}", file=sys.stderr)
            return result
        except subprocess.TimeoutExpired:
            print(f"  [cursor-agent] 超时（第{attempt+1}次）", file=sys.stderr)
            if attempt < 2:
                time.sleep(2 ** attempt)
            else:
                return None
        except Exception as e:
            print(f"  [cursor-agent] 失败（第{attempt+1}次）: {type(e).__name__}: {e}", file=sys.stderr)
            if attempt < 2:
                time.sleep(2 ** attempt)
            else:
                return None
    return None


def _should_skip_instance(inst: dict) -> tuple[bool, str | None]:
    """若 test_patch 过大则跳过。"""
    raw = inst.get("test_patch") or ""
    if len(raw) > 100000:
        return True, f"test_patch 过大（{len(raw)} 字符）"
    return False, None


def parse_judge_response(text: str) -> dict | None:
    """从模型回复中解析 JSON。"""
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


def to_output_record(instance_id: str, inst: dict, judge: dict | None) -> dict:
    """将单条实例与评判结果整理为输出记录（无 over_wide、无失败原因相关字段）。"""
    test_passed = inst.get("test_passed", False)
    over_narrow = (judge or {}).get("over_narrow_test") is True
    return {
        "instance_id": instance_id,
        "test_passed": test_passed,
        "over_narrow_test": over_narrow,
        "over_narrow_reason": (judge or {}).get("over_narrow_reason", ""),
        "problem_description_reasonable": (judge or {}).get("problem_description_reasonable"),
        "problem_description_reason": (judge or {}).get("problem_description_reason", ""),
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="仅对 pred 未通过的实例做 patch/问题描述评判（无过宽判断，过窄定义已修正）"
    )
    parser.add_argument("--enhanced-swe", type=Path, default=None, help="增强 swe JSON 路径")
    parser.add_argument("--harness", type=Path, default=None, help="harness 结果 JSON（如 nl.json）")
    parser.add_argument("--preds-dir", type=Path, default=None, help="preds 轨迹目录")
    parser.add_argument("--instance-ids", nargs="*", help="只处理这些 instance_id（仍仅保留未通过者）")
    parser.add_argument("--output", type=Path, default=None, help="输出 JSON 路径（默认脚本目录下 judge_fail_only_result.json）")
    parser.add_argument("--cursor-agent-cmd", type=str, default=DEFAULT_CURSOR_AGENT_CMD, help="cursor-agent 命令")
    parser.add_argument("--limit", type=int, default=0, help="最多处理条数，0 表示不限制")
    parser.add_argument("--verbose", action="store_true", help="输出详细调试信息")
    parser.add_argument("--no-fail-only", action="store_true", help="若设置则也处理已通过的实例（默认仅处理未通过）")
    parser.add_argument("--no-resume", action="store_true", help="不从已有输出恢复，从头跑并覆盖输出文件")
    args = parser.parse_args()

    enhanced_swe_path = args.enhanced_swe or DEFAULT_ENHANCED_SWE
    harness_path = args.harness or DEFAULT_HARNESS_RESULT
    preds_dir = args.preds_dir or DEFAULT_PREDS_DIR
    output_path = args.output or (DEFAULT_OUTPUT_DIR / "judge_fail_only_result_v2.json")

    instances = build_instances(
        enhanced_swe_path=enhanced_swe_path,
        harness_path=harness_path,
        preds_dir=preds_dir,
        instance_ids=args.instance_ids or None,
        fail_only=not args.no_fail_only,
    )
    if args.limit > 0:
        instances = instances[: args.limit]
    if not instances:
        print("没有可处理的实例（默认仅包含 pred 未通过的实例）。", file=sys.stderr)
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    def save_checkpoint(results_list: list) -> None:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results_list, f, ensure_ascii=False, indent=2)

    # 断点续跑：加载已有结果，只处理尚未有结果的 instance
    results: list[dict] = []
    instances_todo: list[dict] = instances
    if not args.no_resume and output_path.exists():
        existing_list = _load_json(output_path)
        if isinstance(existing_list, list) and existing_list:
            existing_by_id = {r["instance_id"]: r for r in existing_list if r.get("instance_id")}
            # 保持与当前 instances 顺序一致，只保留仍在本轮列表中的已有记录
            results = [existing_by_id[iid] for inst in instances if (iid := inst["instance_id"]) in existing_by_id]
            instances_todo = [inst for inst in instances if inst["instance_id"] not in existing_by_id]
            if instances_todo:
                print(f"[resume] 已加载 {len(results)} 条，剩余 {len(instances_todo)} 条待处理", file=sys.stderr)
            else:
                print(f"[resume] 已全部完成（共 {len(results)} 条），无需继续", file=sys.stderr)
                save_checkpoint(results)
                return

    total = len(instances)
    # 进入循环时已完成的条数（用于打印序号，循环内 results 会 append 故不能再用 len(results)）
    done_before_loop = len(results)
    try:
        for i, inst in enumerate(instances_todo):
            iid = inst["instance_id"]
            idx_in_all = done_before_loop + i + 1  # 在全部实例中的 1-based 序号
            skip, skip_reason = _should_skip_instance(inst)
            if skip:
                print(f"[{idx_in_all}/{total}] {iid} 跳过: {skip_reason}", file=sys.stderr)
                continue

            print(f"[{idx_in_all}/{total}] {iid} ...")
            judge = call_judge_via_cursor_agent(
                inst,
                cursor_agent_cmd=args.cursor_agent_cmd,
                verbose=args.verbose,
            )
            rec = to_output_record(iid, inst, judge)
            results.append(rec)
            save_checkpoint(results)
            if len(results) % CHECKPOINT_EVERY == 0:
                save_checkpoint(results)
                print(f"  [checkpoint] 已保存 {len(results)} 条到 {output_path}", file=sys.stderr)
    finally:
        pass

    save_checkpoint(results)
    print(f"已写入 {len(results)} 条到 {output_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
