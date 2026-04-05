#!/usr/bin/env python3
"""
统计 result/preds_result/strengthen/mkd 和 nlp 中 preds.json 的 model_patch LOC 和 non-test 文件数，
生成 4 张对比图（files breakdown + LOC breakdown × mkd + nlp），保存到 src/yl_ui/ 目录。
"""

import json
import os
import sys

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

# ── 语言扩展名集合（与 merge_swe_detail.py 保持一致）──────────────────────────
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
    """文档文件（按扩展名）不计入 loc/文件数。"""
    if not (filename or filename.strip()):
        return False
    ext = os.path.splitext(filename.strip().lower())[1]
    return ext in _DOC_EXTS


def _count_file_non_comment_loc(patch: str, filename: str) -> tuple:
    """返回 (non_comment_loc, only_comments)。"""
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
    """
    解析合并 patch 字符串，返回 loc（非注释非测试）和 num_non_test。
    按 'diff --git' 分割为各文件 patch，提取文件名后逐文件统计。
    """
    if not patch_str:
        return {"loc": 0, "num_non_test": 0}

    # 按文件分割
    parts = patch_str.split("diff --git ")
    loc = 0
    seen = set()
    num_non_test = 0

    for part in parts:
        if not part.strip():
            continue
        # 从 '+++ b/filename' 提取文件名
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

        is_test = "test" in filename.lower()
        if is_test:
            continue  # 测试文件不计入 loc / num_non_test
        if _is_doc_file(filename):
            continue  # 文档文件不计入 loc / 文件数

        file_loc, only_comments = _count_file_non_comment_loc(part, filename)
        if only_comments:
            continue

        loc += file_loc
        num_non_test += 1

    return {"loc": loc, "num_non_test": num_non_test}


# ── 数据加载 ──────────────────────────────────────────────────────────────────

def load_preds(subset: str, preds_kimi_dir: str) -> list:
    """加载 mkd 或 nl 的 preds.json，返回每条的 stats dict 列表。"""
    path = os.path.join(preds_kimi_dir, subset, "preds.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data.values():
        patch = item.get("model_patch") or ""
        if not patch:
            continue  # 跳过空patch/失败实例
        results.append(stats_from_patch(patch))
    return results


def load_ours(raw_latest_path: str) -> list:
    """从 raw_latest.json 加载预计算的 loc / num_non_test。"""
    path = raw_latest_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return [{"loc": d.get("loc", 0), "num_non_test": d.get("num_non_test", 0)} for d in data]


def load_swebench(json_path: str) -> list:
    """加载 swebench_pro.json 或 swebench_verified.json，用注释过滤逻辑统计 patch。"""
    path = json_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data:
        patch = item.get("patch") or ""
        results.append(stats_from_patch(patch))
    return results


# ── 图表生成 ──────────────────────────────────────────────────────────────────

bucket_colors = ["#a8d8ea", "#7ec8e3", "#5bb5d5", "#3a8fbf", "#1a6fa0"]

f_thresh = [1, 3, 5, 10]
f_labels = ["1", "2-3", "4-5", "6-10", ">10"]

l_thresh = [20, 50, 100, 200]
l_labels = ["≤20", "21-50", "51-100", "101-200", ">200"]


def bucket_pcts(vals, thresholds):
    n = len(vals)
    if n == 0:
        return [0.0] * (len(thresholds) + 1)
    pcts = []
    for lo, hi in zip([0] + thresholds, thresholds + [float("inf")]):
        pcts.append(sum(1 for v in vals if lo < v <= hi) / n * 100)
    return pcts


def make_breakdown_chart(title, labels, datasets, bucket_labels, out_path):
    """
    datasets: list of (name, vals_list)
    labels: bucket labels
    """
    n_groups = len(datasets)
    x = np.arange(n_groups)
    group_names = [d[0] for d in datasets]
    pcts_list = [bucket_pcts(d[1], (f_thresh if "file" in title.lower() else l_thresh))
                 for d in datasets]

    fig, ax = plt.subplots(figsize=(10, 5))
    for i, lbl in enumerate(bucket_labels):
        vals = [p[i] for p in pcts_list]
        bottoms = [sum(p[:i]) for p in pcts_list]
        bars = ax.bar(x, vals, 0.55, bottom=bottoms,
                      color=bucket_colors[i], edgecolor="white", linewidth=0.5,
                      label=lbl, zorder=3)
        for bar, v in zip(bars, vals):
            if v > 4:
                ax.text(bar.get_x() + bar.get_width() / 2,
                        bar.get_y() + bar.get_height() / 2,
                        f"{v:.0f}%", ha="center", va="center", fontsize=8, color="#333")

    ax.set_xticks(x)
    ax.set_xticklabels(group_names, fontsize=11)
    ax.set_ylabel("Percentage (%)", fontsize=10, color="#555")
    ax.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=8,
              loc="upper right")
    plt.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


def main(
    subset: str = "all",
    *,
    preds_kimi_dir: str | None = None,
    raw_latest_path: str | None = None,
    swebench_pro_path: str | None = None,
    swebench_verified_path: str | None = None,
    output_dir: str | None = None,
):
    preds_kimi_dir = preds_kimi_dir or os.path.join(
        _PROJECT_ROOT, "result", "preds_result", "kimi"
    )
    raw_latest_path = raw_latest_path or os.path.join(_SCRIPT_DIR, "raw_latest.json")
    swebench_pro_path = swebench_pro_path or os.path.join(_SCRIPT_DIR, "swebench_pro.json")
    swebench_verified_path = swebench_verified_path or os.path.join(
        _SCRIPT_DIR, "swebench_verified.json"
    )
    output_dir = output_dir or _SCRIPT_DIR

    print("加载数据...")
    if subset != "nl":
        mkd_stats = load_preds("mkd", preds_kimi_dir)
    nlp_stats = load_preds("nl", preds_kimi_dir)
    ours_stats = load_ours(raw_latest_path)
    pro_stats = load_swebench(swebench_pro_path)
    verified_stats = load_swebench(swebench_verified_path)

    if subset != "nl":
        mkd_files = [s["num_non_test"] for s in mkd_stats]
        mkd_loc   = [s["loc"] for s in mkd_stats]
    nlp_files = [s["num_non_test"] for s in nlp_stats]
    nlp_loc   = [s["loc"] for s in nlp_stats]
    ours_files = [s["num_non_test"] for s in ours_stats]
    ours_loc   = [s["loc"] for s in ours_stats]
    pro_files  = [s["num_non_test"] for s in pro_stats]
    pro_loc    = [s["loc"] for s in pro_stats]
    ver_files  = [s["num_non_test"] for s in verified_stats]
    ver_loc    = [s["loc"] for s in verified_stats]

    if subset != "nl":
        print(f"mkd preds: {len(mkd_stats)} 条  nl preds: {len(nlp_stats)} 条")
    else:
        print(f"nl preds: {len(nlp_stats)} 条")
    print(f"Ours: {len(ours_stats)}  SWE-Pro: {len(pro_stats)}  SWE-Verified: {len(verified_stats)}")

    if subset != "nl":
        datasets_mkd_files = [
            ("Preds (mkd)", mkd_files),
            ("Ours (ProMax)", ours_files),
            ("SWE-bench Pro", pro_files),
            ("SWE-bench Verified", ver_files),
        ]
        datasets_mkd_loc = [
            ("Preds (mkd)", mkd_loc),
            ("Ours (ProMax)", ours_loc),
            ("SWE-bench Pro", pro_loc),
            ("SWE-bench Verified", ver_loc),
        ]
    datasets_nlp_files = [
        ("Preds (nl)", nlp_files),
        ("Ours (ProMax)", ours_files),
        ("SWE-bench Pro", pro_files),
        ("SWE-bench Verified", ver_files),
    ]
    datasets_nlp_loc = [
        ("Preds (nl)", nlp_loc),
        ("Ours (ProMax)", ours_loc),
        ("SWE-bench Pro", pro_loc),
        ("SWE-bench Verified", ver_loc),
    ]

    if subset in ("all", "mkd"):
        make_breakdown_chart(
            "Modified Files Breakdown (mkd)", f_labels, datasets_mkd_files, f_labels,
            os.path.join(output_dir, "preds_files_breakdown_mkd.pdf"),
        )
        make_breakdown_chart(
            "Modified LOC Breakdown (mkd)", l_labels, datasets_mkd_loc, l_labels,
            os.path.join(output_dir, "preds_loc_breakdown_mkd.pdf"),
        )
    if subset in ("all", "nl"):
        make_breakdown_chart(
            "Modified Files Breakdown (nl)", f_labels, datasets_nlp_files, f_labels,
            os.path.join(output_dir, "preds_files_breakdown_nlp.pdf"),
        )
        make_breakdown_chart(
            "Modified LOC Breakdown (nl)", l_labels, datasets_nlp_loc, l_labels,
            os.path.join(output_dir, "preds_loc_breakdown_nlp.pdf"),
        )


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="生成 preds 对比图（breakdown）")
    parser.add_argument(
        "--subset",
        choices=("all", "mkd", "nl"),
        default="all",
        help="只生成 mkd / nl / 全部（默认 all）",
    )
    parser.add_argument(
        "--preds-kimi-dir",
        default=None,
        help="含 mkd/nl/preds.json 的 kimi 目录（默认: <项目根>/result/preds_result/kimi）",
    )
    parser.add_argument("--raw-latest", default=None, help="raw_latest.json 路径")
    parser.add_argument("--swebench-pro", default=None, help="swebench_pro.json 路径")
    parser.add_argument("--swebench-verified", default=None, help="swebench_verified.json 路径")
    parser.add_argument("--output-dir", default=None, help="PDF 输出目录（默认: 本脚本所在目录）")
    args = parser.parse_args()
    main(
        args.subset,
        preds_kimi_dir=args.preds_kimi_dir,
        raw_latest_path=args.raw_latest,
        swebench_pro_path=args.swebench_pro,
        swebench_verified_path=args.swebench_verified,
        output_dir=args.output_dir,
    )
