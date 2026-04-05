#!/usr/bin/env python3
"""
从 preds.json 中的 instance_id 出发，在 result/strengthen/v2/all_nl_enhanced.json 中
找到对应实例，提取其 swe-format 条目，写入 data_for_agent/swe-format/<out_subdir>/ 下。

用法示例:
  python -m src.filters.extract_swe_format_from_preds \\
    --preds result/preds_result/strengthen/v2/claude_token/preds.json \\
    --out-subdir claude_token

  python -m src.filters.extract_swe_format_from_preds \\
    --preds result/preds_result/strengthen/v2/claude_token/preds.json \\
    --enhanced result/strengthen/v2/all_nl_enhanced.json \\
    --out-subdir claude_token
"""

import argparse
import json
import os
import sys
from pathlib import Path

# 项目根目录
_SCRIPT_DIR = Path(__file__).resolve().parent
_PROJECT_ROOT = _SCRIPT_DIR.parent.parent


def _swe_format_entry(raw: dict) -> dict:
    """从 all_nl_enhanced 单条去掉内部字段，得到 swe-format 单条。"""
    return {k: v for k, v in raw.items() if not k.startswith("_")}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="按 preds.json 的 instance_id 从 all_nl_enhanced 提取 swe-format 并写入 data_for_agent/swe-format/<out_subdir>/"
    )
    parser.add_argument(
        "--preds",
        type=str,
        default="result/preds_result/strengthen/v2/claude_token/preds.json",
        help="preds.json 路径（dict: instance_id -> 预测条目）",
    )
    parser.add_argument(
        "--enhanced",
        type=str,
        default="result/strengthen/v2/all_nl_enhanced.json",
        help="all_nl_enhanced.json 路径（list of swe-format 风格条目）",
    )
    parser.add_argument(
        "--out-subdir",
        type=str,
        default="claude_token",
        help="输出子目录名，结果写入 data_for_agent/swe-format/<out_subdir>/<out_subdir>.json",
    )
    parser.add_argument(
        "--project-root",
        type=str,
        default=str(_PROJECT_ROOT),
        help="项目根目录",
    )
    args = parser.parse_args()

    root = Path(args.project_root)
    preds_path = root / args.preds
    enhanced_path = root / args.enhanced
    out_dir = root / "data_for_agent" / "swe-format" / args.out_subdir
    out_file = out_dir / f"{args.out_subdir}.json"

    if not preds_path.is_file():
        print(f"Error: preds 文件不存在: {preds_path}", file=sys.stderr)
        sys.exit(1)
    if not enhanced_path.is_file():
        print(f"Error: enhanced 文件不存在: {enhanced_path}", file=sys.stderr)
        sys.exit(1)

    with open(preds_path, "r", encoding="utf-8") as f:
        preds = json.load(f)
    with open(enhanced_path, "r", encoding="utf-8") as f:
        enhanced_list = json.load(f)

    # preds: dict keyed by instance_id
    pred_ids = set(preds.keys())

    # enhanced: list of dict with instance_id
    enhanced_by_id = {item["instance_id"]: item for item in enhanced_list if isinstance(item, dict) and item.get("instance_id")}

    out_list = []
    missing = []
    for iid in pred_ids:
        if iid in enhanced_by_id:
            out_list.append(_swe_format_entry(enhanced_by_id[iid]))
        else:
            missing.append(iid)

    out_dir.mkdir(parents=True, exist_ok=True)
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(out_list, f, ensure_ascii=False, indent=2)

    print(f"preds 共 {len(pred_ids)} 条，enhanced 中匹配 {len(out_list)} 条，已写入 {out_file}")
    if missing:
        print(f"  warning: {len(missing)} 个 instance_id 在 enhanced 中不存在", file=sys.stderr)


if __name__ == "__main__":
    main()
