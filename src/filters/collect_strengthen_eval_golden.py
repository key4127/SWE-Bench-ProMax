#!/usr/bin/env python3
"""
遍历 result/final_stat_result/result/strengthen.json，
在 data_for_agent/eval 和 data_for_agent/swe-format 中找到所有 instance_id 一致的实例，
组合为 strengthen_eval.json 和 strengthen_golden.json，与 strengthen.json 放在同一目录。

也可用 --by-swe 指定 swe-format 下的某个 JSON（如 0226.json），
以其中 instance_id 为白名单，从 eval 下所有 batch 中筛选并输出到 data_for_agent/eval/<name>.json。
"""

import json
import argparse
from pathlib import Path

# 路径：以项目根为准（脚本在 src/pipeline/strengthen/，parents[3] 为项目根）
PROJECT_ROOT = Path(__file__).resolve().parents[3]
STRENGTHEN_JSON = PROJECT_ROOT / "result/final_stat_result/result/strengthen.json"
OUTPUT_DIR = PROJECT_ROOT / "result/final_stat_result/result"
EVAL_DIR = PROJECT_ROOT / "data_for_agent/eval"
SWE_FORMAT_DIR = PROJECT_ROOT / "data_for_agent/swe-format"


def load_strengthen_ids(path: Path) -> set[str]:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError("strengthen.json 应为 list")
    return {item["instance_id"] for item in data if item.get("instance_id")}


def load_swe_format_ids(path: Path) -> set[str]:
    """从 swe-format 的 JSON（list 或 dict）中读取所有 instance_id。"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if isinstance(data, list):
        return {item["instance_id"] for item in data if isinstance(item, dict) and item.get("instance_id")}
    if isinstance(data, dict):
        return {iid for iid, rec in data.items() if isinstance(rec, dict) and rec.get("instance_id")}
    return set()


def load_all_eval_by_id(eval_dir: Path) -> dict[str, dict]:
    """加载 eval 目录下所有 .json，合并为 instance_id -> 条目 的字典。"""
    by_id: dict[str, dict] = {}
    for jpath in sorted(eval_dir.rglob("*.json")):
        with open(jpath, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            for iid, rec in data.items():
                if isinstance(rec, dict) and rec.get("instance_id"):
                    by_id[iid] = rec
        elif isinstance(data, list):
            for rec in data:
                if isinstance(rec, dict) and rec.get("instance_id"):
                    by_id[rec["instance_id"]] = rec
    return by_id


def load_all_swe_by_id(swe_dir: Path) -> dict[str, dict]:
    """加载 swe-format 目录下所有 .json，合并为 instance_id -> 条目 的字典。"""
    by_id: dict[str, dict] = {}
    for jpath in sorted(swe_dir.rglob("*.json")):
        with open(jpath, encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            for rec in data:
                if isinstance(rec, dict) and rec.get("instance_id"):
                    by_id[rec["instance_id"]] = rec
        elif isinstance(data, dict):
            for iid, rec in data.items():
                if isinstance(rec, dict) and rec.get("instance_id"):
                    by_id[iid] = rec
    return by_id


def run_by_swe(swe_name: str) -> None:
    """以 swe-format/<swe_name>.json 中的 instance_id 为白名单，从 eval 所有 batch 中筛选并写入 data_for_agent/eval/<swe_name>.json。"""
    swe_file = SWE_FORMAT_DIR / f"{swe_name}.json"
    if not swe_file.exists():
        raise FileNotFoundError(f"未找到: {swe_file}")

    valid_ids = load_swe_format_ids(swe_file)
    print(f"{swe_file.name} 中共 {len(valid_ids)} 个 instance_id")

    eval_by_id = load_all_eval_by_id(EVAL_DIR)
    print(f"eval 中共 {len(eval_by_id)} 个 instance_id")

    eval_filtered = {iid: eval_by_id[iid] for iid in valid_ids if iid in eval_by_id}
    print(f"匹配到 eval: {len(eval_filtered)} 条")

    out_path = EVAL_DIR / f"{swe_name}.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(eval_filtered, f, ensure_ascii=False, indent=2)
    print(f"已写入: {out_path}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="按 id 白名单从 data_for_agent/eval 与 swe-format 筛选并输出。"
    )
    parser.add_argument(
        "--by-swe",
        metavar="NAME",
        type=str,
        default=None,
        help="用 data_for_agent/swe-format/<NAME>.json 中的 instance_id 为白名单，"
        "筛选 eval 并输出到 data_for_agent/eval/<NAME>.json（如 --by-swe 0226）",
    )
    args = parser.parse_args()

    if args.by_swe is not None:
        run_by_swe(args.by_swe)
        return

    strengthen_path = STRENGTHEN_JSON
    if not strengthen_path.exists():
        raise FileNotFoundError(f"未找到 strengthen.json: {strengthen_path}")

    strengthen_ids = load_strengthen_ids(strengthen_path)
    print(f"strengthen.json 中共 {len(strengthen_ids)} 个 instance_id")

    eval_by_id = load_all_eval_by_id(EVAL_DIR)
    print(f"eval 中共 {len(eval_by_id)} 个 instance_id")

    swe_by_id = load_all_swe_by_id(SWE_FORMAT_DIR)
    print(f"swe-format 中共 {len(swe_by_id)} 个 instance_id")

    # 只保留在 strengthen 中出现的 id
    strengthen_eval = {iid: eval_by_id[iid] for iid in strengthen_ids if iid in eval_by_id}
    strengthen_golden = [swe_by_id[iid] for iid in strengthen_ids if iid in swe_by_id]

    print(f"匹配到 eval: {len(strengthen_eval)} 条")
    print(f"匹配到 swe-format (golden): {len(strengthen_golden)} 条")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    out_eval = OUTPUT_DIR / "strengthen_eval.json"
    out_golden = OUTPUT_DIR / "strengthen_golden.json"

    with open(out_eval, "w", encoding="utf-8") as f:
        json.dump(strengthen_eval, f, ensure_ascii=False, indent=2)
    with open(out_golden, "w", encoding="utf-8") as f:
        json.dump(strengthen_golden, f, ensure_ascii=False, indent=2)

    print(f"已写入: {out_eval}")
    print(f"已写入: {out_golden}")


if __name__ == "__main__":
    main()
