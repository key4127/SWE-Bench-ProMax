#!/usr/bin/env python3
"""
Patch 与问题描述评判脚本（利用 cursor-agent CLI）。

输入：与 src/backend 类似的数据源
  - 问题描述 problem_statement
  - test patch（test_patch）
  - 测试结果（是否通过、model/golden 的 final_result）

通过 cursor-agent CLI 判断：
  1. 问题描述是否合理？用例未通过是否与问题描述不充实、与 test patch 不相干等有关？
  2. 是否存在过宽/过窄测试？
     - 过宽：测试了问题描述中未提及/未详细说明/不够清晰的部分
     - 过窄：测试未覆盖问题描述要求的全部方面，或仅测了部分场景
  3. 问题描述是否与失败相关？

输出 JSON（保存到本地）：
  - test_passed: 是否测试通过
  - has_over_wide_or_over_narrow: 是否存在过宽或过窄测试
  - over_wide / over_narrow: 布尔及简要说明
  - problem_description_related_to_failure: 问题描述是否与失败相关
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
# 便于复用 backend 数据加载
sys.path.insert(0, str(PROJECT_ROOT / "src"))

# 默认路径（与 backend 一致）
DEFAULT_ENHANCED_SWE = PROJECT_ROOT / "result/strengthen/all_nl.json"
DEFAULT_PREDS_DIR = PROJECT_ROOT / "result/preds_result/kimi/nl"
DEFAULT_HARNESS_RESULT = PROJECT_ROOT / "result/harness_result/strengthen/kimi/nl.json"
# 输出目录：脚本所在目录
DEFAULT_OUTPUT_DIR = _SCRIPT_DIR
# cursor-agent 工作目录：每次调用前写入待评判文件
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
) -> list[dict]:
    """
    构建待评判实例列表。每条含：
    instance_id, problem_statement, golden_patch, test_patch, pred_patch,
    test_passed, model_final_result, golden_final_result
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
    """
    将当前实例的关键文件写入 TMP_DIR，供 cursor-agent 在该目录下读取。
      - problem.txt       : 问题描述
      - golden_patch.diff : 标准答案补丁
      - test_patch.diff   : 测试用例补丁
    """
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    (TMP_DIR / "problem.txt").write_text(inst.get("problem_statement", ""), encoding="utf-8")
    (TMP_DIR / "golden_patch.diff").write_text(inst.get("golden_patch", ""), encoding="utf-8")
    (TMP_DIR / "test_patch.diff").write_text(inst.get("test_patch", ""), encoding="utf-8")


def call_judge_via_cursor_agent(
    inst: dict,
    cursor_agent_cmd: str | None = None,
    verbose: bool = False,
) -> dict | None:
    """
    通过 cursor-agent CLI 发起一次评判，返回解析后的 JSON 字典，失败返回 None。
    每次调用前将相关文件写入 TMP_DIR，cursor-agent 在该目录下运行以信任并读取文件。
    """
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


def build_judge_prompt(inst: dict) -> str:
    """构建评判 prompt，引用当前目录下的文件（由 write_tmp_files 写入）。"""
    passed = inst.get("test_passed", False)
    model_res = inst.get("model_final_result", "")
    golden_res = inst.get("golden_final_result", "")

    return f"""你是一个代码补全与测试质量评判专家。请阅读当前目录下的以下文件并做结构化判断：

## 参考文件
- problem.txt       : 问题描述（problem statement）
- golden_patch.diff : 标准答案补丁（golden patch）
- test_patch.diff   : 测试用例补丁（test patch）

## 测试结果
- 用例是否通过：{"通过" if passed else "未通过"}
- 模型运行结果：{model_res or "（无）"}
- 标准答案运行结果：{golden_res or "（无）"}

## 需要判断的四个维度

1. **问题描述是否合理**
   - 若用例未通过，是否因为问题描述不够充实、与 test patch 无关、或描述含糊导致理解偏差？请给出是/否及简短理由。

2. **是否存在过宽测试**
   - 过宽：测试覆盖了问题描述中**未提及、未详细说明或不够清晰**的部分（即测试在"考"描述之外的东西）。是/否及简短说明。

3. **是否存在过窄测试**
   - 过窄：测试未覆盖问题描述所要求的**全部方面或关键场景**，只测了部分内容。是/否及简短说明。

4. **问题描述是否与失败相关**
   - 若用例未通过，问题描述是否与本次失败相关（例如描述不清、与测试不对齐导致被误判）？是/否及简短说明。

请**仅**输出一个合法 JSON 对象，不要其他解释，格式如下（布尔用 true/false）：
{{
  "problem_description_reasonable": true或false,
  "problem_description_reason": "一句话理由",
  "over_wide_test": true或false,
  "over_wide_reason": "一句话说明或空",
  "over_narrow_test": true或false,
  "over_narrow_reason": "一句话说明或空",
  "model_capability_related_to_failure": true或false,
  "model_capability_reason": "一句话说明",
  "problem_description_related_to_failure": true或false,
  "problem_description_failure_reason": "一句话说明"
}}
"""


def _should_skip_instance(inst: dict) -> tuple[bool, str | None]:
    """若 test_patch 超过 100000 字符（过大），跳过该实例。"""
    raw = inst.get("test_patch") or ""
    if len(raw) > 100000:
        return True, f"test_patch 过大（{len(raw)} 字符）"
    return False, None


def parse_judge_response(text: str) -> dict | None:
    """从模型回复中解析 JSON。"""
    text = (text or "").strip()
    # 尝试提取 ```json ... ``` 或首尾大括号
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
    """将单条实例与评判结果整理为输出 JSON 的一条记录。"""
    test_passed = inst.get("test_passed", False)
    over_wide = False
    over_narrow = False
    if judge:
        over_wide = judge.get("over_wide_test") is True
        over_narrow = judge.get("over_narrow_test") is True
    return {
        "instance_id": instance_id,
        "test_passed": test_passed,
        "has_over_wide_or_over_narrow": over_wide or over_narrow,
        "over_wide_test": over_wide,
        "over_wide_reason": (judge or {}).get("over_wide_reason", ""),
        "over_narrow_test": over_narrow,
        "over_narrow_reason": (judge or {}).get("over_narrow_reason", ""),
        "problem_description_related_to_failure": (judge or {}).get("problem_description_related_to_failure"),
        "problem_description_failure_reason": (judge or {}).get("problem_description_failure_reason", ""),
        "problem_description_reasonable": (judge or {}).get("problem_description_reasonable"),
        "problem_description_reason": (judge or {}).get("problem_description_reason", ""),
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Patch 与问题描述评判（cursor-agent CLI）")
    parser.add_argument("--enhanced-swe", type=Path, default=None, help="增强 swe JSON 路径")
    parser.add_argument("--harness", type=Path, default=None, help="harness 结果 JSON（如 nl.json）")
    parser.add_argument("--preds-dir", type=Path, default=None, help="preds 轨迹目录")
    parser.add_argument("--instance-ids", nargs="*", help="只处理这些 instance_id")
    parser.add_argument("--output", type=Path, default=None, help="输出 JSON 路径（默认脚本目录下 judge_result.json）")
    parser.add_argument("--cursor-agent-cmd", type=str, default=DEFAULT_CURSOR_AGENT_CMD, help="cursor-agent 命令（默认 cursor-agent）")
    parser.add_argument("--limit", type=int, default=0, help="最多处理条数，0 表示不限制")
    parser.add_argument("--verbose", action="store_true", help="输出详细的调试信息")
    args = parser.parse_args()

    enhanced_swe_path = args.enhanced_swe or DEFAULT_ENHANCED_SWE
    harness_path = args.harness or DEFAULT_HARNESS_RESULT
    preds_dir = args.preds_dir or DEFAULT_PREDS_DIR
    output_path = args.output or (DEFAULT_OUTPUT_DIR / "judge_result.json")

    instances = build_instances(
        enhanced_swe_path=enhanced_swe_path,
        harness_path=harness_path,
        preds_dir=preds_dir,
        instance_ids=args.instance_ids or None,
    )
    if args.limit > 0:
        instances = instances[: args.limit]
    if not instances:
        print("没有可处理的实例。", file=sys.stderr)
        sys.exit(1)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    def save_checkpoint(results_list: list) -> None:
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results_list, f, ensure_ascii=False, indent=2)

    results = []
    try:
        for i, inst in enumerate(instances):
            iid = inst["instance_id"]
            skip, skip_reason = _should_skip_instance(inst)
            if skip:
                print(f"[{i+1}/{len(instances)}] {iid} 跳过: {skip_reason}", file=sys.stderr)
                continue

            print(f"[{i+1}/{len(instances)}] {iid} ...")
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
                print(f"  [checkpoint] 已保存 {len(results)} 条到 {output_path}")
    finally:
        pass

    save_checkpoint(results)
    print(f"已写入 {len(results)} 条到 {output_path}")


if __name__ == "__main__":
    main()
