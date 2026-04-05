#!/usr/bin/env python3
"""
从 result/harness_result 下所有模型的所有 batch*.json 中筛选符合条件的 instance，
合并写入 result/final_stat_result/result/0224.json。

约束：instance 必须曾在 final_stat_result/batchn/id.json 中出现过。

筛选条件（满足其一即可合并）：
1. 语言为 C 或 C++
2. 在所有模型测试中，该 instance 的 golden patch 均通过测试（golden.final_result 为 success）

输出字段参考 final_stat_result/batchn/raw.json，但去掉 PASS_TO_PASS 与 FAIL_TO_PASS。
"""

import argparse
import json
import os
import re
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", ".."))

# 匹配 batch1.json, batch2.json 等
_BATCH_PATTERN = re.compile(r"^batch\d+\.json$", re.IGNORECASE)

# 匹配 batch1, batch2 等目录名
_FINAL_BATCH_DIR_PATTERN = re.compile(r"^batch\d+$", re.IGNORECASE)

# C/C++ 语言标识（与 harness 中一致）
_CCPP_LANGS = frozenset({"c", "c++"})

# 输出时从 raw 记录中排除的字段
_RAW_DROP_KEYS = frozenset({"PASS_TO_PASS", "FAIL_TO_PASS", "PASS_TO__PASS", "FAIL_TO__PASS"})


def _is_ccpp(lang: str) -> bool:
    if not lang:
        return False
    return lang.strip().lower() in _CCPP_LANGS


def load_batch(path: str) -> list:
    """加载单个 batch JSON，返回 record 列表。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return data
    return [data] if isinstance(data, dict) else []


def collect_from_harness(harness_dir: str):
    """
    遍历 harness_dir 下所有模型子目录及其 batch*.json，
    返回：
    - instance_records: dict[instance_id, record] 每个 instance 保留一条完整记录（首次出现）
    - instance_occurrences: dict[instance_id, list[bool]] 每个 instance 在各处出现的 golden 是否 success
    """
    instance_records = {}
    instance_occurrences = {}  # instance_id -> list of (golden_success: bool)

    if not os.path.isdir(harness_dir):
        return instance_records, instance_occurrences

    for model_name in sorted(os.listdir(harness_dir)):
        model_dir = os.path.join(harness_dir, model_name)
        if not os.path.isdir(model_dir):
            continue
        for fname in sorted(os.listdir(model_dir)):
            if not _BATCH_PATTERN.match(fname):
                continue
            batch_path = os.path.join(model_dir, fname)
            if not os.path.isfile(batch_path):
                continue
            try:
                records = load_batch(batch_path)
            except Exception as e:
                print(f"警告: 无法加载 {batch_path}: {e}", file=sys.stderr)
                continue
            for rec in records:
                if not isinstance(rec, dict):
                    continue
                iid = rec.get("instance_id")
                if not iid:
                    continue
                golden = rec.get("golden") or {}
                final = (golden.get("final_result") or "").strip().lower()
                golden_ok = final == "success"
                if iid not in instance_occurrences:
                    instance_occurrences[iid] = []
                    instance_records[iid] = rec
                instance_occurrences[iid].append(golden_ok)

    return instance_records, instance_occurrences


def qualify(instance_id: str, record: dict, occurrences: list) -> bool:
    """
    判断该 instance 是否满足合并条件之一：
    1. C/C++ 语言
    2. 在所有出现处 golden 均为 success
    """
    if _is_ccpp(record.get("language") or ""):
        return True
    if not occurrences:
        return False
    return all(occurrences)


def collect_allowed_ids_and_raw(final_stat_dir: str):
    """
    遍历 final_stat_result 下各 batchn 目录，收集：
    - allowed_ids: 所有 id.json 中出现过的 instance_id 集合
    - raw_by_id: instance_id -> 该条在 raw.json 中的完整记录（首次出现的 batch 为准）
    """
    allowed_ids = set()
    raw_by_id = {}

    if not os.path.isdir(final_stat_dir):
        return allowed_ids, raw_by_id

    for name in sorted(os.listdir(final_stat_dir)):
        if not _FINAL_BATCH_DIR_PATTERN.match(name):
            continue
        batch_dir = os.path.join(final_stat_dir, name)
        if not os.path.isdir(batch_dir):
            continue
        id_path = os.path.join(batch_dir, "id.json")
        raw_path = os.path.join(batch_dir, "raw.json")
        if os.path.isfile(id_path):
            try:
                with open(id_path, "r", encoding="utf-8") as f:
                    ids = json.load(f)
                for iid in ids if isinstance(ids, list) else [ids]:
                    if isinstance(iid, str) and iid:
                        allowed_ids.add(iid)
            except Exception as e:
                print(f"警告: 无法加载 {id_path}: {e}", file=sys.stderr)
        if os.path.isfile(raw_path):
            try:
                with open(raw_path, "r", encoding="utf-8") as f:
                    raw_list = json.load(f)
            except Exception as e:
                print(f"警告: 无法加载 {raw_path}: {e}", file=sys.stderr)
                continue
            items = raw_list if isinstance(raw_list, list) else [raw_list]
            for rec in items:
                if not isinstance(rec, dict):
                    continue
                iid = rec.get("instance_id")
                if not iid or iid in raw_by_id:
                    continue
                raw_by_id[iid] = rec
            del items
    return allowed_ids, raw_by_id


def raw_record_for_output(raw_rec: dict) -> dict:
    """从 raw 单条记录生成输出记录，去掉 PASS_TO_PASS / FAIL_TO_PASS 等字段。"""
    return {k: v for k, v in raw_rec.items() if k not in _RAW_DROP_KEYS}


def main() -> None:
    parser = argparse.ArgumentParser(description="从 harness_result 筛选 instance 并合并到 0224.json")
    parser.add_argument(
        "result_dir",
        nargs="?",
        default=os.path.join(_PROJECT_ROOT, "result"),
        help="result 目录路径（默认: 项目下的 result）",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="输出 JSON 路径（默认: <result_dir>/final_stat_result/result/0224.json）",
    )
    args = parser.parse_args()

    result_dir = os.path.abspath(args.result_dir)
    harness_dir = os.path.join(result_dir, "harness_result")
    final_stat_dir = os.path.join(result_dir, "final_stat_result")
    if args.output:
        out_path = os.path.abspath(args.output)
    else:
        out_path = os.path.join(result_dir, "final_stat_result", "result", "0224.json")

    if not os.path.isdir(harness_dir):
        print(f"错误: harness 目录不存在: {harness_dir}", file=sys.stderr)
        sys.exit(1)

    allowed_ids, raw_by_id = collect_allowed_ids_and_raw(final_stat_dir)
    if not allowed_ids:
        print("警告: final_stat_result 下未找到任何 id.json，输出将为空。", file=sys.stderr)

    instance_records, instance_occurrences = collect_from_harness(harness_dir)
    qualified_ids = []
    for iid, record in instance_records.items():
        if iid not in allowed_ids:
            continue
        occ = instance_occurrences.get(iid, [])
        if qualify(iid, record, occ):
            qualified_ids.append(iid)

    # 输出使用 raw 中的记录（去掉指定字段），按 qualified_ids 顺序；若某 id 无 raw 则跳过
    out_records = []
    for iid in qualified_ids:
        raw_rec = raw_by_id.get(iid)
        if raw_rec is None:
            print(f"警告: instance {iid} 在 raw.json 中未找到，已跳过", file=sys.stderr)
            continue
        out_records.append(raw_record_for_output(raw_rec))

    out_dir = os.path.dirname(out_path)
    os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out_records, f, ensure_ascii=False, indent=2)

    print(f"共处理 {len(instance_records)} 个 instance，在 id 表内且符合条件 {len(qualified_ids)} 个，写出 {len(out_records)} 条 -> {out_path}")


if __name__ == "__main__":
    main()
