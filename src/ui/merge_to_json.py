#!/usr/bin/env python3
"""
Merge golden.json, eval.json, and swe-format/all.json into a single JSON file.
"""

import json
from pathlib import Path

DATA_DIR = Path(__file__).resolve().parent / "data"
OUTPUT_PATH = DATA_DIR / "merged.json"


def main():
    golden_path = DATA_DIR / "golden.json"
    eval_path = DATA_DIR / "eval.json"
    all_path = DATA_DIR / "swe-format" / "all.json"

    with open(golden_path) as f:
        golden = {x["instance_id"]: x for x in json.load(f)}

    with open(eval_path) as f:
        eval_data = json.load(f)

    with open(all_path) as f:
        all_data = json.load(f)

    merged = []
    for item in all_data:
        iid = item["instance_id"]
        rec = dict(item)
        if iid in eval_data:
            rec["dockerfile"] = eval_data[iid].get("dockerfile", "")
            rec["eval_script"] = eval_data[iid].get("eval_script", "")
            rec["setup_scripts"] = eval_data[iid].get("setup_scripts", {})
        if iid in golden:
            for k, v in golden[iid].items():
                if k not in rec:
                    rec[k] = v
        merged.append(rec)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)

    print(f"Written {len(merged)} records to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
