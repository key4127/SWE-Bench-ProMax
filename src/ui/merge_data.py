import argparse
import json
from pathlib import Path

_UI_DIR = Path(__file__).resolve().parent
_DATA_DIR = _UI_DIR / "data"


def load_raw_records(path: str) -> list:
    """Load JSON array (.json) or JSONL (.jsonl / one object per line)."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    text = text.strip()
    if not text:
        return []
    if text[0] == "[":
        return json.loads(text)
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def main(raw_path: str, merged_json: str, out_path: str) -> None:
    raw = load_raw_records(raw_path)
    with open(merged_json) as f:
        merged = {m["instance_id"]: m for m in json.load(f)}

    EXTRA_FIELDS = [
        "PASS_TO_PASS",
        "FAIL_TO_PASS",
        "dockerfile",
        "eval_script",
        "setup_scripts",
    ]

    for r in raw:
        m = merged.get(r["instance_id"], {})
        for field in EXTRA_FIELDS:
            r[field] = m.get(field, None)

    with open(out_path, "w") as f:
        json.dump(raw, f, indent=2, ensure_ascii=False)

    print(f"Done: {len(raw)} records, {len(raw[0].keys())} fields")
    print("Fields:", sorted(raw[0].keys()))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="合并 raw json/jsonl 与 promax merged json")
    ap.add_argument(
        "--raw",
        default=str(_DATA_DIR / "raw_latest.json"),
        help="原始 JSON 数组或 JSONL（默认 data/raw_latest.json）",
    )
    ap.add_argument(
        "--merged-json",
        default=str(_DATA_DIR / "swe-bench-promax-merged.json"),
        help="含扩展字段的 JSON 数组",
    )
    ap.add_argument(
        "--output",
        default=str(_DATA_DIR / "raw_latest.json"),
        help="输出 JSON",
    )
    args = ap.parse_args()
    main(args.raw, args.merged_json, args.output)
