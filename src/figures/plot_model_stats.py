import argparse
import json
import os
import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.patches import Patch

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

C_RESOLVED = "#43B581"
C_FAILED = "#E06C6C"
LABELS = {"glm": "GLM", "kimi": "Kimi", "gemini": "Gemini", "claude": "Claude"}


def main(input_json: str, output_pdf: str) -> None:
    with open(input_json, encoding="utf-8") as f:
        data = json.load(f)

    models = list(data.keys())
    fig, ax = plt.subplots(figsize=(8, 5))

    gap = 0.2

    for i, model in enumerate(models):
        pass_calls = [item["api_call"] for item in data[model]["pass"]]
        fail_calls = [item["api_call"] for item in data[model]["fail"]]

        vp = ax.violinplot(
            [pass_calls], positions=[i - gap], widths=0.32, showmedians=False, showextrema=False
        )
        for body in vp["bodies"]:
            body.set_facecolor(C_RESOLVED)
            body.set_edgecolor("white")
            body.set_linewidth(0.5)
            body.set_alpha(0.7)

        vf = ax.violinplot(
            [fail_calls], positions=[i + gap], widths=0.32, showmedians=False, showextrema=False
        )
        for body in vf["bodies"]:
            body.set_facecolor(C_FAILED)
            body.set_edgecolor("white")
            body.set_linewidth(0.5)
            body.set_alpha(0.7)

        box_common = dict(showfliers=False, widths=0.07)
        ax.boxplot(
            [pass_calls],
            positions=[i - gap],
            **box_common,
            patch_artist=True,
            boxprops=dict(facecolor="white", edgecolor=C_RESOLVED, linewidth=1.4),
            medianprops=dict(color=C_RESOLVED, linewidth=2),
            whiskerprops=dict(color=C_RESOLVED, linewidth=1.2),
            capprops=dict(color=C_RESOLVED, linewidth=1.2),
        )
        ax.boxplot(
            [fail_calls],
            positions=[i + gap],
            **box_common,
            patch_artist=True,
            boxprops=dict(facecolor="white", edgecolor=C_FAILED, linewidth=1.4),
            medianprops=dict(color=C_FAILED, linewidth=2),
            whiskerprops=dict(color=C_FAILED, linewidth=1.2),
            capprops=dict(color=C_FAILED, linewidth=1.2),
        )

    legend_elements = [
        Patch(facecolor=C_RESOLVED, alpha=0.7, edgecolor="white", label="Resolved"),
        Patch(facecolor=C_FAILED, alpha=0.7, edgecolor="white", label="Failed"),
    ]
    ax.legend(handles=legend_elements, frameon=False, fontsize=10, loc="upper right")

    ax.set_xticks(range(len(models)))
    ax.set_xticklabels([LABELS.get(m, m) for m in models], fontsize=11)
    ax.set_ylabel("API Calls", fontsize=11)

    plt.tight_layout()
    out_dir = os.path.dirname(output_pdf)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    fig.savefig(output_pdf, dpi=300, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"Saved to {output_pdf}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--input",
        default=os.path.join(_SCRIPT_DIR, "data", "model_stats.json"),
    )
    ap.add_argument(
        "--output",
        default=os.path.join(_SCRIPT_DIR, "img", "model_stats.pdf"),
    )
    args = ap.parse_args()
    main(args.input, args.output)
