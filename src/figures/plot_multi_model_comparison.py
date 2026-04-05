#!/usr/bin/env python3
"""
对比多个模型在同一数据集上的通过率（分组柱状图）

Usage:
    python plot_multi_model_comparison.py --result_dir result/final_stat_result/result --files 0307.json 0225.json --output multi_model.pdf

运行前: conda activate all
"""

import argparse
import json
import os
import matplotlib
import matplotlib.pyplot as plt
import numpy as np

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

COLORS = ["#5B8DEF", "#E07B54", "#43B581", "#FAA61A"]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--result_dir', required=True)
    parser.add_argument('--files', nargs='+', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    labels = [f.replace('.json', '') for f in args.files]
    pass_rates = []

    for fname in args.files:
        fpath = os.path.join(args.result_dir, fname)
        with open(fpath, encoding="utf-8") as f:
            data = json.load(f)
        total = len(data)
        resolved = sum(1 for item in data if item.get("resolved", False))
        pass_rates.append(resolved / total * 100 if total > 0 else 0)

    fig, ax = plt.subplots(figsize=(10, 6))
    x = np.arange(len(labels))
    bars = ax.bar(x, pass_rates, width=0.6, color=COLORS, edgecolor="white", linewidth=0.5, zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=11)
    ax.set_ylabel("Pass Rate (%)", fontsize=10, color="#555")
    ax.set_ylim(0, 100)

    for bar in bars:
        h = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2, h + 1, f'{h:.1f}%', ha='center', va='bottom', fontsize=9)

    plt.tight_layout()
    fig.savefig(args.output, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {args.output}")

if __name__ == '__main__':
    main()
