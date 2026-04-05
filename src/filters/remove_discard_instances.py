#!/usr/bin/env python3
"""
从 all_nl_enhanced.json 中移除所有 discard 为 true 的实例，输出到新文件。
"""

import argparse
import json
from pathlib import Path

# 脚本在 src/filter/final，parents[2] 为项目根
_SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = _SCRIPT_DIR.parents[2]

DEFAULT_INPUT = PROJECT_ROOT / "result/strengthen/v2/all_nl_enhanced.json"
DEFAULT_OUTPUT = PROJECT_ROOT / "result/strengthen/v2/all_nl_enhanced_no_discard.json"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="移除 JSON 中 discard 为 true 的实例并输出到新文件"
    )
    parser.add_argument(
        "--input",
        "-i",
        type=Path,
        default=DEFAULT_INPUT,
        help=f"输入 JSON 路径（默认: {DEFAULT_INPUT}）",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"输出 JSON 路径（默认: {DEFAULT_OUTPUT}）",
    )
    args = parser.parse_args()

    if not args.input.exists():
        raise SystemExit(f"输入文件不存在: {args.input}")

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        raise SystemExit("输入 JSON 应为对象数组")

    total = len(data)
    kept = [item for item in data if item.get("discard") is not True]
    removed = total - len(kept)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(kept, f, ensure_ascii=False, indent=2)

    print(f"输入: {total} 条，移除 discard=true: {removed} 条，保留: {len(kept)} 条")
    print(f"已写入: {args.output}")


if __name__ == "__main__":
    main()
