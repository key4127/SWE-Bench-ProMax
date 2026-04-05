import argparse
import json


def main(inputs: list[str], passes: str, output_dir: str) -> None:
    docker_data = {}
    for input_path in inputs:
        with open(input_path, "r", encoding="utf-8") as f:
            cur_data = json.load(f)
            docker_data.update(cur_data)
    with open(passes, "r", encoding="utf-8") as f:
        passes_ids = json.load(f)

    count = 0
    for item in docker_data.values():
        if item.get("instance_id") in passes_ids:
            count += 1
            test_script = item.get("eval_script")
            output = f"{output_dir.rstrip('/')}/{item.get('instance_id')}.sh"
            with open(output, "w", encoding="utf-8") as f:
                f.write(test_script)

    print(f"total count: {count}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="写出 eval shell 脚本")
    ap.add_argument(
        "--input",
        action="append",
        dest="inputs",
        required=True,
        help="versions_docker_res.json（可多次指定）",
    )
    ap.add_argument("--passes", default="./auto_env_config_report/batch5_2/resolved_instances.json")
    ap.add_argument("--output-dir", default="./test_scripts/batch5", help=".sh 输出目录")
    args = ap.parse_args()
    main(args.inputs, args.passes, args.output_dir)
