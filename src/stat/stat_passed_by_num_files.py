#!/usr/bin/env python3
"""
根据 swe-format 与 harness_result，按 num_files 由下向上打印通过测试的实例数量。
参数1: swe-format 类 JSON（含 instance_id, num_files）
参数2: 单个 harness result JSON，或包含多个 JSON 的目录（递归统计所有 .json，取通过实例的并集）
"""

import argparse
import json
import sys
from pathlib import Path
from collections import defaultdict


def load_swe_format(path: Path) -> dict[str, int]:
    """加载 swe-format JSON，返回 instance_id -> num_files。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        return {}
    out = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if iid is None:
            continue
        nf = item.get("num_files")
        out[iid] = int(nf) if nf is not None else 0
    return out


def load_passed_ids_from_file(path: Path) -> set[str]:
    """加载单个 harness result JSON，返回 passed=True 的 instance_id 集合。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        return set()
    passed = set()
    for item in data:
        if not isinstance(item, dict):
            continue
        if item.get("passed") is not True:
            continue
        iid = item.get("instance_id")
        if iid:
            passed.add(iid)
    return passed


def load_passed_ids(path: Path) -> set[str]:
    """
    加载 harness result：若 path 为文件则只读该文件；
    若为目录则递归读取该目录下所有 .json 文件并取通过实例的并集。
    """
    path = path.resolve()
    if path.is_file():
        return load_passed_ids_from_file(path)
    if not path.is_dir():
        raise FileNotFoundError(f"不存在: {path}")

    passed_ids = set()
    json_files = sorted(path.rglob("*.json"))
    for jf in json_files:
        try:
            passed_ids |= load_passed_ids_from_file(jf)
        except (json.JSONDecodeError, OSError) as e:
            print(f"[跳过] {jf}: {e}", file=sys.stderr)
    if json_files:
        print(f"[已统计] 目录下共 {len(json_files)} 个 JSON 文件", file=sys.stderr)
    return passed_ids


def main():
    parser = argparse.ArgumentParser(
        description="按 num_files 由下向上打印通过测试的实例数量（swe-format + harness_result）"
    )
    parser.add_argument(
        "swe_format",
        type=Path,
        help="swe-format 类 JSON 文件路径",
    )
    parser.add_argument(
        "harness_result",
        type=Path,
        help="单个 harness result JSON 文件路径，或包含多个 JSON 的目录（会递归统计）",
    )
    args = parser.parse_args()

    id_to_num_files = load_swe_format(args.swe_format)
    passed_ids = load_passed_ids(args.harness_result)

    # 通过测试的 instance 的 num_files 列表（仅保留在 swe-format 中存在的）
    num_files_list = []
    for iid in passed_ids:
        if iid in id_to_num_files:
            num_files_list.append(id_to_num_files[iid])

    # 按 num_files 由下向上（从小到大）排序
    num_files_list.sort()

    # 按 num_files 分组统计：num_files -> 通过数量
    by_num_files = defaultdict(int)
    for nf in num_files_list:
        by_num_files[nf] += 1

    # 由下向上打印：从 num_files 小到大
    print("num_files\tpassed_count")
    print("-" * 24)
    for nf in sorted(by_num_files.keys()):
        print(f"{nf}\t{by_num_files[nf]}")

    print("-" * 24)
    print(f"total_passed\t{len(num_files_list)}")


if __name__ == "__main__":
    main()
