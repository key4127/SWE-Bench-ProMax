#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np

matplotlib.use("Agg")
plt.rcParams["font.family"] = "DejaVu Sans"

MODEL_STYLES = {
    "gemini": {"label": "Gemini", "color": "#B74A3A"},
    "glm": {"label": "GLM", "color": "#7A4EBC"},
    "kimi": {"label": "Kimi", "color": "#2F8B57"},
    "claude": {"label": "Claude", "color": "#2D628C"},
}


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--input", default="data/model_pass_rate.json")
    p.add_argument("--output", default="polar_language_comparison.pdf")
    p.add_argument("--benchmark", default="SWE-Cascade")
    return p.parse_args()


def load_data(path: Path, benchmark: str):
    with path.open("r", encoding="utf-8") as f:
        raw = json.load(f)

    model_to_details = {}
    for item in raw:
        model = item.get("model", "").strip().lower()
        result = next(
            (r for r in item.get("result", []) if str(r.get("benchmark", "")).strip().lower() == benchmark.lower()),
            None,
        )
        if result and result.get("language_details"):
            model_to_details[model] = result["language_details"]

    if not model_to_details:
        raise ValueError("没有找到 language_details 数据")

    languages = list(next(iter(model_to_details.values())).keys())
    if "go" in languages and "python" in languages:
        i, j = languages.index("go"), languages.index("python")
        languages[i], languages[j] = languages[j], languages[i]
    return model_to_details, languages


def compute_values(model_to_details, languages):
    model_names = [m for m in MODEL_STYLES if m in model_to_details]
    vals = []
    for m in model_names:
        cur = []
        for lang in languages:
            total = float(model_to_details[m][lang]["total"])
            passed = float(model_to_details[m][lang]["pass"])
            cur.append((passed / total) * 100 if total else 0.0)
        vals.append(cur)
    return model_names, np.array(vals)


def draw(model_names, languages, values, output: Path):
    n_groups = len(languages)
    n_models = len(model_names)

    base_angles = np.linspace(0, 2 * np.pi, n_groups, endpoint=False)
    group_width = 2 * np.pi / n_groups
    bar_width = group_width / (n_models + 1.9)

    inner_radius = 13
    r_max = 95
    ring_span = r_max - inner_radius - 3
    heights = values / max(float(np.max(values)), 1.0) * ring_span

    fig = plt.figure(figsize=(10.2, 10.0), facecolor="white")
    ax = fig.add_subplot(111, projection="polar")
    ax.set_position([0.12, 0.15, 0.76, 0.76])
    ax.set_facecolor("white")
    ax.set_theta_offset(np.pi / 2)
    ax.set_theta_direction(-1)

    for i, m in enumerate(model_names):
        st = MODEL_STYLES[m]
        offsets = (i - (n_models - 1) / 2) * bar_width
        bars = ax.bar(
            base_angles + offsets,
            heights[i],
            width=bar_width * 0.9,
            bottom=inner_radius,
            color=st["color"],
            alpha=0.98,
            edgecolor="white",
            linewidth=0.9,
            label=st["label"],
            zorder=3,
        )
        for bar, raw_val, h in zip(bars, values[i], heights[i]):
            theta = bar.get_x() + bar.get_width() / 2
            p0 = ax.transData.transform((theta, 0))
            p1 = ax.transData.transform((theta, 1))
            rotation = np.degrees(np.arctan2(p1[1] - p0[1], p1[0] - p0[0]))
            if rotation > 90:
                rotation -= 180
            if rotation < -90:
                rotation += 180

            label_r = inner_radius + h + 2.0 + i * 1.1 if h < 12 else inner_radius + max(4.0, h * 0.42) + i * 1.4
            color = "#222222" if h < 12 else "white"

            ax.text(
                theta,
                label_r,
                f"{raw_val:.1f}",
                ha="center",
                va="center",
                fontsize=12,
                color=color,
                fontweight="bold",
                rotation=rotation,
                rotation_mode="anchor",
            )

    ax.set_ylim(0, r_max)
    ax.set_yticks([])
    ax.yaxis.grid(True, linestyle=(0, (2, 2)), color="#D7D7D7", alpha=0.75)
    ax.xaxis.grid(True, linestyle="-", color="#DCDCDC", alpha=0.55)
    ax.set_xticks(base_angles)
    ax.set_xticklabels([])

    # 让大多数语言标签更贴近外圈；typescript 单独外移以避免与图形元素重叠
    common_label_radius = r_max + 13
    typescript_label_radius = r_max + 27
    closer_langs = {"c++", "c", "go", "java"}
    closer_label_radius = r_max + 10
    c_langs = {"c++", "c"}
    c_label_radius = r_max + 8
    for ang, lang in zip(base_angles, languages):
        label = lang.upper() if lang in {"c", "c++"} else lang.capitalize()
        cos_a = np.cos(ang)
        ha = "left" if cos_a > 0.25 else ("right" if cos_a < -0.25 else "center")
        text_ang = ang - 0.05 if lang == "c++" else ang
        if lang == "typescript":
            label_r = typescript_label_radius
        elif lang in c_langs:
            label_r = c_label_radius
        elif lang in closer_langs:
            label_r = closer_label_radius
        else:
            label_r = common_label_radius
        ax.text(text_ang, label_r, label, ha=ha, va="center", fontsize=19, fontweight="bold", color="#1F1F1F")

    center_circle = plt.Circle((0, 0), inner_radius - 1.0, transform=ax.transData._b, color="white", zorder=4)
    ax.add_artist(center_circle)
    ax.text(0, 0, "Pass Rate\n(x100)", ha="center", va="center", fontsize=15, color="#777777", zorder=5)

    legend = ax.legend(loc="lower center", bbox_to_anchor=(0.5, -0.17), ncol=2, frameon=False, fontsize=16)
    for t in legend.get_texts():
        t.set_fontfamily("DejaVu Sans")
        t.set_fontweight("bold")

    plt.tight_layout(pad=1.6)
    fig.savefig(output, dpi=300, bbox_inches="tight")
    plt.close(fig)


def main():
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    input_path = (script_dir / args.input).resolve()
    output_path = (script_dir / args.output).resolve()
    model_to_details, languages = load_data(input_path, args.benchmark)
    model_names, values = compute_values(model_to_details, languages)
    draw(model_names, languages, values, output_path)
    print(f"Saved: {output_path}")


if __name__ == "__main__":
    main()
