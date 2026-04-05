import argparse
import json


def remove_commits(input, output, key, value):
    with open(input, 'r', encoding='utf-8') as f:
        data = json.load(f)

    filtered_data = []

    for item in data:
        if not (item.get(key) and item[key] == value):
            filtered_data.append(item)

    print(f'commits: {len(filtered_data)}')

    with open(output, 'w', encoding='utf-8') as f:
        json.dump(filtered_data, f, indent=2, ensure_ascii=False)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description="按字段值过滤掉匹配项")
    ap.add_argument("--input", default="./scale/docker/result.json")
    ap.add_argument("--output", default="./scale/docker/final_result.json")
    ap.add_argument("--key", default="language")
    ap.add_argument("--value", default="javascript", help="该 key 等于此值的条目被删除")
    args = ap.parse_args()
    remove_commits(args.input, args.output, args.key, args.value)