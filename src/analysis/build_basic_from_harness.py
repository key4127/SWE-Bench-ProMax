"""
从 result/harness_result/strengthen 下读取指定 json，
与 result/harness_result/gpt-5-mini 下所有 batch 结果求 id 交集，
从 gpt-5-mini 的 batch 中保留 id 相同的条目，写出为 basic.json（baseline），
并在 stdout 输出统计（格式参考 test_run.print_pass_rate_summary）。
所有路径与文件名写死，无命令行参数。
"""
import json
import os

# 写死路径（注意目录名为 strengthen，非 strenghen）
STRENGTHEN_DIR = "result/harness_result/strengthen"
STRENGTHEN_JSON = "mkd.json"
GPT5_MINI_DIR = "result/harness_result/gpt-5-mini"
BASIC_JSON = "basic.json"


def _ensure_abs_path(rel_path: str) -> str:
    """相对路径基于项目根（本脚本所在位置：src/pipeline/strengthen）."""
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    return os.path.join(root, rel_path)


def _load_list_from_json(path: str) -> list:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    return list(data.values()) if isinstance(data, dict) else []


def _collect_instance_ids(results: list) -> set:
    ids = set()
    for r in results:
        iid = r.get("instance_id")
        if iid is not None:
            ids.add(iid)
    return ids


def print_pass_rate_summary(results_list: list, lang_map: dict) -> None:
    """与 src/harness/test_run.print_pass_rate_summary 一致."""
    total = sum(1 for r in results_list if r.get("golden", {}).get("final_result") == "success")
    if total == 0:
        print("\nNo results to summarize.")
        return

    passed = sum(1 for r in results_list if r.get("passed", False))
    print(f"\n{'='*60}")
    print(f"  Overall: {passed}/{total} passed ({100*passed/total:.1f}%)")
    print(f"{'='*60}")

    lang_stats = {}
    for r in results_list:
        if r.get("golden", {}).get("final_result") != "success":
            continue
        lang = lang_map.get(r.get("instance_id"), "unknown")
        stats = lang_stats.setdefault(lang, {"total": 0, "passed": 0})
        stats["total"] += 1
        if r.get("passed", False):
            stats["passed"] += 1

    print(f"  {'Language':<15} {'Passed':>8} {'Total':>8} {'Rate':>8}")
    print(f"  {'-'*15} {'-'*8} {'-'*8} {'-'*8}")
    for lang in sorted(lang_stats, key=lambda l: -lang_stats[l]["total"]):
        s = lang_stats[lang]
        rate = 100 * s["passed"] / s["total"] if s["total"] else 0
        print(f"  {lang:<15} {s['passed']:>8} {s['total']:>8} {rate:>7.1f}%")

    reason_counts = {}
    for r in results_list:
        reason = r.get("model", {}).get("final_result", "unknown")
        reason_counts[reason] = reason_counts.get(reason, 0) + 1
    total_results = len(results_list)

    print(f"\n  Results:")
    for reason, count in sorted(reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_results if total_results else 0
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")
    print(f"{'='*60}")


def main() -> None:
    root = _ensure_abs_path(".")
    strengthen_path = os.path.join(root, STRENGTHEN_DIR, STRENGTHEN_JSON)
    gpt5_mini_path = os.path.join(root, GPT5_MINI_DIR)
    basic_path = os.path.join(root, STRENGTHEN_DIR, BASIC_JSON)

    strengthen_list = _load_list_from_json(strengthen_path)
    strengthen_ids = _collect_instance_ids(strengthen_list)

    # 从所有 batch 合并 gpt-5-mini 结果，id -> 条目（后出现的覆盖）
    gpt5_mini_id2entry = {}
    for name in sorted(os.listdir(gpt5_mini_path)):
        if name.startswith("batch") and name.endswith(".json"):
            batch_path = os.path.join(gpt5_mini_path, name)
            batch_list = _load_list_from_json(batch_path)
            for r in batch_list:
                iid = r.get("instance_id")
                if iid is not None:
                    gpt5_mini_id2entry[iid] = r

    common_ids = strengthen_ids & set(gpt5_mini_id2entry.keys())
    # 按 strengthen 顺序，从 batch 里取对应条目组成 basic（保留的是 gpt-5-mini 的结果）
    basic_list = [gpt5_mini_id2entry[r["instance_id"]] for r in strengthen_list if r.get("instance_id") in common_ids]

    os.makedirs(os.path.dirname(basic_path), exist_ok=True)
    with open(basic_path, "w", encoding="utf-8") as f:
        json.dump(basic_list, f, indent=2, ensure_ascii=False)

    lang_map = {r.get("instance_id"): r.get("language", "unknown") or "unknown" for r in basic_list}
    print(f"Strengthen JSON: {STRENGTHEN_JSON}")
    print(f"Strengthen entries: {len(strengthen_list)}, gpt-5-mini batch ids: {len(gpt5_mini_id2entry)}, common ids: {len(common_ids)}")
    print(f"basic.json (from gpt-5-mini batch) written: {basic_path} ({len(basic_list)} entries)")
    print_pass_rate_summary(basic_list, lang_map)


if __name__ == "__main__":
    main()
