#!/usr/bin/env python3
"""
根据 preds 中出现的 instance_id，从 gemini_limit_origin.json 中取对应条目，
其余条目沿用 gemini.json，生成 gemini_limit.json。

规则：
- 若某 instance_id 出现在 preds.json 中：
    使用 gemini_limit_origin.json 中该 instance_id 的整条记录；
- 否则：
    使用 gemini.json 中该 instance_id 的整条记录。

默认路径（相对项目根目录）：
- preds: result/preds_result/strengthen/v2/gemini_limit/preds.json
- base: result/harness_result/strengthen/v2/gemini.json
- limit_origin: result/harness_result/strengthen/v2/gemini_limit_origin.json
- output: result/harness_result/strengthen/v2/gemini_limit.json
"""

import argparse
import json
import os
from typing import Any, Dict, List, Set


def load_json(path: str) -> Any:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"文件不存在: {path}")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def collect_pred_ids(preds_path: str) -> Set[str]:
    data = load_json(preds_path)
    ids: Set[str] = set()

    # 支持两种格式：
    # 1) list[{"instance_id": "...", ...}, ...]
    # 2) { "<instance_id>": { "instance_id": "...", ... }, ... }
    if isinstance(data, list):
        for item in data:
            if not isinstance(item, dict):
                continue
            iid = item.get("instance_id")
            if isinstance(iid, str) and iid:
                ids.add(iid)
    elif isinstance(data, dict):
        # 先用 key，当 value 中也有 instance_id 时做一次交叉校验
        for k, v in data.items():
            if isinstance(k, str) and k:
                ids.add(k)
            if isinstance(v, dict):
                iid = v.get("instance_id")
                if isinstance(iid, str) and iid:
                    ids.add(iid)
    else:
        raise ValueError(f"preds 文件格式未知（既不是 list 也不是 dict）: {preds_path}")
    print(f"从 preds 中收集到 {len(ids)} 个 instance_id")
    return ids


def build_index_by_id(items: List[Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
    index: Dict[str, Dict[str, Any]] = {}
    for it in items:
        if not isinstance(it, dict):
            continue
        iid = it.get("instance_id")
        if isinstance(iid, str) and iid:
            if iid in index:
                # 简单提示重复，保留后出现的
                print(f"警告: instance_id 重复，后者覆盖前者: {iid}")
            index[iid] = it
    return index


def merge_gemini(
    preds_path: str,
    base_path: str,
    limit_origin_path: str,
    output_path: str,
) -> None:
    pred_ids = collect_pred_ids(preds_path)

    base_data = load_json(base_path)
    if not isinstance(base_data, list):
        raise ValueError(f"base gemini 文件格式应为 list: {base_path}")

    limit_origin_data = load_json(limit_origin_path)
    if not isinstance(limit_origin_data, list):
        raise ValueError(f"limit_origin 文件格式应为 list: {limit_origin_path}")

    limit_index = build_index_by_id(limit_origin_data)

    merged: List[Dict[str, Any]] = []
    missing_in_limit_origin: Set[str] = set()

    for item in base_data:
        if not isinstance(item, dict):
            merged.append(item)
            continue
        iid = item.get("instance_id")
        if isinstance(iid, str) and iid in pred_ids:
            rep = limit_index.get(iid)
            if rep is None:
                # preds 里有，但 limit_origin 里没有，记录一下，仍然保留原始 base 记录
                missing_in_limit_origin.add(iid)
                merged.append(item)
            else:
                merged.append(rep)
        else:
            merged.append(item)

    # 对于在 preds 中但不在 base 中的 id，仅提示，不额外添加
    base_ids = {
        it.get("instance_id")
        for it in base_data
        if isinstance(it, dict) and isinstance(it.get("instance_id"), str)
    }
    extra_pred_ids = pred_ids - {iid for iid in base_ids if isinstance(iid, str)}

    if missing_in_limit_origin:
        print(
            f"注意: 有 {len(missing_in_limit_origin)} 个 preds 中的 instance_id "
            f"在 limit_origin 中找不到，将保留 gemini.json 中的原始记录。"
        )

    if extra_pred_ids:
        print(
            f"注意: 有 {len(extra_pred_ids)} 个 preds 中的 instance_id "
            f"不在 gemini.json 中，未写入输出文件。"
        )

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False)

    print(
        f"合并完成，共输出 {len(merged)} 条记录 -> {output_path}\n"
        f"（覆盖规则：在 preds 中则用 limit_origin，否则用 gemini）"
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="根据 preds 中的 instance_id，用 gemini_limit_origin 覆盖 gemini，生成 gemini_limit.json"
    )
    parser.add_argument(
        "--preds",
        default="result/preds_result/strengthen/v2/gemini_limit/preds.json",
        help="preds.json 路径（包含 instance_id 列表）",
    )
    parser.add_argument(
        "--base",
        default="result/harness_result/strengthen/v2/gemini.json",
        help="原始 gemini 结果 JSON 路径",
    )
    parser.add_argument(
        "--limit-origin",
        default="result/harness_result/strengthen/v2/gemini_limit_origin.json",
        help="限制设置下的 gemini 结果 JSON 路径",
    )
    parser.add_argument(
        "--output",
        default="result/harness_result/strengthen/v2/gemini_limit.json",
        help="输出 gemini_limit.json 路径",
    )
    args = parser.parse_args()

    # 在项目根目录下执行脚本时，这些默认路径是相对根目录的
    merge_gemini(
        preds_path=args.preds,
        base_path=args.base,
        limit_origin_path=args.limit_origin,
        output_path=args.output,
    )


if __name__ == "__main__":
    main()

