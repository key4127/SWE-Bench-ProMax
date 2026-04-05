#!/usr/bin/env python3
"""
根据 categorization_results.json 绘制 Task Categorization Analysis 图表。

生成图表:
  1. Category Distribution (multi-label) — 水平柱状图
  2. How many categories does each instance touch? — 直方图
  3. Reasoning Abilities Distribution — 水平柱状图
  4. Category Co-occurrence Heatmap — 热力图

Usage:
    python plot_categorization.py --input result/strengthen/v3/categorization_results.json
    python plot_categorization.py --input categorization_results.json --output-dir src/categorize/img

运行前: conda activate all
"""

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path

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
    "figure.facecolor": "white",
    "axes.facecolor": "white",
})

ALL_CATEGORIES = [
    "bug_fix", "security_patch", "performance_optimization", "new_feature",
    "api_interface_change", "refactoring_cleanup", "error_handling",
    "dependency_integration", "test_improvement", "documentation_nl",
]

CATEGORY_LABELS = {
    "refactoring_cleanup": "Refactoring Cleanup",
    "api_interface_change": "Api Interface Change",
    "bug_fix": "Bug Fix",
    "new_feature": "New Feature",
    "documentation_nl": "Documentation Nl",
    "error_handling": "Error Handling",
    "dependency_integration": "Dependency Integration",
    "performance_optimization": "Performance Optimization",
    "test_improvement": "Test Improvement",
    "security_patch": "Security Patch",
}

CATEGORY_COLOR_MAP = {
    "refactoring_cleanup":      "#2B579A",
    "api_interface_change":     "#5B9BD5",
    "bug_fix":                  "#ED7D31",
    "new_feature":              "#70AD47",
    "documentation_nl":         "#A5A5A6",
    "error_handling":           "#FFC000",
    "dependency_integration":   "#00B0F0",
    "performance_optimization": "#548235",
    "test_improvement":         "#404040",
    "security_patch":           "#FF0066",
}


def load_results(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return {k: v for k, v in data.items() if v is not None}


def get_all_categories_per_instance(results: dict) -> dict[str, list[str]]:
    """返回 instance_id -> [所有标签列表]（primary + secondary）。"""
    out = {}
    for iid, v in results.items():
        cats = []
        primary = v.get("primary_category", "")
        if primary in ALL_CATEGORIES:
            cats.append(primary)
        for s in v.get("secondary_categories", []):
            if s in ALL_CATEGORIES and s not in cats:
                cats.append(s)
        out[iid] = cats
    return out


def plot_category_distribution(cats_per_instance: dict, output_dir: Path):
    """水平柱状图: Category Distribution (multi-label)。"""
    n = len(cats_per_instance)
    counter = Counter()
    for cats in cats_per_instance.values():
        for c in cats:
            counter[c] += 1

    sorted_cats = counter.most_common()
    labels = [CATEGORY_LABELS.get(c, c) for c, _ in sorted_cats]
    counts = [cnt for _, cnt in sorted_cats]
    pcts = [cnt / n * 100 for cnt in counts]

    colors = [CATEGORY_COLOR_MAP.get(c, "#999") for c, _ in sorted_cats]

    fig, ax = plt.subplots(figsize=(10, 6))
    y = np.arange(len(labels))
    bars = ax.barh(y, pcts, color=colors, edgecolor="white", linewidth=0.5, height=0.7, zorder=3)

    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=16)
    ax.invert_yaxis()
    ax.set_xlabel("% of instances (multi-label, sums > 100%)", fontsize=16, color="#555")

    for bar, cnt, pct in zip(bars, counts, pcts):
        ax.text(
            bar.get_width() + 0.8, bar.get_y() + bar.get_height() / 2,
            f"{cnt} ({pct:.1f}%)", va="center", fontsize=14, color="#444",
        )

    ax.set_xlim(0, max(pcts) * 1.2 if pcts else 100)
    plt.tight_layout()
    out = output_dir / "category_distribution.pdf"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out}")


def plot_categories_per_instance(cats_per_instance: dict, output_dir: Path):
    """直方图: How many categories does each instance touch?"""
    n = len(cats_per_instance)
    num_cats = [len(cats) for cats in cats_per_instance.values()]
    counter = Counter(num_cats)

    max_cats = max(num_cats) if num_cats else 4
    min_cats = min(num_cats) if num_cats else 1
    x_vals = list(range(min_cats, max_cats + 1))
    y_vals = [counter.get(x, 0) for x in x_vals]
    y_pcts = [v / n * 100 for v in y_vals]

    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(x_vals, y_pcts, color="#4A90D9", edgecolor="white", linewidth=0.5, width=0.6, zorder=3)

    for bar, cnt in zip(bars, y_vals):
        h = bar.get_height()
        if cnt > 0:
            ax.text(bar.get_x() + bar.get_width() / 2, h + 0.8, str(cnt),
                    ha="center", va="bottom", fontsize=14, fontweight="bold", color="#333")

    ax.set_xticks(x_vals)
    ax.set_xlabel("# categories per instance", fontsize=16, color="#555")
    ax.set_ylabel("% of instances", fontsize=16, color="#555")
    ax.set_ylim(0, max(y_pcts) * 1.25 if y_pcts else 100)

    plt.tight_layout()
    out = output_dir / "categories_per_instance.pdf"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out}")


def plot_reasoning_abilities(results: dict, output_dir: Path):
    """水平柱状图: Reasoning Abilities Distribution。"""
    n = len(results)
    counter = Counter()
    for v in results.values():
        for a in v.get("reasoning_abilities", []):
            counter[a] += 1

    sorted_abs = counter.most_common()
    if not sorted_abs:
        print("无 reasoning_abilities 数据，跳过")
        return

    labels = [a for a, _ in sorted_abs]
    counts = [cnt for _, cnt in sorted_abs]
    pcts = [cnt / n * 100 for cnt in counts]

    ability_colors = [
        "#2B579A", "#5B9BD5", "#ED7D31", "#70AD47",
        "#FFC000", "#00B0F0", "#FF0066", "#A5A5A6",
        "#548235", "#404040", "#9B59B6", "#BF8F00",
    ]
    colors = [ability_colors[i % len(ability_colors)] for i in range(len(labels))]

    fig, ax = plt.subplots(figsize=(10, 6))
    y = np.arange(len(labels))
    bars = ax.barh(y, pcts, color=colors, edgecolor="white", linewidth=0.5, height=0.7, zorder=3)

    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=16)
    ax.invert_yaxis()
    ax.set_xlabel("% of instances", fontsize=16, color="#555")

    for bar, cnt, pct in zip(bars, counts, pcts):
        ax.text(
            bar.get_width() + 0.8, bar.get_y() + bar.get_height() / 2,
            f"{cnt} ({pct:.1f}%)", va="center", fontsize=14, color="#444",
        )

    ax.set_xlim(0, max(pcts) * 1.2 if pcts else 100)
    plt.tight_layout()
    out = output_dir / "reasoning_abilities.pdf"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out}")


def plot_cooccurrence_heatmap(cats_per_instance: dict, output_dir: Path):
    """热力图: Category Co-occurrence。"""
    counter = Counter()
    for cats in cats_per_instance.values():
        for c in cats:
            counter[c] += 1

    sorted_cats = [c for c, _ in counter.most_common()]
    if len(sorted_cats) < 2:
        print("类别数不足 2，跳过共现热力图")
        return

    n_cats = len(sorted_cats)
    matrix = np.zeros((n_cats, n_cats), dtype=int)
    cat_idx = {c: i for i, c in enumerate(sorted_cats)}

    for cats in cats_per_instance.values():
        for i, c1 in enumerate(cats):
            for c2 in cats[i:]:
                if c1 in cat_idx and c2 in cat_idx:
                    r, c = cat_idx[c1], cat_idx[c2]
                    matrix[r][c] += 1
                    if r != c:
                        matrix[c][r] += 1

    labels = [CATEGORY_LABELS.get(c, c) for c in sorted_cats]

    fig, ax = plt.subplots(figsize=(10, 8))
    im = ax.imshow(matrix, cmap="YlOrRd", aspect="auto")

    ax.set_xticks(np.arange(n_cats))
    ax.set_yticks(np.arange(n_cats))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=14)
    ax.set_yticklabels(labels, fontsize=14)

    for i in range(n_cats):
        for j in range(n_cats):
            val = matrix[i, j]
            if val > 0:
                text_color = "white" if val > matrix.max() * 0.6 else "black"
                ax.text(j, i, str(val), ha="center", va="center", fontsize=14, color=text_color)

    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
    plt.tight_layout()
    out = output_dir / "category_cooccurrence.pdf"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out}")


def print_summary(results: dict, cats_per_instance: dict):
    """打印文本摘要。"""
    n = len(results)
    cat_counter = Counter()
    for cats in cats_per_instance.values():
        for c in cats:
            cat_counter[c] += 1

    num_cats_list = [len(cats) for cats in cats_per_instance.values()]
    avg_cats = sum(num_cats_list) / len(num_cats_list) if num_cats_list else 0

    print(f"\n{'=' * 60}")
    print(f"Total instances (non-discard): {n}")
    print(f"Average categories per instance: {avg_cats:.2f}")

    print(f"\n--- Category Distribution (multi-label) ---")
    for cat, count in cat_counter.most_common():
        pct = count / n * 100
        bar = "█" * int(pct / 2.5)
        print(f"  {cat:<30} {count:>3} ({pct:5.1f}%)  {bar}")

    ability_counter = Counter()
    for v in results.values():
        for a in v.get("reasoning_abilities", []):
            ability_counter[a] += 1

    if ability_counter:
        print(f"\n--- Reasoning Abilities Distribution ---")
        for ability, count in ability_counter.most_common():
            pct = count / n * 100
            print(f"  {ability:<30} {count:>3} ({pct:5.1f}%)")

    print(f"{'=' * 60}")


def main():
    parser = argparse.ArgumentParser(
        description="根据 categorization_results.json 绘制 Task Categorization Analysis 图表"
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path(__file__).resolve().parent.parent.parent / "result" / "strengthen" / "v3" / "categorization_results.json",
        help="categorization_results.json 路径",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent / "img",
        help="图表输出目录（默认: src/categorize/img/）",
    )
    args = parser.parse_args()

    input_path = args.input.resolve()
    if not input_path.is_file():
        print(f"Error: 结果文件不存在: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    results = load_results(input_path)
    print(f"加载 {len(results)} 条有效分类结果")

    cats_per_instance = get_all_categories_per_instance(results)

    plot_category_distribution(cats_per_instance, output_dir)
    plot_categories_per_instance(cats_per_instance, output_dir)
    plot_reasoning_abilities(results, output_dir)
    plot_cooccurrence_heatmap(cats_per_instance, output_dir)

    print_summary(results, cats_per_instance)


if __name__ == "__main__":
    import sys
    main()
