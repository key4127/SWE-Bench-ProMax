#!/usr/bin/env python3
"""
从 result/strengthen/v1/explain_over_narrow_result.json 读取所有 over_narrow 实例，
输出每条实例的 instance_id 与 len(over_narrow_findings)。
结果 JSON 写入脚本所在目录：narrow_len_all.json。
"""

import json
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = _SCRIPT_DIR.parents[2]

V1_EXPLAIN_OVER_NARROW = PROJECT_ROOT / "result/strengthen/v1/explain_over_narrow_result.json"
OUTPUT_PATH = _SCRIPT_DIR / "narrow_len_all.json"


def main() -> None:
    with open(V1_EXPLAIN_OVER_NARROW, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        data = []

    out = []
    for rec in data:
        iid = rec.get("instance_id")
        if not iid:
            continue
        findings = rec.get("over_narrow_findings")
        if not isinstance(findings, list):
            findings = []
        out.append({
            "instance_id": iid,
            "len_over_narrow_findings": len(findings),
        })

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)

    print(f"Total: {len(out)}")
    print(f"Written: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
