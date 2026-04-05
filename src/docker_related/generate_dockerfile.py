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


def main(inputs: list[str], passes: str, filter_id: str, output_dir: str) -> None:
    exclude_ids = load_exclude_ids(filter_id) if filter_id else set()

    docker_data = {}
    for input_path in inputs:
        with open(input_path, "r", encoding="utf-8") as f:
            cur_data = json.load(f)
            docker_data.update(cur_data)
    with open(passes, "r", encoding="utf-8") as f:
        passes_ids = json.load(f)

    count = 0
    for item in docker_data.values():
        if item.get("instance_id") in passes_ids and item.get("instance_id") not in exclude_ids:
            count += 1
            dockerfile = item.get("dockerfile")
            output = f"{output_dir.rstrip('/')}/{item.get('instance_id')}_Dockerfile"
            with open(output, "w", encoding="utf-8") as f:
                f.write(dockerfile)

    print(f"total count: {count}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="从 docker_res json 写出 Dockerfile 文件")
    ap.add_argument(
        "--input",
        action="append",
        dest="inputs",
        required=True,
        help="versions_docker_res.json（可多次指定）",
    )
    ap.add_argument("--passes", default="./auto_env_config_report/batch5_2/resolved_instances.json")
    ap.add_argument("--filter-id", default="./auto_env_config_report/batch5_1/resolved_instances.json")
    ap.add_argument("--output-dir", default="./dockerfile/batch5_2", help="Dockerfile 输出目录")
    args = ap.parse_args()
    main(args.inputs, args.passes, args.filter_id, args.output_dir)
