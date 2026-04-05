#!/usr/bin/env python3
"""
生成 4 张 CDF 对比图（files & LOC × mkd & nl），保存到 src/yl_ui/ 目录。
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
    """文档文件（按扩展名）不计入 loc/文件数。"""
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

def load_preds(subset: str, preds_kimi_dir: str) -> list:
    path = os.path.join(preds_kimi_dir, subset, "preds.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data.values():
        patch = item.get("model_patch") or ""
        if not patch:
            continue
        results.append(stats_from_patch(patch))
    return results


def load_ours(raw_latest_path: str) -> list:
    path = raw_latest_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return [{"loc": d.get("loc", 0), "num_non_test": d.get("num_non_test", 0)} for d in data]


def load_swebench(json_path: str) -> list:
    path = json_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data:
        patch = item.get("patch") or ""
        results.append(stats_from_patch(patch))
    return results


# ── CDF 图表生成 ──────────────────────────────────────────────────────────────

C_PREDS  = "#E07B54"   # warm orange  — Preds
C_OURS   = "#5B8DEF"   # soft blue    — Ours
C_SP     = "#43B581"   # teal green   — SWE-bench Pro
C_SV     = "#FAA61A"   # warm amber   — SWE-bench Verified


def make_cdf(title: str, xlabel: str, datasets: list, out_path: str, xlim: tuple, ylim: tuple = (50, 105)):
    """
    datasets: list of (vals, color, label)
    xlim: (x_min, x_max), ylim: (y_min, y_max)，纵轴默认 50～105（从 50% 开始）。
    """
    fig, ax = plt.subplots(figsize=(13, 5))
    for vals, color, label in datasets:
        if not vals:
            continue
        sorted_v = np.sort(vals)
        cdf = np.arange(1, len(sorted_v) + 1) / len(sorted_v) * 100
        ax.plot(sorted_v, cdf, color=color, linewidth=2.2, label=label, zorder=3)
    ax.set_xlabel(xlabel, fontsize=10, color="#555")
    ax.set_ylabel("Cumulative %", fontsize=10, color="#555")
    ax.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=9, loc="lower right")
    ax.set_xlim(*xlim)
    ax.set_ylim(*ylim)
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
    nlp_stats      = load_preds("nl", preds_kimi_dir)
    ours_stats     = load_ours(raw_latest_path)
    pro_stats      = load_swebench(swebench_pro_path)
    verified_stats = load_swebench(swebench_verified_path)

    if subset != "nl":
        mkd_files  = [s["num_non_test"] for s in mkd_stats]
        mkd_loc    = [s["loc"]          for s in mkd_stats]
    nlp_files  = [s["num_non_test"] for s in nlp_stats]
    nlp_loc    = [s["loc"]          for s in nlp_stats]
    ours_files = [s["num_non_test"] for s in ours_stats]
    ours_loc   = [s["loc"]          for s in ours_stats]
    pro_files  = [s["num_non_test"] for s in pro_stats]
    pro_loc    = [s["loc"]          for s in pro_stats]
    ver_files  = [s["num_non_test"] for s in verified_stats]
    ver_loc    = [s["loc"]          for s in verified_stats]

    if subset != "nl":
        print(f"mkd preds: {len(mkd_stats)} 条  nl preds: {len(nlp_stats)} 条")
    else:
        print(f"nl preds: {len(nlp_stats)} 条")
    print(f"Ours: {len(ours_stats)}  SWE-Pro: {len(pro_stats)}  SWE-Verified: {len(verified_stats)}")

    # CDF Files: 横坐标到 80，纵坐标从 50 开始
    # CDF LOC: 横坐标到 5000，纵坐标从 50 开始
    ylim_half = (50, 105)
    if subset in ("all", "mkd"):
        make_cdf(
            "CDF: Modified Files per Instance (mkd)", "# Modified Files",
            [(mkd_files,  C_PREDS, "Preds (mkd)"),
             (ours_files, C_OURS,  "Ours (ProMax)"),
             (pro_files,  C_SP,    "SWE-bench Pro"),
             (ver_files,  C_SV,    "SWE-bench Verified")],
            os.path.join(output_dir, "preds_cdf_files_mkd.pdf"),
            xlim=(0, 80), ylim=ylim_half,
        )
        make_cdf(
            "CDF: Modified LOC per Instance (mkd)", "# Modified LOC",
            [(mkd_loc,  C_PREDS, "Preds (mkd)"),
             (ours_loc, C_OURS,  "Ours (ProMax)"),
             (pro_loc,  C_SP,    "SWE-bench Pro"),
             (ver_loc,  C_SV,    "SWE-bench Verified")],
            os.path.join(output_dir, "preds_cdf_loc_mkd.pdf"),
            xlim=(0, 5000), ylim=ylim_half,
        )
    if subset in ("all", "nl"):
        make_cdf(
            "CDF: Modified Files per Instance (nl)", "# Modified Files",
            [(nlp_files,  C_PREDS, "Preds (nl)"),
             (ours_files, C_OURS,  "Ours (ProMax)"),
             (pro_files,  C_SP,    "SWE-bench Pro"),
             (ver_files,  C_SV,    "SWE-bench Verified")],
            os.path.join(output_dir, "preds_cdf_files_nlp.pdf"),
            xlim=(0, 80), ylim=ylim_half,
        )
        make_cdf(
            "CDF: Modified LOC per Instance (nl)", "# Modified LOC",
            [(nlp_loc,  C_PREDS, "Preds (nl)"),
             (ours_loc, C_OURS,  "Ours (ProMax)"),
             (pro_loc,  C_SP,    "SWE-bench Pro"),
             (ver_loc,  C_SV,    "SWE-bench Verified")],
            os.path.join(output_dir, "preds_cdf_loc_nlp.pdf"),
            xlim=(0, 5000), ylim=ylim_half,
        )


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="生成 preds CDF 对比图")
    parser.add_argument(
        "--subset",
        choices=("all", "mkd", "nl"),
        default="all",
        help="只生成 mkd / nl / 全部（默认 all）",
    )
    parser.add_argument("--preds-kimi-dir", default=None)
    parser.add_argument("--raw-latest", default=None)
    parser.add_argument("--swebench-pro", default=None)
    parser.add_argument("--swebench-verified", default=None)
    parser.add_argument("--output-dir", default=None)
    args = parser.parse_args()
    main(
        args.subset,
        preds_kimi_dir=args.preds_kimi_dir,
        raw_latest_path=args.raw_latest,
        swebench_pro_path=args.swebench_pro,
        swebench_verified_path=args.swebench_verified,
        output_dir=args.output_dir,
    )
