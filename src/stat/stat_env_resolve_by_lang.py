#!/usr/bin/env python3
"""
统计 auto_env_config_report 五个 batch 合并后，各语言配环境 resolve 的成功率。
源数据：scale/docker/batchn/result/ 下的 JSON；resolve 结果：auto_env_config_report/batchn/resolved_instances.json
"""
import json
import os
from collections import defaultdict

# 项目根目录（脚本在 src/stat/ 下时，根目录为 ../..）
REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# report batch -> (scale batch 名, result 目录下要读取的 json 文件名列表)
# 不计算 batch4（batch4_1 与 scale batch4 的对应关系不明确）
BATCH_CONFIG = [
    ("batch1", "batch1", ["result.json"]),
    ("batch2", "batch2", ["result.json"]),
    ("batch3", "batch3", ["result.json"]),
    ("batch5", "batch5", ["result.json"]),  # batch5_result_1/2 与 result.json 有重叠，只读 result.json
]


def load_result_instances(scale_batch: str, result_files: list) -> dict:
    """加载 scale/docker/{batch}/result/ 下的实例，返回 instance_id -> language（去重保留第一条）。"""
    out = {}
    result_dir = os.path.join(REPO_ROOT, "scale", "docker", scale_batch, "result")
    for fname in result_files:
        path = os.path.join(result_dir, fname)
        if not os.path.isfile(path):
            continue
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, list):
            data = [data]
        for item in data:
            iid = item.get("instance_id")
            if iid is None:
                continue
            if iid not in out:
                out[iid] = (item.get("language") or "unknown").strip().lower()
    return out


def load_resolved_set(report_batch: str) -> set:
    """加载 auto_env_config_report/{batch}/resolved_instances.json，返回 resolve 成功的 instance_id 集合。"""
    path = os.path.join(REPO_ROOT, "auto_env_config_report", report_batch, "resolved_instances.json")
    if not os.path.isfile(path):
        return set()
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return set(data) if isinstance(data, list) else set()


def main():
    # 汇总：按语言 -> total_count, resolved_count
    lang_total = defaultdict(int)
    lang_resolved = defaultdict(int)

    for report_batch, scale_batch, result_files in BATCH_CONFIG:
        instances = load_result_instances(scale_batch, result_files)
        resolved = load_resolved_set(report_batch)

        for iid, lang in instances.items():
            lang_total[lang] += 1
            if iid in resolved:
                lang_resolved[lang] += 1

    # 输出
    print("Language | Total | Resolved | Success Rate")
    print("-" * 50)
    total_all = 0
    resolved_all = 0
    for lang in sorted(lang_total.keys()):
        total = lang_total[lang]
        resolved = lang_resolved[lang]
        total_all += total
        resolved_all += resolved
        rate = (resolved / total * 100) if total else 0
        print(f"{lang:12} | {total:5} | {resolved:8} | {rate:.2f}%")
    print("-" * 50)
    overall = (resolved_all / total_all * 100) if total_all else 0
    print(f"{'Total':12} | {total_all:5} | {resolved_all:8} | {overall:.2f}%")


if __name__ == "__main__":
    main()
