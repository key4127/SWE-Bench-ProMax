import argparse
import json
import matplotlib.pyplot as plt
import matplotlib
import numpy as np
from pathlib import Path

matplotlib.rcParams["font.family"] = "sans-serif"
matplotlib.rcParams["font.sans-serif"] = ["DejaVu Sans", "Arial", "Helvetica"]

_SCRIPT_DIR = Path(__file__).resolve().parent


def main(input_path: str, output_path: str) -> None:
    with open(input_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    benchmarks = sorted(data.items(), key=lambda x: x[1]["files"])
    names = [b[0] for b in benchmarks]
    locs = [b[1]["loc"] for b in benchmarks]
    files = [b[1]["files"] for b in benchmarks]

    n = len(names)
    bar_height = 0.32
    group_gap = 0.6

    color_map = {
        "SWE-Cascade": ("#3778B8", "#7AADE0", "#2A5F96"),
        "SWE-bench Pro": ("#4FAE42", "#8ED484", "#3A8A2E"),
        "SWE-bench Verified": ("#E8941A", "#F2BD5C", "#C07A0E"),
    }

    group_positions = np.arange(n) * (2 * bar_height + group_gap)

    fig, ax = plt.subplots(figsize=(7.5, 2.8))
    fig.patch.set_facecolor("white")
    ax.set_facecolor("white")

    max_loc = max(locs)
    max_files = max(files)

    for i in range(n):
        c_dark, c_light, c_text = color_map[names[i]]

        y_loc = group_positions[i]
        y_files = group_positions[i] + bar_height

        ax.barh(y_loc, locs[i], height=bar_height, color=c_dark, edgecolor="none")
        ax.barh(
            y_files,
            files[i] / max_files * max_loc,
            height=bar_height,
            color=c_light,
            edgecolor="none",
        )

        loc_val = locs[i]
        loc_label = f"{loc_val:.0f} mean lines of code" if i == 0 else f"{loc_val:.0f} lines of code"
        ax.text(
            locs[i] + max_loc * 0.02,
            y_loc,
            loc_label,
            va="center",
            fontsize=10,
            color=c_text,
            fontweight="medium",
        )

        file_val = files[i]
        file_label = f"{file_val:.1f} mean number of files" if i == 0 else f"{file_val:.1f} files"
        ax.text(
            files[i] / max_files * max_loc + max_loc * 0.02,
            y_files,
            file_label,
            va="center",
            fontsize=10,
            color=c_text,
            fontweight="medium",
        )

    y_label_positions = group_positions + bar_height / 2
    ax.set_yticks(y_label_positions)
    ax.set_yticklabels(names, fontsize=12, fontweight="medium", color="#333333")
    ax.tick_params(axis="y", pad=15)

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["bottom"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.tick_params(left=False, bottom=False)
    ax.set_xticks([])

    ax.set_xlim(0, max_loc * 1.32)
    ax.invert_yaxis()

    plt.tight_layout()
    out = Path(output_path)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(
        str(out),
        dpi=300,
        bbox_inches="tight",
        facecolor="white",
        pad_inches=0.3,
    )
    print(f"Chart saved to {out}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--input",
        default=str(_SCRIPT_DIR / "data" / "benchmark_detail.json"),
        help="benchmark_detail.json",
    )
    ap.add_argument("--output", default="benchmark_comparison.pdf", help="输出 PDF 路径")
    args = ap.parse_args()
    main(args.input, args.output)
