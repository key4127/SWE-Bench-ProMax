#!/usr/bin/env python3
"""
从 0226_raw.json 中按语言分组，每种语言平均抽取 8 个 instance，
合并为 strengthen.json 并写入指定输出文件夹。
"""

import argparse
import json
import random
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(
        description="按语言从 raw JSON 中每语言抽样约 8 个 instance，输出 strengthen.json"
    )
    parser.add_argument(
        "input_json",
        nargs="?",
        default="result/final_stat_result/result/0226_raw.json",
        help="输入 JSON 路径（默认: result/final_stat_result/result/0226_raw.json）",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        default="result/final_stat_result/strengthen",
        help="输出目录，其下生成 strengthen.json（默认: result/final_stat_result/strengthen）",
    )
    parser.add_argument(
        "-n",
        "--per-lang",
        type=int,
        default=8,
        help="每种语言抽取的 instance 数量（默认: 8）",
    )
    parser.add_argument(
        "-s",
        "--seed",
        type=int,
        default=None,
        help="随机种子，便于复现",
    )
    args = parser.parse_args()

    # 项目根目录: 从 src/pipeline/strengthen/ 往上 3 层
    base = Path(__file__).resolve().parents[3]
    input_path = base / args.input_json
    if not input_path.exists():
        # 兼容用户写的 result/final_stat_result/0226_raw.json
        alt = base / "result/final_stat_result/0226_raw.json"
        if alt.exists():
            input_path = alt
        else:
            print(f"Error: 文件不存在: {input_path}", file=sys.stderr)
            sys.exit(1)

    try:
        with open(input_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(data, list):
        print("Error: 输入 JSON 应为数组", file=sys.stderr)
        sys.exit(1)

    # 按 language 分组
    by_lang = {}
    for item in data:
        lang = item.get("language", "unknown")
        by_lang.setdefault(lang, []).append(item)

    if args.seed is not None:
        random.seed(args.seed)

    n_per = args.per_lang
    sampled = []
    for lang, items in sorted(by_lang.items()):
        if len(items) <= n_per:
            chosen = items
        else:
            chosen = random.sample(items, n_per)
        sampled.extend(chosen)
        print(f"  {lang}: 共 {len(items)} 条 -> 抽取 {len(chosen)} 条")

    out_dir = base / args.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "strengthen.json"

    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(sampled, f, ensure_ascii=False, indent=2)

    print(f"已写入 {len(sampled)} 条 -> {out_file}")


if __name__ == "__main__":
    main()
