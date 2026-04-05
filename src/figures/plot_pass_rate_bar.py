#!/usr/bin/env python3
"""
Pass Rate Bar Chart - 对比多个模型的通过率

Usage:
    python plot_pass_rate_bar.py --input result.json --output pass_rate.pdf

Input format (result.json):
    {
        "model_a": {"resolved": 45, "total": 100},
        "model_b": {"resolved": 62, "total": 100}
    }

运行前: conda activate all
"""

import argparse
import json
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

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()

    with open(args.input, encoding="utf-8") as f:
        data = json.load(f)

    models = list(data.keys())
    pass_rates = [data[m]["resolved"] / data[m]["total"] * 100 for m in models]

    fig, ax = plt.subplots(figsize=(10, 6))
    x = np.arange(len(models))
    bars = ax.bar(x, pass_rates, width=0.6, color="#5B8DEF", edgecolor="white", linewidth=0.5, zorder=3)

    ax.set_xticks(x)
    ax.set_xticklabels(models, fontsize=11)
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
