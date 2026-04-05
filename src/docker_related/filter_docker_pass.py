import argparse
import json


def load_exclude_ids(path):
    """从文件中加载要排除的 id 集合。支持 JSON 数组：字符串列表或含 instance_id 的对象列表。"""
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    exclude = set()
    for x in data:
        if isinstance(x, str):
            exclude.add(x)
        elif isinstance(x, dict) and x.get("instance_id") is not None:
            exclude.add(x["instance_id"])
    return exclude


def main(
    raws: list[str],
    passes: str,
    filter_id: str,
    output: str,
) -> None:
    exclude_ids = load_exclude_ids(filter_id) if filter_id else set()

    raw_data = []
    for raw in raws:
        with open(raw, "r", encoding="utf-8") as f:
            cur_data = json.load(f)
            raw_data.extend(cur_data)
    with open(passes, "r", encoding="utf-8") as f:
        passes_ids = json.load(f)

    data = []
    ids = set()

    for item in raw_data:
        if item.get("instance_id") in passes_ids and item.get("instance_id") not in exclude_ids:
            data.append(item)
            if item.get("instance_id") in ids:
                print(item.get("instance_id"))
            ids.add(item.get("instance_id"))

    print(len(passes_ids))
    print(len(data))

    with open(output, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="按 resolved / exclude 过滤 batch 原始 JSON")
    ap.add_argument(
        "--raw",
        action="append",
        dest="raws",
        required=True,
        help="原始结果 JSON（可多次指定）",
    )
    ap.add_argument("--passes", default="./auto_env_config_report/batch5_2/resolved_instances.json")
    ap.add_argument("--filter-id", default="./auto_env_config_report/batch5_1/resolved_instances.json")
    ap.add_argument("--output", default="./data_for_agent/golden/batch5/batch5.json")
    args = ap.parse_args()
    main(args.raws, args.passes, args.filter_id, args.output)
