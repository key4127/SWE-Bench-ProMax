#!/usr/bin/env python3
"""
Merge all batch data from main/data/ into standard/clean-data/.
Uses swe-format instance_ids as the source of truth; golden and eval
are filtered to only include matching entries.

Output:
  - clean-data/swe-format/all.json  (JSON array, for load_dataset)
  - clean-data/golden.json          (JSON array)
  - clean-data/eval.json            (JSON dict)

Usage:
    python scripts/merge_batches.py
"""

import json
import argparse
from pathlib import Path


def merge_json_arrays(files: list[Path]) -> list:
    merged = []
    seen_ids = set()
    for f in sorted(files):
        data = json.loads(f.read_text(encoding="utf-8"))
        for item in data:
            iid = item.get("instance_id", "")
            if iid not in seen_ids:
                seen_ids.add(iid)
                merged.append(item)
    return merged


def merge_json_dicts(files: list[Path]) -> dict:
    merged = {}
    for f in sorted(files):
        data = json.loads(f.read_text(encoding="utf-8"))
        merged.update(data)
    return merged


def save_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  -> {path}  ({len(data)} entries)")


def main():
    script_dir = Path(__file__).resolve().parent
    default_src = script_dir.parent.parent / "main" / "data"
    default_dst = script_dir.parent / "clean-data"

    parser = argparse.ArgumentParser(description="Merge all batch data (using swe-format as source of truth)")
    parser.add_argument("--src", type=Path, default=default_src, help="Source data directory (default: ../main/data)")
    parser.add_argument("--dst", type=Path, default=default_dst, help="Output directory (default: clean-data)")
    args = parser.parse_args()

    src: Path = args.src
    dst: Path = args.dst

    # 1. swe-format is the primary source, defines the valid instance_id set
    print("Merging swe-format ...")
    swe_files = sorted(src.glob("swe-format/batch*/batch*.json"))
    swe_data = merge_json_arrays(swe_files)
    valid_ids = {item["instance_id"] for item in swe_data}
    save_json(dst / "swe-format" / "all.json", swe_data)

    # 2. golden: only keep entries present in swe-format
    print("Merging golden (filtered by swe-format) ...")
    golden_files = sorted(src.glob("golden/batch*.json"))
    golden_all = merge_json_arrays(golden_files)
    golden_data = [item for item in golden_all if item["instance_id"] in valid_ids]
    save_json(dst / "golden.json", golden_data)

    # 3. eval: only keep entries present in swe-format
    print("Merging eval (filtered by swe-format) ...")
    eval_files = sorted(src.glob("eval/batch*.json"))
    eval_all = merge_json_dicts(eval_files)
    eval_data = {k: v for k, v in eval_all.items() if k in valid_ids}
    save_json(dst / "eval.json", eval_data)

    print(f"\nDone! {len(swe_data)} swe-format / {len(golden_data)} golden / {len(eval_data)} eval")
    if len(golden_data) < len(swe_data):
        missing = valid_ids - {item["instance_id"] for item in golden_data}
        print(f"  Warning: {len(missing)} swe-format entries missing golden patch")
    if len(eval_data) < len(swe_data):
        missing = valid_ids - set(eval_data.keys())
        print(f"  Warning: {len(missing)} swe-format entries missing eval config")


if __name__ == "__main__":
    main()
