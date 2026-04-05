import argparse
import json
from pathlib import Path


def fetch_the_same_json(input_dir, passes):
    with open(passes, "r", encoding="utf-8") as f:
        passes_ids = json.load(f)

    data = []

    dir_path = Path(input_dir)

    for item in dir_path.rglob("*"):
        if not item.name.endswith("_docker.json"):
            with open(item, "r", encoding="utf-8") as f:
                item_raw_data = json.load(f)

                item_data = []
                data.extend(item_data)

    print(f"commit num: {len(data)}")

    return data


def main(inputs: list[str]) -> None:
    data = []
    for input_path in inputs:
        with open(input_path, "r", encoding="utf-8") as f:
            cur_data = json.load(f)
            data.extend(cur_data)

    repo_set = set()
    repo_count = {
        "go": 0,
        "python": 0,
        "java": 0,
        "c++": 0,
        "c": 0,
        "rust": 0,
        "typescript": 0,
    }
    ins_count = {
        "go": 0,
        "python": 0,
        "java": 0,
        "c++": 0,
        "c": 0,
        "rust": 0,
        "typescript": 0,
    }

    for item in data:
        repo = item.get("repo")
        language = item.get("language")
        if repo not in repo_set:
            repo_count[language] += 1
            repo_set.add(repo)
        ins_count[language] += 1

    print(repo_count)


_DEFAULT_INPUTS = [
    "./data_for_agent/batch1/batch1.json",
    "./data_for_agent/batch2/batch2.json",
    "./data_for_agent/batch3/batch3.json",
    "./data_for_agent/batch4/batch4_1.json",
]


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="按语言统计仓库数 / 实例数")
    ap.add_argument(
        "--input",
        action="append",
        dest="inputs",
        default=None,
        help="swe-format JSON 路径（可多次指定；不传则用内置默认 batch1–4 列表）",
    )
    args = ap.parse_args()
    main(args.inputs if args.inputs else _DEFAULT_INPUTS)
