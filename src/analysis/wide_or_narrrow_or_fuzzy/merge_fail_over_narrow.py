#!/usr/bin/env python3
"""
将 judge_fail_only_result.json 中的「过窄测试」字段合并到 judge_result.json 中。

规则：
  - 以 instance_id 为键，对两个 JSON 列表进行对齐。
  - 若某个 instance_id 同时出现在 judge_result.json 与 judge_fail_only_result.json 中，
    则用 fail_only 结果中的以下字段覆盖 judge_result.json 中对应字段：
      - over_narrow_test
      - over_narrow_reason
  - 不修改其它任何字段。

默认行为：
  - 输入：
      --judge  默认 src/test/patch/judge_result.json
      --fail   默认 src/test/patch/judge_fail_only_result.json
  - 输出：
      若指定 --output，则写入该路径；
      否则在原 judge_result.json 上就地覆盖（in-place）。
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List


SCRIPT_DIR = Path(__file__).resolve().parent


def _load_json_list(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(f"JSON 文件不存在: {path}")
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError(f"JSON 内容必须为列表(list): {path}")
    return data  # type: ignore[return-value]


def merge_over_narrow(
    judge_path: Path,
    fail_only_path: Path,
) -> List[Dict[str, Any]]:
    """读取两个 JSON 列表，仅将 over_narrow_* 字段从 fail_only 合并到 judge。"""
    judge_list = _load_json_list(judge_path)
    fail_list = _load_json_list(fail_only_path)

    # 以 instance_id 为键构建索引
    judge_index: Dict[str, Dict[str, Any]] = {}
    for rec in judge_list:
        iid = rec.get("instance_id")
        if isinstance(iid, str):
            judge_index[iid] = rec

    updated_count = 0
    missing_in_judge = 0

    for rec in fail_list:
        iid = rec.get("instance_id")
        if not isinstance(iid, str):
            continue
        target = judge_index.get(iid)
        if target is None:
            # 该实例仅存在于 fail_only 结果中，按需求不新增，只跳过
            missing_in_judge += 1
            continue

        # 仅同步「过窄测试」相关字段
        if "over_narrow_test" in rec:
            target["over_narrow_test"] = rec["over_narrow_test"]
        if "over_narrow_reason" in rec:
            target["over_narrow_reason"] = rec["over_narrow_reason"]
        updated_count += 1

    print(f"已更新 {updated_count} 条记录的 over_narrow_* 字段。")
    if missing_in_judge:
        print(f"警告：在 judge_result.json 中未找到 {missing_in_judge} 个实例（仅存在于 fail_only 结果中），已跳过。")

    return judge_list


def main() -> None:
    parser = argparse.ArgumentParser(
        description="将 judge_fail_only_result.json 中的过窄测试字段合并到 judge_result.json（仅覆盖 over_narrow_*）。"
    )
    parser.add_argument(
        "--judge",
        type=Path,
        default=SCRIPT_DIR / "judge_result.json",
        help="原始 judge_result.json 路径（默认：脚本目录下 judge_result.json）",
    )
    parser.add_argument(
        "--fail",
        type=Path,
        default=SCRIPT_DIR / "judge_fail_only_result.json",
        help="仅失败样本评判结果 judge_fail_only_result.json 路径（默认：脚本目录下 judge_fail_only_result.json）",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="合并后的输出 JSON 路径（默认：覆盖 --judge 指定的文件）",
    )
    args = parser.parse_args()

    judge_path: Path = args.judge
    fail_only_path: Path = args.fail
    output_path: Path = args.output or judge_path

    merged = merge_over_narrow(judge_path=judge_path, fail_only_path=fail_only_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)

    print(f"已写入合并结果到: {output_path}")


if __name__ == "__main__":
    main()

