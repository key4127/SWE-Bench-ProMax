#!/usr/bin/env python3
"""
对比 result/strengthen/v2/all_nl_enhanced.json 与 v3/all_nl_fuzzy.json 中
每条记录的 problem_statement 字符数（Python len，Unicode 码点个数）。

按 instance_id 对齐；输出总体汇总及差值分布（v3 - v2）。

用法:
  python compare_problem_statement_len_v2_v3.py
  python compare_problem_statement_len_v2_v3.py --top 20
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
V2_PATH = ROOT / "result" / "strengthen" / "v2" / "all_nl_enhanced.json"
V3_PATH = ROOT / "result" / "strengthen" / "v3" / "all_nl_fuzzy.json"


def load_id_to_ps(path: Path) -> dict[str, str]:
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise SystemExit(f"期望 JSON 数组: {path}")
    out: dict[str, str] = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if not iid:
            continue
        ps = item.get("problem_statement")
        out[str(iid)] = ps if isinstance(ps, str) else ""
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description="对比 v2 / v3 problem_statement 字符数")
    ap.add_argument(
        "--top",
        type=int,
        default=0,
        metavar="N",
        help="额外打印按 |v3-v2| 从大到小前 N 条（0 表示不打印）",
    )
    args = ap.parse_args()

    if not V2_PATH.is_file():
        print(f"缺少文件: {V2_PATH}", file=sys.stderr)
        sys.exit(1)
    if not V3_PATH.is_file():
        print(f"缺少文件: {V3_PATH}", file=sys.stderr)
        sys.exit(1)

    v2 = load_id_to_ps(V2_PATH)
    v3 = load_id_to_ps(V3_PATH)

    only_v2 = set(v2) - set(v3)
    only_v3 = set(v3) - set(v2)
    common = set(v2) & set(v3)

    print(f"v2: {V2_PATH}")
    print(f"v3: {V3_PATH}")
    print(f"v2 条数: {len(v2)}  v3 条数: {len(v3)}  交集: {len(common)}")
    if only_v2:
        print(f"仅在 v2: {len(only_v2)} 条")
    if only_v3:
        print(f"仅在 v3: {len(only_v3)} 条")
    print()

    len_v2 = [len(v2[i]) for i in common]
    len_v3 = [len(v3[i]) for i in common]
    deltas = [len_v3[j] - len_v2[j] for j in range(len(common))]

    print("字符数 len(problem_statement) — 仅统计交集 instance_id")
    print(f"  v2: min={min(len_v2)} max={max(len_v2)} mean={statistics.mean(len_v2):.1f} median={statistics.median(len_v2):.1f}")
    print(f"  v3: min={min(len_v3)} max={max(len_v3)} mean={statistics.mean(len_v3):.1f} median={statistics.median(len_v3):.1f}")
    print()
    print("差值 delta = v3_len - v2_len")
    print(f"  min={min(deltas)} max={max(deltas)} mean={statistics.mean(deltas):.1f} median={statistics.median(deltas):.1f}")
    if len(deltas) >= 2:
        print(f"  stdev={statistics.stdev(deltas):.1f}")
    inc = sum(1 for d in deltas if d > 0)
    dec = sum(1 for d in deltas if d < 0)
    same = sum(1 for d in deltas if d == 0)
    print(f"  变长: {inc}  变短: {dec}  不变: {same}")
    print()

    if args.top > 0:
        rows = [(iid, len(v3[iid]) - len(v2[iid]), len(v2[iid]), len(v3[iid])) for iid in common]
        rows.sort(key=lambda r: (-abs(r[1]), r[0]))
        print(f"按 |v3-v2| 降序前 {args.top} 条:")
        for iid, d, l2, l3 in rows[: args.top]:
            print(f"  {d:+6d}  v2={l2:5d} v3={l3:5d}  {iid}")


if __name__ == "__main__":
    main()
