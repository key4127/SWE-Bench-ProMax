#!/usr/bin/env python3
"""
左右双图 CDF：
  左图 — 正确 patch / Kimi / GLM 各自修改了多少文件
  右图 — Kimi / GLM 通过/失败实例的交互轮次(user+assistant)
"""

import json
import os
import glob

import matplotlib
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np

matplotlib.use("Agg")
plt.rcParams.update({
    "font.size": 19,
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

# ── 语言扩展名集合 ──────────────────────────────────────────────────────────────
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


def get_rounds_from_traj(traj_path: str) -> int:
    """user+assistant 算一轮交互，返回轮次数。"""
    with open(traj_path, encoding="utf-8") as f:
        traj = json.load(f)
    msgs = traj.get("messages", [])
    return sum(1 for m in msgs if m.get("role") == "assistant")


def load_harness(model_name: str) -> dict:
    """返回 {instance_id: passed_bool}"""
    path = os.path.join(_PROJECT_ROOT, "result", "harness_result",
                        "strengthen", "v2", f"{model_name}.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return {x["instance_id"]: x["passed"] for x in data}


def load_rounds(model_name: str, valid_ids: set) -> dict:
    """返回 {instance_id: rounds}"""
    base = os.path.join(_PROJECT_ROOT, "result", "preds_result",
                        "strengthen", "v2", model_name)
    result = {}
    for inst_id in valid_ids:
        traj_path = os.path.join(base, inst_id, f"{inst_id}.traj.json")
        if os.path.exists(traj_path):
            result[inst_id] = get_rounds_from_traj(traj_path)
    return result


# ── 颜色 ────────────────────────────────────────────────────────────────────────
C_GOLD = "#43B581"
C_KIMI = "#E07B54"
C_GLM  = "#5B8DEF"


def plot_cdf(ax, vals, color, label, linewidth=2.2, linestyle="-"):
    if not vals:
        return
    sorted_v = np.sort(vals)
    cdf = np.arange(1, len(sorted_v) + 1) / len(sorted_v) * 100
    ax.plot(sorted_v, cdf, color=color, linewidth=linewidth, label=label,
            linestyle=linestyle, zorder=3)


def main():
    # ── 加载公共数据 ──────────────────────────────────────────────────────────
    gold_path = os.path.join(_PROJECT_ROOT, "result", "strengthen", "v2",
                             "all_nl_enhanced.json")
    print("加载 all_nl_enhanced.json ...")
    with open(gold_path, encoding="utf-8") as f:
        all_instances = json.load(f)
    valid_instances = [x for x in all_instances if not x.get("discard", False)]
    valid_ids = {x["instance_id"] for x in valid_instances}
    gold_map = {x["instance_id"]: x["num_non_test"] for x in valid_instances}
    print(f"  总实例: {len(all_instances)}, 有效: {len(valid_instances)}")

    # ── 左图数据：文件数 ──────────────────────────────────────────────────────
    gold_files = []
    kimi_files = []
    glm_files = []

    kimi_preds_path = os.path.join(_PROJECT_ROOT, "result", "preds_result",
                                   "strengthen", "v2", "kimi", "preds.json")
    glm_preds_path = os.path.join(_PROJECT_ROOT, "result", "preds_result",
                                  "strengthen", "v2", "glm", "preds.json")

    print("加载 preds.json (kimi & glm) ...")
    with open(kimi_preds_path, encoding="utf-8") as f:
        kimi_preds = json.load(f)
    with open(glm_preds_path, encoding="utf-8") as f:
        glm_preds = json.load(f)

    for inst_id in valid_ids:
        gold_files.append(gold_map[inst_id])
        if inst_id in kimi_preds:
            patch = kimi_preds[inst_id].get("model_patch") or ""
            kimi_files.append(stats_from_patch(patch)["num_non_test"])
        if inst_id in glm_preds:
            patch = glm_preds[inst_id].get("model_patch") or ""
            glm_files.append(stats_from_patch(patch)["num_non_test"])

    print(f"  Gold files  — n={len(gold_files)}, mean={np.mean(gold_files):.1f}")
    print(f"  Kimi files  — n={len(kimi_files)}, mean={np.mean(kimi_files):.1f}")
    print(f"  GLM  files  — n={len(glm_files)}, mean={np.mean(glm_files):.1f}")

    # ── 右图数据：交互轮次 ────────────────────────────────────────────────────
    print("加载 harness results ...")
    kimi_harness = load_harness("kimi")
    glm_harness = load_harness("glm")

    print("加载 traj 文件 (kimi) ...")
    kimi_rounds = load_rounds("kimi", valid_ids)
    print("加载 traj 文件 (glm) ...")
    glm_rounds = load_rounds("glm", valid_ids)

    kimi_pass_rounds, kimi_fail_rounds = [], []
    for inst_id in valid_ids:
        if inst_id in kimi_rounds and inst_id in kimi_harness:
            r = kimi_rounds[inst_id]
            if kimi_harness[inst_id]:
                kimi_pass_rounds.append(r)
            else:
                kimi_fail_rounds.append(r)

    glm_pass_rounds, glm_fail_rounds = [], []
    for inst_id in valid_ids:
        if inst_id in glm_rounds and inst_id in glm_harness:
            r = glm_rounds[inst_id]
            if glm_harness[inst_id]:
                glm_pass_rounds.append(r)
            else:
                glm_fail_rounds.append(r)

    print(f"  Kimi pass={len(kimi_pass_rounds)}, fail={len(kimi_fail_rounds)}")
    print(f"  GLM  pass={len(glm_pass_rounds)}, fail={len(glm_fail_rounds)}")

    # ── 绘图 ─────────────────────────────────────────────────────────────────
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 5.5))

    # 左图：文件数 CDF
    plot_cdf(ax1, gold_files, C_GOLD, "Gold Patch")
    plot_cdf(ax1, kimi_files, C_KIMI, "Kimi")
    plot_cdf(ax1, glm_files,  C_GLM,  "GLM")
    ax1.set_xlabel("# Modified Files", fontsize=18, color="#555")
    ax1.set_ylabel("Cumulative %", fontsize=18, color="#555")
    ax1.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=17,
               loc="lower right")
    ax1.xaxis.set_major_locator(ticker.MultipleLocator(10))
    ax1.set_xlim(0, 80)
    ax1.set_ylim(50, 105)

    # 右图：交互轮次 CDF（同色系，实线=pass，虚线=fail）
    plot_cdf(ax2, kimi_pass_rounds, C_KIMI, "Kimi (pass)")
    plot_cdf(ax2, kimi_fail_rounds, C_KIMI, "Kimi (fail)", linewidth=1.8,
             linestyle="--")
    plot_cdf(ax2, glm_pass_rounds,  C_GLM,  "GLM (pass)")
    plot_cdf(ax2, glm_fail_rounds,  C_GLM,  "GLM (fail)", linewidth=1.8,
             linestyle="--")
    ax2.set_xlabel("# Interaction Rounds", fontsize=18, color="#555")
    ax2.set_ylabel("Cumulative %", fontsize=18, color="#555")
    ax2.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=17,
               loc="lower right")
    ax2.xaxis.set_major_locator(ticker.MultipleLocator(50))
    ax2.set_xlim(0, 250)
    ax2.set_ylim(0, 105)

    plt.tight_layout()

    out_path = os.path.join(_PROJECT_ROOT, "images", "failure_analysis_cdf.pdf")
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


if __name__ == "__main__":
    main()
