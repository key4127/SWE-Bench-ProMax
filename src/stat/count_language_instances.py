#!/usr/bin/env python3
"""
统计 result/final_stat_result/result 内某个 JSON 文件中，每个 language 的 instance 数量，输出到 stdout。
"""

import argparse
import json
import sys


def main():
    parser = argparse.ArgumentParser(description="按 language 统计 JSON 中 instance 数量")
    parser.add_argument(
        "json_file",
        help="result/final_stat_result/result 下的 JSON 文件路径",
    )
    args = parser.parse_args()

    try:
        with open(args.json_file, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(data, list):
        print("Error: 期望 JSON 为数组", file=sys.stderr)
        sys.exit(1)

    # 统计每个 language 的 instance 数量（空/缺失视为同一类）
    counts = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        lang = (item.get("language") or "").strip() or "(empty)"
        counts[lang] = counts.get(lang, 0) + 1

    # 按 language 名字排序输出
    for lang in sorted(counts.keys(), key=lambda x: (x == "(empty)", x.lower())):
        print(f"{lang}\t{counts[lang]}")


if __name__ == "__main__":
    main()
