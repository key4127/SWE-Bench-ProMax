#!/usr/bin/env python3
"""
统计某个 pass_rate.json 的结果并输出到 stdout。
统计时排除写死在脚本中的 discard 实例（原 all_nl_enhanced 中 discard 为 true 的 instance_id）。
不依赖 harness 包，仅做统计输出。
"""

import argparse
import json
import sys
from pathlib import Path

DISCARD_INSTANCE_IDS: frozenset[str] = frozenset({
    "aws__s2n-tls-5552",
    "betaflight__betaflight-14156",
    "betaflight__betaflight-14174",
    "betaflight__betaflight-14229",
    "betaflight__betaflight-c_9230c5f",
    "betaflight__betaflight-c_d3c113b",
    "espressif__esp-idf-c_5812b19",
    "espressif__esp-idf-c_b385b6e",
    "espressif__esp-idf-c_b59b366",
    "espressif__esp-idf-c_e94d9ce",
    "openssl__openssl-c_3638ffc",
    "Icinga__icinga2-10432",
    "QuEST-Kit__QuEST-653",
    "at-wat__mcl_3dl-435",
    "danmar__cppcheck-8030",
    "deskflow__deskflow-c_05f377e",
    "deskflow__deskflow-c_a78959e",
    "deskflow__deskflow-c_a8348b1",
    "deskflow__deskflow-c_bee0f84",
    "deskflow__deskflow-c_cfedfc2",
    "deskflow__deskflow-c_f456aab",
    "google__googletest-c_17d335d",
    "nasa__fprime-4340",
    "TecharoHQ__anubis-158",
    "TecharoHQ__anubis-368",
    "TecharoHQ__anubis-657",
    "antonmedv__fx-c_294e473",
    "cli__cli-10354",
    "cli__cli-10720",
    "cli__cli-11752",
    "cli__cli-c_d684834",
    "gin__gin-gonic-3963",
    "grpc__grpc-go-8750",
    "jesseduffield__lazygit-4953",
    "livekit__livekit-4198",
    "pingcap__tidb-59644",
    "restic__restic-5173",
    "restic__restic-5494",
    "restic__restic-5550",
    "restic__restic-c_b7bbb40",
    "rqlite__rqlite-2057",
    "rqlite__rqlite-2145",
    "samber__lo-756",
    "spf13__cobra-2231",
    "spf13__viper-c_d8387f6",
    "trufflesecurity__trufflehog-3134",
    "apache__calcite-4390",
    "apache__calcite-c_6e664e9",
    "apache__fesod-413",
    "apache__fesod-533",
    "apache__fesod-567",
    "apache__fesod-658",
    "apache__fesod-772",
    "apache__hbase-7540",
    "apache__iceberg-12167",
    "apache__maven-11322",
    "apache__maven-9311",
    "apache__pinot-16723",
    "bazelbuild__bazel-c_37a74a7",
    "google__gson-2951",
    "nacos__alibaba-13142",
    "AtsushiSakai__PythonRobotics-1211",
    "albumentations-team__albumentations-2325",
    "camel-ai__camel-3015",
    "crewAIInc__crewAI-3289",
    "crewAIInc__crewAI-3420",
    "google__adk-python-1200",
    "google__adk-python-2388",
    "google__adk-python-c_0487eea",
    "google__adk-python-c_5b7c8c0",
    "jax-ml__jax-26383",
    "jax-ml__jax-26556",
    "letta-ai__letta-c_d81382b",
    "pandas-dev__pandas-59636",
    "stanfordnlp__dspy-9193",
    "unclecode__crawl4ai-c_2ab0bf2",
    "verl-project__verl-2410",
    "astral-sh__ruff-21445",
    "firecracker-microvm__firecracker-c_0fa8dfc",
    "fish-shell__fish-shell-c_61ee695",
    "jj-vcs__jj-7231",
    "jj-vcs__jj-8691",
    "qdrant__qdrant-c_3942071",
    "qdrant__qdrant-c_51b3a62",
    "tracel-ai__burn-4337",
    "angular__angular-66350",
    "angular__angular-c_04c2447",
    "angular__angular-c_2563f39",
    "angular__angular-c_6783fb7",
    "angular__angular-c_afea8a9",
    "angular__angular-c_db95a5c",
    "angular__angular-c_e77df14",
    "ant-design__ant-design-52470",
    "ant-design__ant-design-53106",
    "ant-design__ant-design-53133",
    "ant-design__ant-design-53311",
    "ant-design__ant-design-53401",
    "ant-design__ant-design-53983",
    "ant-design__ant-design-54415",
    "ant-design__ant-design-54416",
    "ant-design__ant-design-55478",
    "ant-design__ant-design-56053",
    "ant-design__ant-design-56250",
})


def main() -> None:
    parser = argparse.ArgumentParser(
        description="统计 pass_rate.json 并输出到 stdout，排除写死的 discard 实例"
    )
    parser.add_argument(
        "--pass-rate",
        "-p",
        required=True,
        help="pass_rate.json 路径",
    )
    args = parser.parse_args()

    pass_rate_path = Path(args.pass_rate)
    if not pass_rate_path.exists():
        print(f"Error: pass_rate 文件不存在: {pass_rate_path}", file=sys.stderr)
        sys.exit(1)

    exclude_ids = DISCARD_INSTANCE_IDS

    with open(pass_rate_path, "r", encoding="utf-8") as f:
        results_list = json.load(f)
    if not isinstance(results_list, list):
        print("Error: pass_rate.json 应为 list 格式", file=sys.stderr)
        sys.exit(1)

    filtered = [r for r in results_list if r.get("instance_id") not in exclude_ids]
    n_excluded = len(results_list) - len(filtered)
    if n_excluded:
        n_discard = sum(1 for r in results_list if r.get("instance_id") in exclude_ids)
        print(f"Excluded {n_excluded} instances ({n_discard} discard).\n", file=sys.stderr)

    lang_map = {r["instance_id"]: r.get("language", "unknown") or "unknown" for r in filtered}
    _print_pass_rate_summary(filtered, lang_map)


def _print_pass_rate_summary(results_list: list, lang_map: dict) -> None:
    """仅统计并输出到 stdout，不依赖 harness。"""
    total = sum(1 for r in results_list if r.get("golden", {}).get("final_result") == "success")
    if total == 0:
        print("\nNo results to summarize.")
        return
    passed = sum(1 for r in results_list if r.get("passed", False))
    print(f"\n{'='*60}")
    print(f"  Overall: {passed}/{total} passed ({100*passed/total:.1f}%)")
    print(f"{'='*60}")

    lang_stats: dict = {}
    for r in results_list:
        if r.get("golden", {}).get("final_result") != "success":
            continue
        lang = lang_map.get(r.get("instance_id"), "unknown")
        stats = lang_stats.setdefault(lang, {"total": 0, "passed": 0})
        stats["total"] += 1
        if r.get("passed", False):
            stats["passed"] += 1

    print(f"  {'Language':<15} {'Passed':>8} {'Total':>8} {'Rate':>8}")
    print(f"  {'-'*15} {'-'*8} {'-'*8} {'-'*8}")
    for lang in sorted(lang_stats, key=lambda l: -lang_stats[l]["total"]):
        s = lang_stats[lang]
        rate = 100 * s["passed"] / s["total"] if s["total"] else 0
        print(f"  {lang:<15} {s['passed']:>8} {s['total']:>8} {rate:>7.1f}%")

    reason_counts: dict = {}
    for r in results_list:
        reason = r.get("model", {}).get("final_result", "unknown")
        reason_counts[reason] = reason_counts.get(reason, 0) + 1
    total_results = len(results_list)
    print(f"\n  Results:")
    for reason, count in sorted(reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_results if total_results else 0
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
