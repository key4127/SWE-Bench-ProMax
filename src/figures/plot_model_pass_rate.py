#!/usr/bin/env python3
"""
对比多个模型在不同数据集上的通过率

Usage:
    python plot_model_pass_rate.py file1.json file2.json file3.json

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

_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", ".."))

def load_result(path):
    """加载result JSON文件并统计resolved数量"""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    total = len(data)
    resolved = sum(1 for item in data if item.get("resolved", False))
    return resolved, total

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('files', nargs='+', help='pass_rate文件路径列表')
    parser.add_argument('--output', default='./img/pass_rate.pdf', help='输出图片路径')
    args = parser.parse_args()

    os.makedirs(os.path.dirname(args.output) or '.', exist_ok=True)

    labels = []
    pass_rates = []

    for path in args.files:
        if os.path.exists(path):
            resolved, total = load_result(path)
            pass_rates.append(resolved / total * 100 if total > 0 else 0)
            labels.append(os.path.basename(path).replace('.json', ''))
        else:
            print(f"警告: 文件不存在 {path}")
            pass_rates.append(0)
            labels.append(os.path.basename(path).replace('.json', ''))

    fig, ax = plt.subplots(figsize=(10, 6))
    x = np.arange(len(labels))
    bars = ax.bar(x, pass_rates, width=0.6, color="#5B8DEF", edgecolor="white", linewidth=0.5, zorder=3)

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
