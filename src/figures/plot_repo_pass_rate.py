#!/usr/bin/env python3
"""
绘制repo级别的通过率分布

Usage:
    python plot_repo_pass_rate.py --result_file result/final_stat_result/result/0307.json --output repo_pass_rate.pdf --top 20

运行前: conda activate all
"""

import argparse
import json
import matplotlib
import matplotlib.pyplot as plt

matplotlib.use("Agg")
plt.rcParams.update({
    "font.size": 11,
    "font.family": "sans-serif",
    "font.weight": "bold",
    "axes.labelweight": "bold",
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.alpha": 0.15,
    "grid.linestyle": "--",
    "figure.facecolor": "#fafafa",
    "axes.facecolor": "#fafafa",
})

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--result_file', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--top', type=int, default=20)
    args = parser.parse_args()

    with open(args.result_file, encoding="utf-8") as f:
        data = json.load(f)

    repo_stats = {}
    for item in data:
        repo = item.get("repo", "unknown")
        if repo not in repo_stats:
            repo_stats[repo] = {"total": 0, "resolved": 0}
        repo_stats[repo]["total"] += 1
        if item.get("resolved", False):
            repo_stats[repo]["resolved"] += 1

    repos = sorted(repo_stats.items(), key=lambda x: x[1]["total"], reverse=True)[:args.top]
    labels = [r[0].split('/')[-1] if '/' in r[0] else r[0] for r in repos]
    pass_rates = [r[1]["resolved"] / r[1]["total"] * 100 if r[1]["total"] > 0 else 0 for r in repos]

    fig, ax = plt.subplots(figsize=(12, 8))
    ax.barh(labels, pass_rates, color="#5B8DEF", edgecolor="white", linewidth=0.5, zorder=3)
    ax.set_xlabel('Pass Rate (%)', fontsize=10, color="#555")
    ax.set_xlim(0, 100)
    ax.invert_yaxis()

    plt.tight_layout()
    fig.savefig(args.output, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {args.output}")

if __name__ == '__main__':
    main()
