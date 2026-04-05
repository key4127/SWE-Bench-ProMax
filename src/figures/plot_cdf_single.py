#!/usr/bin/env python3
"""生成单张CDF对比图（Ours vs SWE-bench）"""
import argparse
import json
import os
import matplotlib
import matplotlib.pyplot as plt
import numpy as np

matplotlib.use("Agg")
plt.rcParams.update({
    "font.size": 10,
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

_C_STYLE_EXTS = {
    ".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".m", ".mm",
    ".go", ".java", ".kt", ".kts", ".scala", ".groovy",
    ".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx", ".mts",
    ".rs", ".cs", ".swift", ".php",
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
            if not line_is_comment and use_python and (stripped.startswith('"""') or stripped.startswith("'''")):
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


def load_ours(enhanced_json_path: str) -> list:
    path = enhanced_json_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data:
        if item.get("discard"):
            continue
        patch = item.get("patch") or ""
        results.append(stats_from_patch(patch))
    return results


def load_swebench(json_path: str) -> list:
    path = json_path
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    results = []
    for item in data:
        patch = item.get("patch") or ""
        results.append(stats_from_patch(patch))
    return results


C_OURS = "#5B8DEF"
C_SP = "#43B581"
C_SV = "#FAA61A"


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
    cdf_dir = os.path.join(_SCRIPT_DIR, "data", "cdf")
    swebench_pro_path = swebench_pro_path or os.path.join(cdf_dir, "swebench_pro.json")
    swebench_verified_path = swebench_verified_path or os.path.join(
        cdf_dir, "swebench_verified.json"
    )
    output_path = output_path or os.path.join(_SCRIPT_DIR, "img", "cdf_comparison.pdf")

    print("加载数据...")
    ours_stats = load_ours(enhanced_json_path)
    pro_stats = load_swebench(swebench_pro_path)
    verified_stats = load_swebench(swebench_verified_path)

    ours_files = [s["num_non_test"] for s in ours_stats]
    ours_loc = [s["loc"] for s in ours_stats]
    pro_files = [s["num_non_test"] for s in pro_stats]
    pro_loc = [s["loc"] for s in pro_stats]
    ver_files = [s["num_non_test"] for s in verified_stats]
    ver_loc = [s["loc"] for s in verified_stats]

    print(f"ours: {len(ours_stats)}, pro: {len(pro_stats)}, verified: {len(verified_stats)}")

    fig, axes = plt.subplots(1, 2, figsize=(16, 5))

    # 左: Files
    ax = axes[0]
    for vals, color, label in [(ours_files, C_OURS, "Ours"), (pro_files, C_SP, "SWE-Pro"), (ver_files, C_SV, "SWE-Verified")]:
        if vals:
            sorted_v = np.sort(vals)
            cdf = np.arange(1, len(sorted_v) + 1) / len(sorted_v) * 100
            ax.plot(sorted_v, cdf, color=color, linewidth=2.2, label=label, zorder=3)
    ax.set_xlabel("# Modified Files", fontsize=10)
    ax.set_ylabel("Cumulative %", fontsize=10)
    ax.legend(frameon=True, fontsize=9, loc="lower right")
    ax.set_xlim(0, 80)
    ax.set_ylim(50, 105)

    # 右: LOC
    ax = axes[1]
    for vals, color, label in [(ours_loc, C_OURS, "Ours"), (pro_loc, C_SP, "SWE-Pro"), (ver_loc, C_SV, "SWE-Verified")]:
        if vals:
            sorted_v = np.sort(vals)
            cdf = np.arange(1, len(sorted_v) + 1) / len(sorted_v) * 100
            ax.plot(sorted_v, cdf, color=color, linewidth=2.2, label=label, zorder=3)
    ax.set_xlabel("# Modified LOC", fontsize=10)
    ax.set_ylabel("Cumulative %", fontsize=10)
    ax.legend(frameon=True, fontsize=9, loc="lower right")
    ax.set_xlim(0, 5000)
    ax.set_ylim(50, 105)

    plt.tight_layout()
    out_path = output_path
    _parent = os.path.dirname(out_path)
    if _parent:
        os.makedirs(_parent, exist_ok=True)
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--enhanced-json", default=None)
    ap.add_argument("--swebench-pro", default=None)
    ap.add_argument("--swebench-verified", default=None)
    ap.add_argument("--output", default=None)
    args = ap.parse_args()
    main(
        enhanced_json_path=args.enhanced_json,
        swebench_pro_path=args.swebench_pro,
        swebench_verified_path=args.swebench_verified,
        output_path=args.output,
    )
