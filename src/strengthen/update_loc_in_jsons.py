#!/usr/bin/env python3
"""
对 result 下所有包含 loc 字段的 JSON 文件，根据 patch 或 files 重新计算 loc / 文件数
（排除文档扩展名、仅注释、测试文件等），并写回原文件。

用法:
  python -m result.update_loc_in_jsons [--dry-run] [路径...]
  不传路径时默认扫描 result/ 下所有 .json（递归）。
"""

import argparse
import json
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", ".."))
_SRC = os.path.join(_PROJECT_ROOT, "src")
if _SRC not in sys.path:
    sys.path.insert(0, _SRC)

from result.merge_swe_detail import stats_from_files, stats_from_patch


def has_loc_in_data(obj):
    """递归检查是否存在键 'loc'（用于判断是否需要处理）。"""
    if isinstance(obj, dict):
        if "loc" in obj:
            return True
        for v in obj.values():
            if has_loc_in_data(v):
                return True
    elif isinstance(obj, list):
        for v in obj:
            if has_loc_in_data(v):
                return True
    return False


def update_item(item):
    """对单条记录用 patch 或 files 重算 loc 等，原地修改。返回是否做了更新。"""
    if not isinstance(item, dict) or "loc" not in item:
        return False
    updated = False
    if item.get("files"):
        s = stats_from_files(item["files"])
        item["loc"] = s["loc"]
        item["num_files"] = s["num_files"]
        item["num_non_test"] = s["num_non_test"]
        item["num_test"] = s["num_test"]
        updated = True
    elif item.get("patch"):
        s = stats_from_patch(item["patch"])
        item["loc"] = s["loc"]
        item["num_non_test"] = s["num_non_test"]
        updated = True
    return updated


def process_file(path: str, dry_run: bool) -> int:
    """处理单个 JSON 文件，返回更新的记录数。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not has_loc_in_data(data):
        return 0
    if not isinstance(data, list):
        return 0
    n = 0
    for item in data:
        if update_item(item):
            n += 1
    if n and not dry_run:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    return n


def main():
    parser = argparse.ArgumentParser(
        description="对 result 下含 loc 的 JSON 按 patch/files 重算 loc 与文件数并写回"
    )
    parser.add_argument(
        "paths",
        nargs="*",
        help="要处理的 JSON 文件或目录（默认: result/）",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="只统计会更新多少条，不写回文件",
    )
    args = parser.parse_args()

    if not args.paths:
        result_dir = os.path.join(_PROJECT_ROOT, "result")
        args.paths = [result_dir]

    files_to_process = []
    for p in args.paths:
        p = os.path.normpath(p if os.path.isabs(p) else os.path.join(_PROJECT_ROOT, p))
        if not os.path.exists(p):
            continue
        if os.path.isfile(p):
            if p.endswith(".json"):
                files_to_process.append(p)
        else:
            for root, _dirs, filenames in os.walk(p):
                for name in filenames:
                    if name.endswith(".json"):
                        files_to_process.append(os.path.join(root, name))

    total_updated = 0
    touched_files = 0
    for path in files_to_process:
        try:
            n = process_file(path, args.dry_run)
            if n:
                total_updated += n
                touched_files += 1
                rel = os.path.relpath(path, _PROJECT_ROOT)
                print(f"{rel}: 更新 {n} 条")
        except Exception as e:
            print(f"{path}: 错误 {e}", file=sys.stderr)

    if args.dry_run and total_updated:
        print(f"[dry-run] 共将更新 {total_updated} 条，涉及 {touched_files} 个文件")
    elif total_updated:
        print(f"已更新 {total_updated} 条，涉及 {touched_files} 个文件")


if __name__ == "__main__":
    main()
