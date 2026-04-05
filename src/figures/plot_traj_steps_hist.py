#!/usr/bin/env python3
"""
绘制trajectory步数分布直方图

Usage:
    python plot_traj_steps_hist.py --result_file result/final_stat_result/result/0307.json --output hist.pdf

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
    parser.add_argument('--bins', type=int, default=20)
    args = parser.parse_args()

    with open(args.result_file, encoding="utf-8") as f:
        data = json.load(f)

    steps = [item.get("trajectory_steps", 0) for item in data if "trajectory_steps" in item]

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.hist(steps, bins=args.bins, color="#5B8DEF", alpha=0.7, edgecolor="white", linewidth=0.5, zorder=3)

    ax.set_xlabel('Trajectory Steps', fontsize=10, color="#555")
    ax.set_ylabel('Frequency', fontsize=10, color="#555")

    plt.tight_layout()
    fig.savefig(args.output, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {args.output}")

if __name__ == '__main__':
    main()
