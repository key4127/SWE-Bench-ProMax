#!/usr/bin/env python3
"""
从 explain_over_narrow_result.json 中读取「失败」的案例（analysis_failed=True 或
缺少/空的 over_narrow_findings），仅对这些 instance_id 重新调用 cursor-agent，
为它们重新生成过窄测试的结构化说明。

用法：
  python explain_over_narrow_retry_failed.py
  python explain_over_narrow_retry_failed.py --result explain_over_narrow_result.json --output explain_over_narrow_retry_result.json
  python explain_over_narrow_retry_failed.py --merge   # 重跑后把新结果合并回原 result 文件
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Dict, List

# 项目根：脚本在 src/test/patch，parents[2] 为项目根
_SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = _SCRIPT_DIR.parents[2]

sys.path.insert(0, str(PROJECT_ROOT / "src"))

DEFAULT_ENHANCED_SWE = PROJECT_ROOT / "result/strengthen/all_nl.json"
DEFAULT_JUDGE_RESULT = _SCRIPT_DIR / "judge_result.json"
DEFAULT_RESULT_PATH = _SCRIPT_DIR / "explain_over_narrow_result.json"
DEFAULT_OUTPUT_PATH = _SCRIPT_DIR / "explain_over_narrow_retry_result.json"
TMP_DIR = _SCRIPT_DIR / "tmp_explain_over_narrow"

DEFAULT_CURSOR_AGENT_CMD = "cursor-agent"
CHECKPOINT_EVERY = 10


def _load_json(path: Path) -> Any:
    if not path or not path.exists():
        return None
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def load_failed_instance_ids_from_result(path: Path) -> List[str]:
    """
    从已有的 explain_over_narrow_result.json 中提取「失败」的 instance_id：
    - analysis_failed == True，或
    - 没有 over_narrow_findings 或 over_narrow_findings 为空列表。
    """
    data = _load_json(path)
    if data is None or not isinstance(data, list):
        return []
    out: List[str] = []
    for rec in data:
        try:
            iid = rec.get("instance_id")
            if not isinstance(iid, str):
                continue
            if rec.get("analysis_failed") is True:
                out.append(iid)
                continue
            findings = rec.get("over_narrow_findings")
            if not isinstance(findings, list) or len(findings) == 0:
                out.append(iid)
        except (AttributeError, TypeError):
            continue
    return out


def load_enhanced_swe(path: Path | None) -> List[Dict[str, Any]]:
    """
    加载增强 swe：列表项至少包含 instance_id, patch (golden_patch), test_patch。
    结构与 judge_patch_fail_only.py 保持一致。
    """
    path = path or DEFAULT_ENHANCED_SWE
    data = _load_json(path)
    if data is None:
        return []
    if isinstance(data, list):
        return data  # type: ignore[return-value]
    if isinstance(data, dict):
        return list(data.values())  # type: ignore[return-value]
    return []


def load_judge_over_narrow_ids(path: Path | None) -> List[str]:
    """
    从 judge_result.json 中提取被标记为 over_narrow_test=True 的 instance_id 列表。
    """
    path = path or DEFAULT_JUDGE_RESULT
    data = _load_json(path)
    if data is None or not isinstance(data, list):
        return []
    out: List[str] = []
    for rec in data:
        try:
            if rec.get("over_narrow_test") is True and isinstance(rec.get("instance_id"), str):
                out.append(rec["instance_id"])
        except AttributeError:
            continue
    return out


def build_instances(
    enhanced_swe_path: Path | None = None,
    judge_path: Path | None = None,
    instance_ids: List[str] | None = None,
) -> List[Dict[str, Any]]:
    """
    构建待分析实例列表。每条包含：
      - instance_id
      - repo
      - base_commit
      - golden_patch
      - test_patch

    仅保留在 judge_result.json 中被标记为 over_narrow_test=True 的实例。
    若传入 instance_ids，则进一步在上述集合上取交集。
    """
    items = load_enhanced_swe(enhanced_swe_path)
    over_narrow_ids = set(load_judge_over_narrow_ids(judge_path))
    if not over_narrow_ids:
        return []

    if instance_ids:
        allow = set(instance_ids)
        over_narrow_ids &= allow
        if not over_narrow_ids:
            return []

    out: List[Dict[str, Any]] = []
    for it in items:
        iid = it.get("instance_id")
        if not isinstance(iid, str):
            continue
        if iid not in over_narrow_ids:
            continue
        out.append(
            {
                "instance_id": iid,
                "repo": it.get("repo", ""),
                "base_commit": it.get("base_commit", ""),
                "golden_patch": it.get("patch", ""),
                "test_patch": it.get("test_patch", ""),
            }
        )
    return out


def write_tmp_files(inst: Dict[str, Any]) -> None:
    """
    将当前实例的 golden_patch 与 test_patch 写入 TMP_DIR，供 cursor-agent 读取。
    """
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    (TMP_DIR / "golden_patch.diff").write_text(inst.get("golden_patch", ""), encoding="utf-8")
    (TMP_DIR / "test_patch.diff").write_text(inst.get("test_patch", ""), encoding="utf-8")


def build_explain_prompt(inst: Dict[str, Any]) -> str:
    """
    构建对「过窄测试」做结构化解释的 prompt。
    """
    iid = inst.get("instance_id", "")
    repo = inst.get("repo", "")
    return f"""你是一个代码测试质量分析专家。

## 背景

当前目录下有两个补丁文件：
- golden_patch.diff : 标准答案补丁（实现修复的参考方案）
- test_patch.diff   : 针对该问题编写的测试补丁

这条实例已被上游标记为「过窄测试」(over_narrow_test = true)。

## 「过窄测试」的精确定义

**过窄测试**是指：测试用例使用了**过于严格的断言或检查方式**，**强行限定了具体实现细节**，
导致许多在**功能上完全正确**的提交被判为无效。

**核心判断标准**：假设一个开发者用**不同但功能等价的方式**解决了同一问题（比如使用不同的
函数名、不同的错误消息措辞、不同的内部数据结构、不同的 API 签名），测试是否会因此失败？
如果会，那就是过窄测试的体现。

典型表现包括但不限于：
- 断言要求错误消息或输出必须是某个**精确字符串**（如 `assert msg == "Missing fractions after '.'."`），
  而不是检查语义是否正确或是否包含关键信息
- 通过**导入或实例化特定命名**的类/函数/模块来验证（如 `from impl import SpecificClass`），
  一个使用不同命名但功能等价的实现会直接 ImportError
- 检查**内部实现细节**而非外部可观察行为（如断言私有属性 `obj._internal_field`、
  要求结构体字段必须叫某个名字）
- 硬编码**特定文件路径、配置键名、头文件路径**等实现选择
- 要求使用某个**特定的 API 调用方式**，而不接受功能等价的替代实现
  （如测试直接调用 `s2n_policy_strict()` 而非通过行为验证）

## 关键区分：什么算过窄，什么不算

**不算过窄**的情况——测试引用的是**代码库中原已存在**的类、函数、模块、API 等：
- 如果某个类名/函数名/头文件在 golden_patch.diff 的改动中**没有出现**（即不在 `+` 行中），
  说明它是仓库原有的公共接口，测试使用它是合理的，**不应标记为过窄**。
- 同理，如果 golden_patch.diff 只是修改了一个已有函数的内部实现（而非新建函数），
  测试通过调用该已有函数来验证行为是正常的测试写法。

**算过窄**的情况——测试强行绑定了 golden patch **新引入**的实现细节：
- golden_patch.diff 的 `+` 行中新建了某个类名/函数名/枚举名/结构体字段名，
  而 test_patch.diff 直接引用该名称做断言——换一个等价的命名方案就会失败。
- golden_patch.diff 新增了某段特定措辞的错误消息，test_patch.diff 对其做精确字符串匹配——
  换一种语义等价但措辞不同的消息就会失败。
- test_patch.diff 中新增了对 golden patch 引入的内部数据结构、私有属性、文件路径等的直接检查。

**简单判断方法**：查看 test_patch.diff 中引用的名称/字符串/路径，
若它同时出现在 golden_patch.diff 的 `+` 行（新增内容）中，则很可能是对新引入实现细节的绑定，属于过窄。
若它不在 golden_patch.diff 的改动范围内，则大概率是原有接口，不算过窄。

## 你的任务

请仔细阅读 test_patch.diff 与 golden_patch.diff，按照上述区分标准，
找出 test_patch.diff 中所有体现「过窄」的具体位置和写法。

对于每一处过窄的体现，请回答：
1. 测试中**具体做了什么**（引用相关代码或断言）
2. 这为什么是过窄的——即一个**功能正确但实现不同的方案**会如何因此失败

## 输出格式

请严格按照以下 JSON 格式输出：
{{
  "instance_id": "{iid}",
  "repo": "{repo}",
  "over_narrow_findings": [
    {{
      "category": "分类标签（见下方枚举）",
      "file": "test_patch.diff 中涉及的文件路径（从 diff header 中提取，如 tests/test_foo.py）",
      "symbol": "被过窄绑定的具体名称或值（如类名、函数名、枚举值、精确字符串、文件路径等）",
      "constraint": "测试要求什么必须为什么（如：错误消息必须为 \"Missing fractions after '.'.\"、结构体字段必须命名为 motorProtocol）"
    }}
  ]
}}

**category** 必须为以下之一：
- "exact_string_match"   : 要求输出、错误消息、日志等必须是精确字符串或精确子串
- "hardcoded_name"       : 强制使用特定的类名、函数名、方法名、变量名、属性名、枚举名或结构体字段名
- "import_dependency"    : 强制从特定路径导入，或依赖特定的模块/头文件结构
- "internal_structure"   : 检查内部数据结构布局、私有 API、或假定特定的字段组织方式
- "file_path_dependency" : 依赖特定的文件路径、文件名或目录结构
- "specific_api_usage"   : 强制使用某个特定 API 或调用方式，而非接受功能等价的替代
- "output_format"        : 对输出格式有过于严格的约束（如精确的空格、换行、排序、前后缀）
- "other"                : 以上未覆盖的其它实现细节约束（如强制 sleep 时间、线程数、magic number 等）

要求：
- 该实例已确认为过窄测试，over_narrow_findings 列表不应为空。
- 若有多处过窄体现，请逐一列出，不要合并。
- JSON 中除上述字段外不要添加多余字段。
- 只输出纯 JSON，不要使用 Markdown 代码块包裹，不要输出任何 JSON 以外的文字。
"""


def parse_agent_json(text: str) -> Dict[str, Any] | None:
    """
    从 cursor-agent 的回复中提取 JSON。
    兼容 ```json ... ``` 包裹或裸 JSON。
    """
    text = (text or "").strip()
    m = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", text)
    if m:
        text = m.group(1).strip()
    m = re.search(r"\{[\s\S]*\}", text)
    if m:
        text = m.group(0)
    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return obj
        return None
    except json.JSONDecodeError:
        return None


def call_cursor_agent(
    inst: Dict[str, Any],
    cursor_agent_cmd: str | None = None,
    verbose: bool = False,
) -> Dict[str, Any] | None:
    """调用 cursor-agent，对单个实例做一次说明。"""
    write_tmp_files(inst)
    prompt_text = build_explain_prompt(inst)
    cmd = (cursor_agent_cmd or DEFAULT_CURSOR_AGENT_CMD).strip()

    if verbose:
        print(
            f"  [cursor-agent] cwd: {TMP_DIR}，命令: {cmd}，prompt 长度: {len(prompt_text)} 字符",
            file=sys.stderr,
        )

    for attempt in range(3):
        try:
            proc = subprocess.run(
                [cmd, "--print", "--yolo", prompt_text],
                capture_output=True,
                text=True,
                timeout=300,
                cwd=TMP_DIR,
            )
            if proc.returncode != 0:
                print(
                    f"  [cursor-agent] 退出码 {proc.returncode}（第{attempt+1}次）: {proc.stderr[:300]}",
                    file=sys.stderr,
                )
                if attempt < 2:
                    time.sleep(2**attempt)
                    continue
                return None
            text = proc.stdout.strip()
            if verbose:
                print(f"  [cursor-agent] 回复（前 300 字符）: {text[:300]}", file=sys.stderr)
            result = parse_agent_json(text)
            if result is None and text:
                print(f"  [cursor-agent] JSON 解析失败，原始全文:\n{text}", file=sys.stderr)
            return result
        except subprocess.TimeoutExpired:
            print(f"  [cursor-agent] 超时（第{attempt+1}次）", file=sys.stderr)
            if attempt < 2:
                time.sleep(2**attempt)
            else:
                return None
        except Exception as e:  # noqa: BLE001
            print(f"  [cursor-agent] 失败（第{attempt+1}次）: {type(e).__name__}: {e}", file=sys.stderr)
            if attempt < 2:
                time.sleep(2**attempt)
            else:
                return None
    return None


def to_output_record(inst: Dict[str, Any], analysis: Dict[str, Any] | None) -> Dict[str, Any]:
    """整理成输出记录，方便后续在 Cursor 中浏览。"""
    iid = inst.get("instance_id", "")
    repo = inst.get("repo", "")
    base_commit = inst.get("base_commit", "")

    base = {
        "instance_id": iid,
        "repo": repo,
        "base_commit": base_commit,
    }
    if not analysis:
        base["analysis_failed"] = True
        return base

    base.update(analysis)
    return base


def merge_retry_into_result(original_path: Path, retry_results: List[Dict[str, Any]]) -> None:
    """
    将本次重跑结果按 instance_id 合并回原 result 文件：
    原列表中若某条的 instance_id 在 retry_results 中出现，则用新结果替换该条。
    """
    original = _load_json(original_path)
    if not isinstance(original, list):
        return
    by_id: Dict[str, Dict[str, Any]] = {rec.get("instance_id"): rec for rec in retry_results if rec.get("instance_id")}
    merged: List[Dict[str, Any]] = []
    for rec in original:
        iid = rec.get("instance_id")
        if iid in by_id:
            merged.append(by_id[iid])
        else:
            merged.append(rec)
    with original_path.open("w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "从 explain_over_narrow_result.json 中读取失败案例，"
            "仅对这些 instance_id 重新调用 cursor-agent 生成过窄测试说明。"
        )
    )
    parser.add_argument(
        "--result",
        type=Path,
        default=DEFAULT_RESULT_PATH,
        help="已有的 explain 结果 JSON，从中提取失败案例（默认：脚本目录下 explain_over_narrow_result.json）",
    )
    parser.add_argument(
        "--enhanced-swe",
        type=Path,
        default=None,
        help="增强 swe JSON 路径（默认：result/strengthen/all_nl.json）",
    )
    parser.add_argument(
        "--judge",
        type=Path,
        default=None,
        help="包含 over_narrow_test 字段的评判结果 JSON（默认：脚本目录下 judge_result.json）",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="重跑结果输出路径（默认：explain_over_narrow_retry_result.json）",
    )
    parser.add_argument(
        "--cursor-agent-cmd",
        type=str,
        default=DEFAULT_CURSOR_AGENT_CMD,
        help="cursor-agent 命令（默认：cursor-agent）",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="最多处理条数，0 表示不限制",
    )
    parser.add_argument(
        "--merge",
        action="store_true",
        help="重跑完成后，将新结果按 instance_id 合并回 --result 文件",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="输出详细调试信息",
    )
    args = parser.parse_args()

    result_path = args.result
    enhanced_swe_path = args.enhanced_swe or DEFAULT_ENHANCED_SWE
    judge_path = args.judge or DEFAULT_JUDGE_RESULT
    output_path = args.output or DEFAULT_OUTPUT_PATH

    failed_ids = load_failed_instance_ids_from_result(result_path)
    if not failed_ids:
        print(
            f"在 {result_path} 中未发现失败案例（无 analysis_failed 且无空 over_narrow_findings）。",
            file=sys.stderr,
        )
        sys.exit(0)

    print(f"从 {result_path} 中读取到 {len(failed_ids)} 个失败案例，将重新生成。", file=sys.stderr)

    instances = build_instances(
        enhanced_swe_path=enhanced_swe_path,
        judge_path=judge_path,
        instance_ids=failed_ids,
    )
    if not instances:
        print(
            "失败案例在 judge_result 或增强 swe 中无对应数据，无法构建实例。",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.limit > 0:
        instances = instances[: args.limit]
    output_path.parent.mkdir(parents=True, exist_ok=True)

    def save_checkpoint(results_list: List[Dict[str, Any]]) -> None:
        with output_path.open("w", encoding="utf-8") as f:
            json.dump(results_list, f, ensure_ascii=False, indent=2)

    results: List[Dict[str, Any]] = []
    try:
        for i, inst in enumerate(instances):
            iid = inst.get("instance_id", "")
            print(f"[{i+1}/{len(instances)}] {iid} ...")
            analysis = call_cursor_agent(
                inst,
                cursor_agent_cmd=args.cursor_agent_cmd,
                verbose=args.verbose,
            )
            rec = to_output_record(inst, analysis)
            results.append(rec)
            save_checkpoint(results)
            if len(results) % CHECKPOINT_EVERY == 0:
                print(f"  [checkpoint] 已保存 {len(results)} 条到 {output_path}")
    finally:
        pass

    save_checkpoint(results)
    print(f"已写入 {len(results)} 条到 {output_path}")

    if args.merge and results:
        merge_retry_into_result(result_path, results)
        print(f"已合并 {len(results)} 条重跑结果回 {result_path}")


if __name__ == "__main__":
    main()
