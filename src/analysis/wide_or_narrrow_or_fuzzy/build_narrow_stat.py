#!/usr/bin/env python3
"""
统计 result/preds_result/strengthen/v2 下 kimi 与 glm 的 pass_rate.json，
不筛选语言：仅纳入 kimi 与 glm 两边均通过且在 all_nl 中的实例（含 C++）。
不要求必须是过窄：在 explain_over_narrow 中的用其 len(over_narrow_findings)，非过窄的 len 置为 0。
在 result/strengthen/v2 下生成 narrow_stat.json，包含：
  instance_id、language、problem_statement、html_url、len_over_narrow_findings、loc、num_files、num_non_test、num_test。
html_url 与 loc/num 来自 result/strengthen/v1/all_nl.json。
"""

import json
import sys
from pathlib import Path

# 项目根：脚本在 src/test/patch，parents[2] 为项目根
_SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = _SCRIPT_DIR.parents[2]

# 默认路径
V2_PREDS = PROJECT_ROOT / "result/preds_result/strengthen/v2"
KIMI_PASS_RATE = V2_PREDS / "kimi/pass_rate.json"
GLM_PASS_RATE = V2_PREDS / "glm/pass_rate.json"
V1_ALL_NL = PROJECT_ROOT / "result/strengthen/v1/all_nl.json"
V1_EXPLAIN_OVER_NARROW = PROJECT_ROOT / "result/strengthen/v1/explain_over_narrow_result.json"
V2_OUTPUT = PROJECT_ROOT / "result/strengthen/v2/narrow_stat.json"

def _load_json(path: Path) -> list | dict | None:
    if not path.exists():
        return None
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _pass_rate_by_id(path: Path) -> dict[str, dict]:
    """加载 pass_rate.json，返回 instance_id -> 单条记录。"""
    data = _load_json(path)
    if data is None or not isinstance(data, list):
        return {}
    return {item["instance_id"]: item for item in data if item.get("instance_id")}


def _is_passed(entry: dict) -> bool:
    """判断该条是否通过：兼容 passed 或 is_match，以及 model_info.passed。"""
    if entry.get("passed") is True or entry.get("is_match") is True:
        return True
    model_info = entry.get("model_info") or {}
    if model_info.get("passed") is True:
        return True
    # nl.json 格式：model.final_result == "success"
    model = entry.get("model") or {}
    if isinstance(model, dict) and (model.get("final_result") or "").strip().lower() == "success":
        return True
    return False


def main() -> None:
    # 1) 加载 kimi / glm pass_rate
    kimi_by_id = _pass_rate_by_id(KIMI_PASS_RATE)
    glm_by_id = _pass_rate_by_id(GLM_PASS_RATE)
    if not kimi_by_id:
        print(f"Warning: 未找到或为空: {KIMI_PASS_RATE}", file=sys.stderr)
    if not glm_by_id:
        print(f"Warning: 未找到或为空: {GLM_PASS_RATE}", file=sys.stderr)

    # 2) 两边都通过的 instance_id
    kimi_passed = {iid for iid, e in kimi_by_id.items() if _is_passed(e)}
    glm_passed = {iid for iid, e in glm_by_id.items() if _is_passed(e)}
    both_passed = kimi_passed & glm_passed

    # 3) 加载 v1 all_nl：language、html_url、problem_statement、loc/num
    all_nl_data = _load_json(V1_ALL_NL)
    if all_nl_data is None:
        all_nl_data = []
    if isinstance(all_nl_data, dict):
        all_nl_list = list(all_nl_data.values())
    else:
        all_nl_list = all_nl_data if isinstance(all_nl_data, list) else []
    all_nl_by_id = {item["instance_id"]: item for item in all_nl_list if item.get("instance_id")}
    all_nl_ids = set(all_nl_by_id.keys())

    # 4) 候选：两边均通过且在 all_nl 中（所有语言含 C++ 同此条件）
    both_passed_in_nl = both_passed & all_nl_ids
    candidate_ids = both_passed_in_nl

    # 5) 加载 explain_over_narrow_result (v1)：仅在其中的实例有 len；非过窄 len 置为 0
    explain_data = _load_json(V1_EXPLAIN_OVER_NARROW)
    if explain_data is None or not isinstance(explain_data, list):
        explain_list = []
    else:
        explain_list = explain_data
    explain_by_id = {rec["instance_id"]: rec for rec in explain_list if rec.get("instance_id")}

    # 6) 构建输出列表
    out = []
    for iid in sorted(candidate_ids):
        nl_item = all_nl_by_id.get(iid) or {}
        explain_rec = explain_by_id.get(iid)
        if explain_rec is not None:
            findings = explain_rec.get("over_narrow_findings")
            len_findings = len(findings) if isinstance(findings, list) else 0
        else:
            len_findings = 0
        out.append({
            "instance_id": iid,
            "language": (nl_item.get("language") or "").strip() or None,
            "problem_statement": nl_item.get("problem_statement", ""),
            "html_url": nl_item.get("html_url") or "",
            "len_over_narrow_findings": len_findings,
            "loc": nl_item.get("loc"),
            "num_files": nl_item.get("num_files"),
            "num_non_test": nl_item.get("num_non_test"),
            "num_test": nl_item.get("num_test"),
        })

    V2_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with open(V2_OUTPUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    # 简单统计
    print(f"kimi passed: {len(kimi_passed)}, glm passed: {len(glm_passed)}, both: {len(both_passed)}")
    print(f"both passed & in all_nl: {len(both_passed_in_nl)}")
    print(f"output (candidate): {len(out)}")
    lang_counts: dict[str, int] = {}
    for r in out:
        lang = (all_nl_by_id.get(r["instance_id"]) or {}).get("language", "").strip().lower() or "unknown"
        lang_counts[lang] = lang_counts.get(lang, 0) + 1
    for lang in sorted(lang_counts):
        print(f"  {lang}: {lang_counts[lang]}")
    print(f"Written: {V2_OUTPUT}")


if __name__ == "__main__":
    main()
