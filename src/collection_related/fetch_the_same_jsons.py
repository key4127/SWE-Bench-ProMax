import argparse
import json
from pathlib import Path


def fetch_the_same_json(postfix, input, output):
    data = []

    dir_path = Path(input)

    for item in dir_path.rglob(f'*{postfix}'):
        with open(item, 'r', encoding='utf-8') as f:
            item_data = json.load(f)
            data.extend(item_data)

    print(f'commit num: {len(data)}')

    with open(output, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description="合并目录下匹配后缀的 JSON 数组")
    ap.add_argument("--postfix", default="_docker_res.json", help="文件名后缀过滤")
    ap.add_argument("--input", default="./auto_env_config_report/batch5/", help="搜索根目录")
    ap.add_argument("--output", default="./data_for_agent/eval/batch5/batch5.json")
    args = ap.parse_args()
    fetch_the_same_json(args.postfix, args.input, args.output)