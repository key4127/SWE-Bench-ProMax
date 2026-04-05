#!/usr/bin/env python3
"""
统计 auto_env_config_report 中每个 batch、每种语言的成功数量和成功率。
原数组（总样本）来自 scale/docker/batchn/result，成功判定来自 auto_env_config_report 中的 evaluation_report / judge_res / merged_docker_config_report。
"""

import json
import os
from pathlib import Path
from collections import defaultdict

# 项目根目录
ROOT = Path(__file__).resolve().parent.parent
SCALE_RESULT_BASE = ROOT / "scale" / "docker"
REPORT_BASE = ROOT / "auto_env_config_report"


def load_original_instances(batch_key: str) -> dict[str, str]:
    """
    从 scale/docker/batchn/result 加载原数组，返回 instance_id -> language。
    batch_key: 如 "batch1", "batch2", "batch3", "batch4", "batch5"
    """
    # batch4_1 对应 scale 的 batch4
    scale_batch = "batch4" if batch_key == "batch4_1" else batch_key
    result_dir = SCALE_RESULT_BASE / scale_batch / "result"
    if not result_dir.exists():
        return {}

    id_to_lang = {}
    for f in sorted(result_dir.glob("*.json")):
        try:
            with open(f, encoding="utf-8") as fp:
                data = json.load(fp)
        except (json.JSONDecodeError, OSError):
            continue
        if not isinstance(data, list):
            continue
        for item in data:
            iid = item.get("instance_id")
            lang = item.get("language") or "unknown"
            if iid and iid not in id_to_lang:
                id_to_lang[iid] = str(lang).strip().lower()
    return id_to_lang


def load_resolved_set(batch_key: str) -> set[str]:
    """
    从 auto_env_config_report 加载成功 instance_id 集合（resolved=True）。
    """
    report_dir = REPORT_BASE / batch_key
    if not report_dir.exists():
        return set()

    resolved = set()
    # 可能存在的报告文件模式
    patterns = [
        "evaluation_report.json",
        "merged_docker_config_report.json",
        "*_judge_res.json",
    ]
    for pat in patterns:
        for f in report_dir.glob(pat):
            try:
                with open(f, encoding="utf-8") as fp:
                    data = json.load(fp)
            except (json.JSONDecodeError, OSError):
                continue
            details = data.get("instance_details") if isinstance(data, dict) else None
            if not details:
                continue
            for item in details:
                if isinstance(item, dict) and item.get("resolved") is True:
                    iid = item.get("instance_id")
                    if iid:
                        resolved.add(iid)
    return resolved


def main():
    # 确定 auto_env_config_report 下有哪些 batch
    batch_dirs = [d.name for d in REPORT_BASE.iterdir() if d.is_dir()]
    batch_dirs.sort()

    all_stats = []
    for batch_key in batch_dirs:
        id_to_lang = load_original_instances(batch_key)
        resolved_set = load_resolved_set(batch_key)
        if not id_to_lang:
            print(f"[{batch_key}] 未找到原数组 (scale/docker 对应 result)，跳过")
            continue

        # 按语言统计：总数、成功数
        lang_total = defaultdict(int)
        lang_success = defaultdict(int)
        for iid, lang in id_to_lang.items():
            lang_total[lang] += 1
            if iid in resolved_set:
                lang_success[lang] += 1

        for lang in sorted(lang_total.keys()):
            total = lang_total[lang]
            success = lang_success[lang]
            rate = (success / total * 100) if total else 0
            all_stats.append({
                "batch": batch_key,
                "language": lang,
                "total": total,
                "success": success,
                "success_rate_pct": round(rate, 2),
            })

    # 打印表格
    print("Batch\tLanguage\tTotal\tSuccess\tSuccessRate(%)")
    print("-" * 60)
    for s in all_stats:
        print(f"{s['batch']}\t{s['language']}\t{s['total']}\t{s['success']}\t{s['success_rate_pct']}")

    # 写入 JSON
    out_path = REPORT_BASE / "stat_by_language.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(all_stats, f, ensure_ascii=False, indent=2)
    print(f"\n已写入: {out_path}")

    # 汇总表：每个 batch 一行，各语言成功率
    print("\n--- 按 Batch 汇总 ---")
    by_batch = defaultdict(list)
    for s in all_stats:
        by_batch[s["batch"]].append(s)
    for batch in sorted(by_batch.keys()):
        rows = by_batch[batch]
        total_all = sum(r["total"] for r in rows)
        success_all = sum(r["success"] for r in rows)
        rate_all = (success_all / total_all * 100) if total_all else 0
        print(f"{batch}: 总样本={total_all}, 成功={success_all}, 成功率={rate_all:.2f}%")
        for r in rows:
            print(f"  - {r['language']}: {r['success']}/{r['total']} ({r['success_rate_pct']}%)")


if __name__ == "__main__":
    main()
