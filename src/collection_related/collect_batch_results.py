#!/usr/bin/env python3
"""
将 scale/docker/batchn 中的 JSON 按命名规则合并为三份结果：
- *_docker.json -> result/result.json
- raw_* -> result/raw.json 或 result/raw_n.json（超过 1000 条时按每 1000 条分片）
- 既无 raw_ 前缀也无 _docker 后缀 -> result/detail.json 或 result/detail_n.json（同上）
"""

import argparse
import json
import os
import sys

CHUNK_SIZE = 1000  # raw / detail 分片大小（条）


def ensure_list(data):
    """若为单个对象则包装成单元素列表，否则返回原列表。"""
    if isinstance(data, list):
        return data
    return [data] if data is not None else []


def non_empty_items(data: list) -> list:
    """过滤掉 commits 为空的项（仅用于 raw / detail）。"""
    out = []
    for x in data:
        if not isinstance(x, dict):
            out.append(x)
            continue
        if "commits" not in x:
            out.append(x)
            continue
        commits = x["commits"]
        if isinstance(commits, list) and len(commits) == 0:
            continue
        out.append(x)
    return out


def collect_batch(batch_dir: str) -> None:
    batch_dir = os.path.abspath(batch_dir)
    if not os.path.isdir(batch_dir):
        raise FileNotFoundError(f"批次目录不存在: {batch_dir}")

    result_dir = os.path.join(batch_dir, "result")
    os.makedirs(result_dir, exist_ok=True)

    result_list = []
    raw_list = []
    detail_list = []

    for name in sorted(os.listdir(batch_dir)):
        if not name.endswith(".json"):
            continue
        path = os.path.join(batch_dir, name)
        if not os.path.isfile(path):
            continue

        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            print(f"跳过无效或不可读文件 {name}: {e}", file=sys.stderr)
            continue

        base = name[:-5]  # 去掉 .json
        if base.endswith("_docker"):
            # 带 docker 后缀 -> result.json
            result_list.extend(ensure_list(data))
        elif base.startswith("raw_"):
            # raw 前缀 -> raw.json（跳过空项目）
            raw_list.extend(non_empty_items(ensure_list(data)))
        else:
            # 既无前缀也无后缀 -> detail.json（跳过空项目）
            detail_list.extend(non_empty_items(ensure_list(data)))

    def write_json(filepath: str, data: list) -> None:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def write_chunked(basename: str, data: list) -> list[str]:
        """若 data 超过 CHUNK_SIZE 条则按 CHUNK_SIZE 分片为 basename_n.json，否则单文件 basename.json。返回生成的文件名列表。"""
        if len(data) <= CHUNK_SIZE:
            path = os.path.join(result_dir, f"{basename}.json")
            write_json(path, data)
            return [f"{basename}.json"]
        paths = []
        for i in range(0, len(data), CHUNK_SIZE):
            chunk = data[i : i + CHUNK_SIZE]
            n = i // CHUNK_SIZE + 1
            path = os.path.join(result_dir, f"{basename}_{n}.json")
            write_json(path, chunk)
            paths.append(f"{basename}_{n}.json")
        return paths

    write_json(os.path.join(result_dir, "result.json"), result_list)
    write_chunked("raw", raw_list)
    write_chunked("detail", detail_list)

    print(
        f"已写入 {result_dir}: result={len(result_list)} 条, "
        f"raw={len(raw_list)} 条, detail={len(detail_list)} 条"
    )


def main():
    parser = argparse.ArgumentParser(
        description="将 batchn 中按命名规则分类的 JSON 合并为 result/result.json、raw.json、detail.json"
    )
    parser.add_argument(
        "batch_dir",
        help="批次目录，例如 scale/docker/batch1 或 scale/docker/batch5",
    )
    args = parser.parse_args()
    collect_batch(args.batch_dir)


if __name__ == "__main__":
    main()
