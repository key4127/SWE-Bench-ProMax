import argparse
from pathlib import Path
import json
import random


def random_select(input, output):
    with open(input, 'r', encoding='utf-8') as f:
        data = json.load(f)

    k = min(10, len(data))
    
    selected = random.sample(data, k)
    selected_url = []

    for select in selected:
        selected_url.append({
            "html_url": select["html_url"]
        })

    with open(output, 'w', encoding='utf-8') as f:
        json.dump(selected_url, f, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="从各 repo json 随机抽若干条 html_url")
    ap.add_argument("--pass-ci-dir", default="./filtered_data/pass_ci", help="输入 json 目录前缀")
    ap.add_argument("--output-dir", default="./filtered_data/part_of_test", help="输出 json 目录前缀")
    ap.add_argument(
        "repos",
        nargs="*",
        default=["airflow"],
        help="仓库短名列表（默认: airflow）",
    )
    args = ap.parse_args()
    for repo in args.repos:
        random_select(
            f"{args.pass_ci_dir.rstrip('/')}/{repo}.json",
            f"{args.output_dir.rstrip('/')}/{repo}.json",
        )