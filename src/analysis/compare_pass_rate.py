#!/usr/bin/env python3
"""
比较两个 pass_rate 文件：
1) 输出 a 未通过但 b 通过的数量
2) 输出 b 未通过但 a 通过的数量
3) 将 b 通过且 a 未通过的 b 侧条目写入指定 JSON 文件
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def _load_json(path: Path) -> list[dict]:
    if not path.exists():
        print(f"Error: 文件不存在: {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        print(f"Error: 期望 JSON 为 list: {path}", file=sys.stderr)
        sys.exit(1)
    return [item for item in data if isinstance(item, dict)]


def _entry_passed(entry: dict) -> bool:
    """兼容不同 pass_rate 结构，尽量判断该条是否通过。"""
    if isinstance(entry.get("passed"), bool):
        return bool(entry["passed"])

    model = entry.get("model")
    golden = entry.get("golden")
    if isinstance(model, dict) and isinstance(golden, dict):
        return (
            model.get("final_result") == "success"
            and golden.get("final_result") == "success"
        )

    model_info = entry.get("model_info")
    golden_info = entry.get("golden_info")
    if isinstance(model_info, dict) and isinstance(golden_info, dict):
        return bool(model_info.get("passed")) and bool(golden_info.get("passed"))

    return False


def _build_map(data: list[dict], tag: str) -> dict[str, dict]:
    result: dict[str, dict] = {}
    missing_id = 0
    duplicated = 0
    for item in data:
        iid = item.get("instance_id")
        if not iid:
            missing_id += 1
            continue
        if iid in result:
            duplicated += 1
        result[iid] = item

    if missing_id:
        print(
            f"Warning: {tag} 中有 {missing_id} 条缺少 instance_id，已忽略。",
            file=sys.stderr,
        )
    if duplicated:
        print(
            f"Warning: {tag} 中有 {duplicated} 个重复 instance_id，已使用最后一条。",
            file=sys.stderr,
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description="比较两个 pass_rate，并导出 b 通过 a 未通过的条目")
    parser.add_argument("--a", required=True, help="a 的 pass_rate.json 路径")
    parser.add_argument("--b", required=True, help="b 的 pass_rate.json 路径")
    parser.add_argument("--output", "-o", required=True, help="输出 JSON 路径（保存 b 通过 a 未通过）")
    args = parser.parse_args()

    a_path = Path(args.a)
    b_path = Path(args.b)
    out_path = Path(args.output)

    a_data = _load_json(a_path)
    b_data = _load_json(b_path)

    a_map = _build_map(a_data, "a")
    b_map = _build_map(b_data, "b")

    all_ids = set(a_map.keys()) | set(b_map.keys())

    a_fail_b_pass_ids: list[str] = []
    b_fail_a_pass_ids: list[str] = []
    b_pass_a_fail_rows: list[dict] = []

    missing_in_a = 0
    missing_in_b = 0

    for iid in sorted(all_ids):
        a_entry = a_map.get(iid)
        b_entry = b_map.get(iid)

        if a_entry is None:
            missing_in_a += 1
        if b_entry is None:
            missing_in_b += 1

        a_pass = _entry_passed(a_entry) if a_entry is not None else False
        b_pass = _entry_passed(b_entry) if b_entry is not None else False

        if (not a_pass) and b_pass:
            a_fail_b_pass_ids.append(iid)
            if b_entry is not None:
                b_pass_a_fail_rows.append(b_entry)
        elif (not b_pass) and a_pass:
            b_fail_a_pass_ids.append(iid)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(b_pass_a_fail_rows, f, ensure_ascii=False, indent=2)

    print(f"a未通过但b通过数量: {len(a_fail_b_pass_ids)}")
    print(f"b未通过但a通过数量: {len(b_fail_a_pass_ids)}")
    print(f"已写入 b通过a未通过 条目: {len(b_pass_a_fail_rows)} -> {out_path}")
    if missing_in_a or missing_in_b:
        print(
            f"提示: 仅在单侧出现的 instance_id 视为另一侧未通过。"
            f" missing_in_a={missing_in_a}, missing_in_b={missing_in_b}",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
