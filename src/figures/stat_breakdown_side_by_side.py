#!/usr/bin/env python3
"""
生成两张并列的 breakdown 堆叠柱状图（Modified Files + Modified LOC），输出为 PDF。
运行前请先: conda activate all
"""

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

# ── 语言扩展名集合 ────────────────────────────────────────────────────────────
_C_STYLE_EXTS = {
    ".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".m", ".mm",
    ".go",
    ".java", ".kt", ".kts", ".scala", ".groovy",
    ".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx", ".mts",
    ".rs",
    ".cs", ".swift",
    ".php",
}
_PYTHON_EXTS = {".py", ".pyx", ".pyi", ".pxd"}
_HASH_ONLY_EXTS = {
    ".sh", ".bash", ".zsh", ".fish",
    ".rb", ".pl", ".r", ".jl",
    ".yaml", ".yml", ".toml", ".ini", ".cfg",
}
_DOC_EXTS = {
    ".md", ".markdown", ".rst", ".txt",
    ".adoc", ".asciidoc", ".tex", ".texi", ".org",
    ".htm", ".html",
}


def _is_doc_file(filename: str) -> bool:
    if not (filename or filename.strip()):
        return False
    ext = os.path.splitext(filename.strip().lower())[1]
    return ext in _DOC_EXTS


def _count_file_non_comment_loc(patch: str, filename: str) -> tuple:
    if not patch:
        return 0, True

    ext = os.path.splitext(filename)[1].lower() if filename else ""
    use_c_style = ext in _C_STYLE_EXTS
    use_python = ext in _PYTHON_EXTS
    use_hash = use_python or ext in _HASH_ONLY_EXTS

    in_block = False
    triple = None
    non_comment = 0
    has_any = False

    for raw in patch.splitlines():
        if raw.startswith(("+++", "---", "@@", "\\")):
            continue

        is_change = raw[:1] in ("+", "-")
        content = raw[1:] if raw[:1] in ("+", "-", " ") else raw
        stripped = content.strip()

        if in_block or triple is not None:
            line_is_comment = True
        elif not stripped:
            line_is_comment = False
        else:
            line_is_comment = False
            if use_c_style and (stripped.startswith("//") or stripped.startswith("/*")):
                line_is_comment = True
            if not line_is_comment and use_hash and stripped.startswith("#"):
                line_is_comment = True
            if not line_is_comment and use_python and (
                stripped.startswith('"""') or stripped.startswith("'''")
            ):
                line_is_comment = True

        if use_c_style:
            i = 0
            while i < len(content):
                if in_block:
                    j = content.find("*/", i)
                    if j < 0:
                        break
                    in_block = False
                    i = j + 2
                else:
                    sl = content.find("//", i)
                    bl = content.find("/*", i)
                    if bl < 0:
                        break
                    if 0 <= sl < bl:
                        break
                    in_block = True
                    j = content.find("*/", bl + 2)
                    if j < 0:
                        break
                    in_block = False
                    i = j + 2

        if use_python:
            if triple is None:
                for q in ('"""', "'''"):
                    idx = content.find(q)
                    if idx >= 0:
                        if content.find(q, idx + 3) < 0:
                            triple = q[0]
                        break
            else:
                if triple * 3 in content:
                    triple = None

        if is_change:
            has_any = True
            if not line_is_comment:
                non_comment += 1

    return non_comment, (has_any and non_comment == 0)


def stats_from_patch(patch_str: str) -> dict:
    if not patch_str:
        return {"loc": 0, "num_non_test": 0}

    parts = patch_str.split("diff --git ")
    loc = 0
    seen = set()
    num_non_test = 0

    for part in parts:
        if not part.strip():
            continue
        filename = ""
        for line in part.splitlines():
            if line.startswith("+++ b/"):
                filename = line[6:].strip()
                break
            if line.startswith("+++ /dev/null"):
                filename = ""
                break

        if not filename or filename in seen:
            continue
        seen.add(filename)

        if "test" in filename.lower():
            continue
        if _is_doc_file(filename):
            continue

        file_loc, only_comments = _count_file_non_comment_loc(part, filename)
        if only_comments:
            continue

        loc += file_loc
        num_non_test += 1

    return {"loc": loc, "num_non_test": num_non_test}


# ── 数据加载 ──────────────────────────────────────────────────────────────────

def load_ours(enhanced_json_path: str) -> list:
    path = enhanced_json_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return [
        {"loc": d.get("loc", 0), "num_non_test": d.get("num_non_test", 0)}
        for d in data
        if d.get("discard") is not True
    ]


def load_swebench(json_path: str) -> list:
    path = json_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data:
        patch = item.get("patch") or ""
        results.append(stats_from_patch(patch))
    return results


# ── 图表生成 ──────────────────────────────────────────────────────────────────

BUCKET_COLORS = ["#a8d8ea", "#7ec8e3", "#5bb5d5", "#3a8fbf", "#1a6fa0"]

F_THRESH = [1, 3, 5, 10]
F_LABELS = ["1", "2-3", "4-5", "6-10", ">10"]

L_THRESH = [20, 50, 100, 200]
L_LABELS = ["≤20", "21-50", "51-100", "101-200", ">200"]


def bucket_pcts_normalized(vals, thresholds):
    """计算各桶百分比并归一化至 100%。"""
    n = len(vals)
    if n == 0:
        return [0.0] * (len(thresholds) + 1)
    raw = []
    for lo, hi in zip([0] + thresholds, thresholds + [float("inf")]):
        raw.append(sum(1 for v in vals if lo < v <= hi) / n * 100)
    total = sum(raw)
    if total > 0:
        raw = [r / total * 100 for r in raw]
    return raw


def draw_breakdown(ax, title, datasets, thresholds, bucket_labels, show_legend=True):
    n_groups = len(datasets)
    # 略大于 0.75（会重叠），略小于 1.2（空隙过大）；文字之间留最小可读间距
    x = np.arange(n_groups) * 0.98
    group_names = [d[0] for d in datasets]
    pcts_list = [bucket_pcts_normalized(d[1], thresholds) for d in datasets]

    for i, lbl in enumerate(bucket_labels):
        vals = [p[i] for p in pcts_list]
        bottoms = [sum(p[:i]) for p in pcts_list]
        bars = ax.bar(x, vals, 0.52, bottom=bottoms,
                      color=BUCKET_COLORS[i], edgecolor="white", linewidth=0.5,
                      label=lbl, zorder=3)
        for bar, v in zip(bars, vals):
            if v > 4:
                ax.text(bar.get_x() + bar.get_width() / 2,
                        bar.get_y() + bar.get_height() / 2,
                        f"{v:.0f}%", ha="center", va="center", fontsize=12, color="#333")

    ax.set_title(title, fontsize=16, fontweight="bold", pad=8)
    ax.set_xticks(x)
    ax.set_xticklabels(group_names, fontsize=14)
    for lbl, name in zip(ax.get_xticklabels(), group_names):
        lbl.set_fontweight("bold" if name == "SWE-Cascade" else "normal")
    ax.set_ylabel("Percentage (%)", fontsize=14, color="#555")
    ax.set_ylim(0, 100)
    ax.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=12,
              loc="upper left", bbox_to_anchor=(1.01, 1.0))


def main(
    *,
    enhanced_json_path: str | None = None,
    swebench_pro_path: str | None = None,
    swebench_verified_path: str | None = None,
    output_path: str | None = None,
):
    enhanced_json_path = enhanced_json_path or os.path.join(
        _PROJECT_ROOT, "result", "strengthen", "v2", "all_nl_enhanced.json"
    )
    swebench_pro_path = swebench_pro_path or os.path.join(_SCRIPT_DIR, "swebench_pro.json")
    swebench_verified_path = swebench_verified_path or os.path.join(
        _SCRIPT_DIR, "swebench_verified.json"
    )
    output_path = output_path or os.path.join(_SCRIPT_DIR, "breakdown_side_by_side.pdf")

    print("加载数据...")
    ours_stats     = load_ours(enhanced_json_path)
    pro_stats      = load_swebench(swebench_pro_path)
    verified_stats = load_swebench(swebench_verified_path)

    ours_files = [s["num_non_test"] for s in ours_stats]
    ours_loc   = [s["loc"]          for s in ours_stats]
    pro_files  = [s["num_non_test"] for s in pro_stats]
    pro_loc    = [s["loc"]          for s in pro_stats]
    ver_files  = [s["num_non_test"] for s in verified_stats]
    ver_loc    = [s["loc"]          for s in verified_stats]

    print(f"SWE-Cascade: {len(ours_stats)}  SWE-Pro: {len(pro_stats)}  SWE-Verified: {len(verified_stats)}")

    datasets_files = [
        ("SWE-Cascade", ours_files),
        ("SWE-bench Pro", pro_files),
        ("SWE-bench Verified", ver_files),
    ]
    datasets_loc = [
        ("SWE-Cascade", ours_loc),
        ("SWE-bench Pro", pro_loc),
        ("SWE-bench Verified", ver_loc),
    ]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(17, 5))
    fig.subplots_adjust(wspace=0.46)

    draw_breakdown(ax1, "Modified Files Breakdown", datasets_files, F_THRESH, F_LABELS)
    draw_breakdown(ax2, "Modified LOC Breakdown", datasets_loc, L_THRESH, L_LABELS)
    out_path = output_path
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="并列 breakdown 图（SWE-Cascade vs Pro vs Verified）")
    ap.add_argument(
        "--enhanced-json",
        default=None,
        help="all_nl_enhanced.json（默认: <项目根>/result/strengthen/v2/all_nl_enhanced.json）",
    )
    ap.add_argument("--swebench-pro", default=None)
    ap.add_argument("--swebench-verified", default=None)
    ap.add_argument("--output", default=None, help="输出 PDF 路径")
    args = ap.parse_args()
    main(
        enhanced_json_path=args.enhanced_json,
        swebench_pro_path=args.swebench_pro,
        swebench_verified_path=args.swebench_verified,
        output_path=args.output,
    )
