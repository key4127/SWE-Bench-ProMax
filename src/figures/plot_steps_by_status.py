#!/usr/bin/env python3
"""
对比resolved和unresolved实例的trajectory步数分布

Usage:
    python plot_steps_by_status.py --result_file result/final_stat_result/result/0307.json --output steps_by_status.pdf

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
    args = parser.parse_args()

    with open(args.result_file, encoding="utf-8") as f:
        data = json.load(f)

    resolved_steps = [item.get("trajectory_steps", 0) for item in data
                     if item.get("resolved", False) and "trajectory_steps" in item]
    unresolved_steps = [item.get("trajectory_steps", 0) for item in data
                       if not item.get("resolved", False) and "trajectory_steps" in item]

    fig, ax = plt.subplots(figsize=(10, 6))
    bp = ax.boxplot([resolved_steps, unresolved_steps], labels=["Resolved", "Unresolved"], patch_artist=True)

    for patch, color in zip(bp['boxes'], ["#43B581", "#E07B54"]):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)

    ax.set_ylabel('Trajectory Steps', fontsize=10, color="#555")

    plt.tight_layout()
    fig.savefig(args.output, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {args.output}")

if __name__ == '__main__':
    main()
