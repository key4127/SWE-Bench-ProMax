#!/usr/bin/env python3
"""
从 result/final_stat_result 的某个 JSON 中按语言筛选：
1. 筛掉该语言中 loc 最低的 x 个实例
2. 再筛掉该语言中 num_files 最少的 x 个实例

输出写到同目录下的 0225.json（可通过参数修改）。
"""

import argparse
import json
import os
import sys

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", ".."))


def main():
    parser = argparse.ArgumentParser(
        description="按语言筛掉 loc 最低的 x 个与 num_files 最少的 x 个实例，输出 0225.json"
    )
    parser.add_argument(
        "input",
        nargs="?",
        default=os.path.join(_PROJECT_ROOT, "result", "final_stat_result", "result", "0224.json"),
        help="输入 JSON 路径（默认: result/final_stat_result/result/0224.json）",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="输出 JSON 路径（默认: 与输入同目录下的 0225.json）",
    )
    parser.add_argument(
        "-l", "--language",
        required=True,
        help="要筛选的语言，例如 go, rust, c, c++",
    )
    parser.add_argument(
        "-x",
        type=int,
        default=5,
        help="每种条件筛掉的数量（默认: 5）",
    )
    args = parser.parse_args()

    input_path = os.path.normpath(
        args.input if os.path.isabs(args.input) else os.path.join(_PROJECT_ROOT, args.input)
    )
    if not os.path.isfile(input_path):
        print(f"错误: 输入文件不存在: {input_path}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        out_path = os.path.normpath(
            args.output if os.path.isabs(args.output) else os.path.join(_PROJECT_ROOT, args.output)
        )
    else:
        out_dir = os.path.dirname(input_path)
        out_path = input_path

    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        print("错误: 输入 JSON 应为 list", file=sys.stderr)
        sys.exit(1)

    lang_key = args.language.strip().lower()
    other = [r for r in data if (r.get("language") or "").strip().lower() != lang_key]
    target = [r for r in data if (r.get("language") or "").strip().lower() == lang_key]

    n_before = len(target)
    # 1) 筛掉 loc 最低的 x 个
    target_sorted_loc = sorted(target, key=lambda r: (r.get("loc") is None, r.get("loc") or 0))
    drop_loc_ids = {target_sorted_loc[i]["instance_id"] for i in range(min(args.x, len(target_sorted_loc)))}
    target = [r for r in target if r["instance_id"] not in drop_loc_ids]

    # 2) 再筛掉 num_files 最少的 x 个
    target_sorted_files = sorted(target, key=lambda r: (r.get("num_files") is None, r.get("num_files") or 0))
    drop_files_ids = {target_sorted_files[i]["instance_id"] for i in range(min(args.x, len(target_sorted_files)))}
    target = [r for r in target if r["instance_id"] not in drop_files_ids]

    result = other + target
    result.sort(key=lambda r: (r.get("language") or "", r.get("instance_id") or ""))

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(
        f"语言 {args.language}: {n_before} -> 去掉 loc 最低 {len(drop_loc_ids)} 个、num_files 最少 {len(drop_files_ids)} 个 -> {len(target)} 条"
    )
    print(f"总条数: {len(data)} -> {len(result)}")
    print(f"已写入: {out_path}")


if __name__ == "__main__":
    main()
