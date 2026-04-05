import json
import os
from collections import Counter
from datetime import datetime
from pathlib import Path

import html as html_lib
import gradio as gr
import matplotlib
import matplotlib.pyplot as plt

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

_UI_DATA_DIR = Path(__file__).resolve().parent / "data"


def _data_file(env_key: str, name: str) -> str:
    p = os.environ.get(env_key)
    if p:
        return p
    return str(_UI_DATA_DIR / name)


DATA_PATH = _data_file("YL_UI_DATA", "raw_latest.json")
SWEBENCH_VERIFIED_PATH = _data_file("YL_UI_SWEBENCH_VERIFIED", "swebench_verified.json")
SWEBENCH_PRO_PATH = _data_file("YL_UI_SWEBENCH_PRO", "swebench_pro.json")
ANNOTATIONS_PATH = _data_file("YL_UI_ANNOTATIONS", "annotations.json")

with open(DATA_PATH) as f:
    DATA = json.load(f)
DATA_MAP = {d["instance_id"]: d for d in DATA}

with open(SWEBENCH_VERIFIED_PATH) as f:
    SWE_VERIFIED = json.load(f)

with open(SWEBENCH_PRO_PATH) as f:
    SWE_PRO = json.load(f)
# normalize language field: js->javascript, ts->typescript
LANG_NORM = {"js": "javascript", "ts": "typescript"}
for d in SWE_PRO:
    d["language"] = LANG_NORM.get(d.get("repo_language", ""), d.get("repo_language", ""))

def load_annotations():
    if os.path.exists(ANNOTATIONS_PATH):
        with open(ANNOTATIONS_PATH) as f:
            return json.load(f)
    return {}

def save_annotations(annos):
    with open(ANNOTATIONS_PATH, "w") as f:
        json.dump(annos, f, indent=2, ensure_ascii=False)

# ==================== Tab 1: Statistics ====================

import numpy as np
from scipy.stats import gaussian_kde

# 文档类扩展名/路径：不计入 loc 与修改文件数
_DOC_EXTS = {
    ".md", ".markdown", ".rst", ".txt",
    ".adoc", ".asciidoc", ".tex", ".texi", ".org",
    ".htm", ".html",
}


def _is_doc_file(filename):
    """文档文件（按扩展名）不计入 loc/文件数。"""
    if not (filename or filename.strip()):
        return False
    ext = os.path.splitext(filename.strip().lower())[1]
    return ext in _DOC_EXTS


def _parse_patch_files(patch_str):
    """Parse patch by 'diff --git', yield (filename, part) for each file. filename may be ''."""
    if not patch_str:
        return
    parts = patch_str.split("diff --git ")
    for part in parts:
        if not part.strip():
            continue
        filename = ""
        for line in part.splitlines():
            if line.startswith("+++ b/"):
                filename = line[6:].strip()
                break
            if line.startswith("+++ /dev/null"):
                break
        yield filename, part


def count_patch_lines(patch_str):
    """Count added+deleted lines in a patch, excluding document files."""
    total = 0
    for filename, part in _parse_patch_files(patch_str):
        if _is_doc_file(filename):
            continue
        for line in part.splitlines():
            if (line.startswith("+") and not line.startswith("+++")) or (
                line.startswith("-") and not line.startswith("---")
            ):
                total += 1
    return total


def count_patch_files(patch_str):
    """Count number of files in a patch, excluding document files."""
    n = 0
    for filename, _ in _parse_patch_files(patch_str):
        if not _is_doc_file(filename):
            n += 1
    return n

def precompute_stats():
    # --- ProMax stats per language ---
    pm_langs = Counter(d["language"] for d in DATA)
    pm_repos_per_lang = {}
    for d in DATA:
        pm_repos_per_lang.setdefault(d["language"], set()).add(d["repo"])
    pm_repo_count = {k: len(v) for k, v in pm_repos_per_lang.items()}
    pm_avg_files = {}
    pm_avg_loc = {}
    for lang in pm_langs:
        items = [d for d in DATA if d["language"] == lang]
        pm_avg_files[lang] = sum(d.get("num_non_test", 0) for d in items) / len(items)
        pm_avg_loc[lang] = sum(d.get("loc", 0) for d in items) / len(items)

    # --- SWE-bench Verified stats (Python only) ---
    sv_count = len(SWE_VERIFIED)
    sv_repos = len(set(d["repo"] for d in SWE_VERIFIED))
    sv_avg_files = sum(count_patch_files(d.get("patch", "")) for d in SWE_VERIFIED) / sv_count
    sv_avg_loc = sum(count_patch_lines(d.get("patch", "")) for d in SWE_VERIFIED) / sv_count

    # --- SWE-bench Pro stats per language ---
    sp_langs = Counter(d["language"] for d in SWE_PRO)
    sp_repos_per_lang = {}
    for d in SWE_PRO:
        sp_repos_per_lang.setdefault(d["language"], set()).add(d["repo"])
    sp_repo_count = {k: len(v) for k, v in sp_repos_per_lang.items()}
    sp_avg_files = {}
    sp_avg_loc = {}
    for lang in sp_langs:
        items = [d for d in SWE_PRO if d["language"] == lang]
        sp_avg_files[lang] = sum(count_patch_files(d.get("patch", "")) for d in items) / len(items)
        sp_avg_loc[lang] = sum(count_patch_lines(d.get("patch", "")) for d in items) / len(items)

    # --- Summary text ---
    pm_total_repos = len(set(d["repo"] for d in DATA))
    pm_avg_loc_all = sum(d.get("loc", 0) for d in DATA) / len(DATA)
    pm_avg_files_all = sum(d.get("num_non_test", 0) for d in DATA) / len(DATA)
    sp_total_repos = len(set(d["repo"] for d in SWE_PRO))
    sp_avg_loc_all = sum(count_patch_lines(d.get("patch", "")) for d in SWE_PRO) / len(SWE_PRO)
    sp_avg_files_all = sum(count_patch_files(d.get("patch", "")) for d in SWE_PRO) / len(SWE_PRO)
    summary = (
        f"ProMax: {len(DATA)} instances | {len(pm_langs)} languages | {pm_total_repos} repos | "
        f"avg LOC {pm_avg_loc_all:.1f} | avg files {pm_avg_files_all:.1f}\n"
        f"SWE-bench Pro: {len(SWE_PRO)} instances | {len(sp_langs)} languages | {sp_total_repos} repos | "
        f"avg LOC {sp_avg_loc_all:.1f} | avg files {sp_avg_files_all:.1f}\n"
        f"SWE-bench Verified: {sv_count} instances | 1 language (Python) | {sv_repos} repos | "
        f"avg LOC {sv_avg_loc:.1f} | avg files {sv_avg_files:.1f}"
    )

    # --- Collect all languages across all datasets ---
    all_langs = sorted(set(list(pm_langs.keys()) + list(sp_langs.keys()) + ["python"]))
    x = np.arange(len(all_langs))
    w = 0.25

    # Colors: muted, modern palette
    C_PM = "#5B8DEF"   # soft blue
    C_SP = "#43B581"   # teal green
    C_SV = "#FAA61A"   # warm amber

    def add_labels(ax, bars, vals, fmt="d"):
        for bar, val in zip(bars, vals):
            if val:
                label = f"{val:.1f}" if fmt == "f" else str(int(val))
                ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + ax.get_ylim()[1] * 0.008,
                        label, ha="center", va="bottom", fontsize=8, color="#444")

    def make_chart(title, ylabel, v_pm, v_sp, v_sv, fmt="d"):
        fig, ax = plt.subplots(figsize=(13, 5.5))
        b1 = ax.bar(x - w, v_pm, w, label="Ours", color=C_PM, edgecolor="white", linewidth=0.5, zorder=3)
        b2 = ax.bar(x, v_sp, w, label="SWE-bench Pro", color=C_SP, edgecolor="white", linewidth=0.5, zorder=3)
        b3 = ax.bar(x + w, v_sv, w, label="SWE-bench Verified", color=C_SV, edgecolor="white", linewidth=0.5, zorder=3)
        ax.set_xticks(x)
        ax.set_xticklabels([l.capitalize() for l in all_langs], fontsize=10)
        ax.set_ylabel(ylabel, fontsize=10, color="#555")
        ax.legend(frameon=True, fancybox=True, shadow=False, framealpha=0.9, fontsize=9, loc="upper right")
        ax.tick_params(axis="y", colors="#888")
        add_labels(ax, b1, v_pm, fmt)
        add_labels(ax, b2, v_sp, fmt)
        add_labels(ax, b3, v_sv, fmt)
        plt.tight_layout()
        return fig

    fig1 = make_chart("Instances per Language", "Count",
        [pm_langs.get(l, 0) for l in all_langs],
        [sp_langs.get(l, 0) for l in all_langs],
        [sv_count if l == "python" else 0 for l in all_langs])

    fig2 = make_chart("Repos per Language", "Count",
        [pm_repo_count.get(l, 0) for l in all_langs],
        [sp_repo_count.get(l, 0) for l in all_langs],
        [sv_repos if l == "python" else 0 for l in all_langs])

    fig3 = make_chart("Avg Modified Non-Test Files per Language", "Files",
        [pm_avg_files.get(l, 0) for l in all_langs],
        [sp_avg_files.get(l, 0) for l in all_langs],
        [sv_avg_files if l == "python" else 0 for l in all_langs], fmt="f")

    fig4 = make_chart("Avg Modified LOC per Language", "LOC",
        [pm_avg_loc.get(l, 0) for l in all_langs],
        [sp_avg_loc.get(l, 0) for l in all_langs],
        [sv_avg_loc if l == "python" else 0 for l in all_langs], fmt="f")

    # --- Histograms for distribution (overlaid + KDE fit) ---
    def make_dist(title, xlabel, datasets, bins):
        """datasets: list of (vals, color, label)"""
        fig, ax = plt.subplots(figsize=(13, 5))
        x_smooth = np.linspace(bins[0], bins[-1], 300)
        for vals, color, label in datasets:
            if not vals:
                continue
            counts, _ = np.histogram(vals, bins=bins)
            pcts = counts / len(vals) * 100
            centers = bins[:-1] + np.diff(bins) / 2
            ax.bar(centers, pcts, width=np.diff(bins)[0] * 0.85, color=color,
                   alpha=0.35, edgecolor="white", linewidth=0.5, zorder=2)
            # KDE fit line
            arr = np.array(vals, dtype=float)
            if len(set(arr)) > 1:
                kde = gaussian_kde(arr, bw_method=0.3)
                density = kde(x_smooth)
                # scale density to match percentage axis
                bin_width = np.diff(bins)[0]
                ax.plot(x_smooth, density * 100 * bin_width, color=color,
                        linewidth=2.2, label=label, zorder=4)
            else:
                ax.plot([], [], color=color, linewidth=2.2, label=label)
        ax.set_xlabel(xlabel, fontsize=10, color="#555")
        ax.set_ylabel("Percentage (%)", fontsize=10, color="#555")
        ax.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=9, loc="upper right")
        ax.set_xlim(bins[0], bins[-1])
        plt.tight_layout()
        return fig

    # -- Files distribution --
    pm_file_counts = [d.get("num_non_test", 0) for d in DATA]
    sp_file_counts = [count_patch_files(d.get("patch", "")) for d in SWE_PRO]
    sv_file_counts = [count_patch_files(d.get("patch", "")) for d in SWE_VERIFIED]
    all_fc = pm_file_counts + sp_file_counts + sv_file_counts
    file_hi = int(np.percentile(all_fc, 95)) + 2
    file_bins = np.arange(0, file_hi + 1) - 0.5

    fig5 = make_dist("Distribution of Modified Files per Instance", "# Modified Files",
        [(pm_file_counts, C_PM, "Ours"), (sp_file_counts, C_SP, "SWE-bench Pro"),
         (sv_file_counts, C_SV, "SWE-bench Verified")], file_bins)

    # -- LOC distribution (wider bins) --
    pm_loc_counts = [d.get("loc", 0) for d in DATA]
    sp_loc_counts = [count_patch_lines(d.get("patch", "")) for d in SWE_PRO]
    sv_loc_counts = [count_patch_lines(d.get("patch", "")) for d in SWE_VERIFIED]
    all_lc = pm_loc_counts + sp_loc_counts + sv_loc_counts
    loc_hi = int(np.percentile(all_lc, 95))
    loc_step = max(5, round(loc_hi / 20 / 5) * 5)
    loc_bins = np.arange(0, loc_hi + loc_step + 1, loc_step)

    fig6 = make_dist("Distribution of Modified LOC per Instance", "# Modified LOC",
        [(pm_loc_counts, C_PM, "Ours"), (sp_loc_counts, C_SP, "SWE-bench Pro"),
         (sv_loc_counts, C_SV, "SWE-bench Verified")], loc_bins)

    # -- Per-language distribution for Ours --
    ours_lang_figs = {}
    for lang in sorted(pm_langs.keys()):
        items = [d for d in DATA if d["language"] == lang]
        f_vals = [d.get("num_non_test", 0) for d in items]
        l_vals = [d.get("loc", 0) for d in items]
        # files
        fhi = int(np.percentile(f_vals, 95)) + 2 if f_vals else 5
        fb = np.arange(0, fhi + 1) - 0.5
        fig_f = make_dist(f"Modified Files — {lang.capitalize()} (n={len(items)})",
                          "# Modified Files", [(f_vals, C_PM, lang.capitalize())], fb)
        # loc
        lhi = int(np.percentile(l_vals, 95)) if l_vals else 50
        ls = max(5, round(lhi / 15 / 5) * 5)
        lb = np.arange(0, lhi + ls + 1, ls)
        fig_l = make_dist(f"Modified LOC — {lang.capitalize()} (n={len(items)})",
                          "# Modified LOC", [(l_vals, C_PM, lang.capitalize())], lb)
        ours_lang_figs[lang] = (fig_f, fig_l)

    # --- CDF plots (cumulative %, right-shift = more complex) ---
    def make_cdf(title, xlabel, datasets):
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
        ax.set_ylim(0, 105)
        plt.tight_layout()
        return fig

    fig7 = make_cdf("CDF: Modified Files per Instance", "# Modified Files",
        [(pm_file_counts, C_PM, "Ours"), (sp_file_counts, C_SP, "SWE-bench Pro"),
         (sv_file_counts, C_SV, "SWE-bench Verified")])

    fig8 = make_cdf("CDF: Modified LOC per Instance", "# Modified LOC",
        [(pm_loc_counts, C_PM, "Ours"), (sp_loc_counts, C_SP, "SWE-bench Pro"),
         (sv_loc_counts, C_SV, "SWE-bench Verified")])

    # --- Complexity bucket stacked bar chart ---
    def bucket_pcts(vals, thresholds, labels):
        n = len(vals)
        pcts = []
        for lo, hi in zip([0] + thresholds, thresholds + [float('inf')]):
            pcts.append(sum(1 for v in vals if lo < v <= hi) / n * 100)
        return pcts

    # Files buckets
    f_thresh = [1, 3, 5, 10]
    f_labels = ["1", "2-3", "4-5", "6-10", ">10"]
    pm_fb = bucket_pcts(pm_file_counts, f_thresh, f_labels)
    sp_fb = bucket_pcts(sp_file_counts, f_thresh, f_labels)
    sv_fb = bucket_pcts(sv_file_counts, f_thresh, f_labels)

    fig9, ax9 = plt.subplots(figsize=(10, 5))
    x9 = np.arange(3)
    bottom_pm = bottom_sp = bottom_sv = 0
    bucket_colors = ["#a8d8ea", "#7ec8e3", "#5bb5d5", "#3a8fbf", "#1a6fa0"]
    for i, lbl in enumerate(f_labels):
        vals = [pm_fb[i], sp_fb[i], sv_fb[i]]
        bars = ax9.bar(x9, vals, 0.55, bottom=[
            sum(pm_fb[:i]), sum(sp_fb[:i]), sum(sv_fb[:i])],
            color=bucket_colors[i], edgecolor="white", linewidth=0.5, label=f"{lbl} files", zorder=3)
        for bar, v in zip(bars, vals):
            if v > 4:
                ax9.text(bar.get_x() + bar.get_width()/2,
                         bar.get_y() + bar.get_height()/2,
                         f"{v:.0f}%", ha="center", va="center", fontsize=8, color="#333")
    ax9.set_xticks(x9)
    ax9.set_xticklabels(["Ours", "SWE-bench Pro", "SWE-bench Verified"], fontsize=11)
    ax9.set_ylabel("Percentage (%)", fontsize=10, color="#555")
    ax9.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=8, loc="upper right",
               bbox_to_anchor=(1.15, 1))
    plt.tight_layout()

    # LOC buckets
    l_thresh = [20, 50, 100, 200]
    l_labels = ["≤20", "21-50", "51-100", "101-200", ">200"]
    pm_lb = bucket_pcts(pm_loc_counts, l_thresh, l_labels)
    sp_lb = bucket_pcts(sp_loc_counts, l_thresh, l_labels)
    sv_lb = bucket_pcts(sv_loc_counts, l_thresh, l_labels)

    fig10, ax10 = plt.subplots(figsize=(10, 5))
    for i, lbl in enumerate(l_labels):
        vals = [pm_lb[i], sp_lb[i], sv_lb[i]]
        bars = ax10.bar(x9, vals, 0.55, bottom=[
            sum(pm_lb[:i]), sum(sp_lb[:i]), sum(sv_lb[:i])],
            color=bucket_colors[i], edgecolor="white", linewidth=0.5, label=f"{lbl} LOC", zorder=3)
        for bar, v in zip(bars, vals):
            if v > 4:
                ax10.text(bar.get_x() + bar.get_width()/2,
                          bar.get_y() + bar.get_height()/2,
                          f"{v:.0f}%", ha="center", va="center", fontsize=8, color="#333")
    ax10.set_xticks(x9)
    ax10.set_xticklabels(["Ours", "SWE-bench Pro", "SWE-bench Verified"], fontsize=11)
    ax10.set_ylabel("Percentage (%)", fontsize=10, color="#555")
    ax10.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=8, loc="upper right",
                bbox_to_anchor=(1.15, 1))
    plt.tight_layout()

    return summary, fig1, fig2, fig3, fig4, fig5, fig6, fig7, fig8, fig9, fig10, ours_lang_figs

# Pre-generate so they show immediately
STATS_SUMMARY, STATS_FIG1, STATS_FIG2, STATS_FIG3, STATS_FIG4, STATS_FIG5, STATS_FIG6, STATS_FIG7, STATS_FIG8, STATS_FIG9, STATS_FIG10, STATS_LANG_FIGS = precompute_stats()

def colorize_diff(text):
    if not text:
        return ""
    lines = []
    for line in text.splitlines():
        escaped = html_lib.escape(line)
        if line.startswith("+") and not line.startswith("+++"):
            lines.append(f'<span style="color:#22863a;background:#dafbe1">{escaped}</span>')
        elif line.startswith("-") and not line.startswith("---"):
            lines.append(f'<span style="color:#cb2431;background:#ffeef0">{escaped}</span>')
        elif line.startswith("@@"):
            lines.append(f'<span style="color:#6f42c1">{escaped}</span>')
        else:
            lines.append(escaped)
    return '<pre style="overflow-x:auto;font-size:13px;line-height:1.5">' + "\n".join(lines) + "</pre>"

# ==================== Tab 2: Review & Annotate ====================

ALL_LANGS = sorted(set(d["language"] for d in DATA))
LANG_REPOS = {}
for d in DATA:
    LANG_REPOS.setdefault(d["language"], set()).add(d["repo"])
for k in LANG_REPOS:
    LANG_REPOS[k] = sorted(LANG_REPOS[k])

def on_lang_change(language):
    if not language or language == "All":
        repos = sorted(set(d["repo"] for d in DATA))
        ids = [d["instance_id"] for d in DATA]
    else:
        repos = LANG_REPOS.get(language, [])
        ids = [d["instance_id"] for d in DATA if d["language"] == language]
    return (
        gr.update(choices=["All"] + repos, value="All"),
        gr.update(choices=ids, value=ids[0] if ids else None),
    )

def on_repo_change(language, repo):
    items = DATA
    if language and language != "All":
        items = [d for d in items if d["language"] == language]
    if repo and repo != "All":
        items = [d for d in items if d["repo"] == repo]
    ids = [d["instance_id"] for d in items]
    return gr.update(choices=ids, value=ids[0] if ids else None)

def load_instance(instance_id):
    empty = ("",) * 11
    if not instance_id:
        return empty
    d = DATA_MAP.get(instance_id)
    if not d:
        return empty
    annos = load_annotations()
    anno = annos.get(instance_id, {})

    pr = d.get('pull_number', 'N/A')
    pr_str = f"#{pr}" if pr != 'N/A' else 'N/A'
    meta = (
        f"**Instance:** `{d['instance_id']}`  \n"
        f"**Repo:** `{d['repo']}` | **Language:** `{d['language']}` | "
        f"**PR:** {pr_str}  \n"
        f"**URL:** {d.get('html_url', 'N/A')}  \n"
        f"**Files:** {d.get('num_files', 'N/A')} (test: {d.get('num_test', 'N/A')}, non-test: {d.get('num_non_test', 'N/A')}) | "
        f"**LOC:** {d.get('loc', 'N/A')}"
    )
    problem = d.get("problem_statement", "") or ""
    hints = d.get("hints_text", "") or ""
    patch = colorize_diff(d.get('patch', ''))
    test_patch = colorize_diff(d.get('test_patch', ''))
    eval_script = f"```bash\n{d.get('eval_script', '') or ''}\n```"

    rating = None
    comment = ""
    anno_list = annos.get(instance_id, [])
    if anno_list:
        history_lines = []
        for a in anno_list:
            history_lines.append(f"[{a.get('timestamp','')}] **{a.get('author','?')}**: {a.get('rating','')} — {a.get('comment','')}")
        status = f"{len(anno_list)} annotation(s):\n\n" + "\n\n".join(history_lines)
    else:
        status = "Not annotated yet"

    return (meta, problem, hints, patch, test_patch, eval_script, rating, comment, status)

def save_annotation(instance_id, author, rating, comment):
    if not instance_id:
        return "No instance selected"
    if not author or not author.strip():
        return "Please enter your name"
    annos = load_annotations()
    if instance_id not in annos:
        annos[instance_id] = []
    annos[instance_id].append({
        "author": author.strip(),
        "rating": rating,
        "comment": comment,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    })
    save_annotations(annos)
    total_annotated = sum(1 for v in annos.values() if v)
    return f"Saved! ({total_annotated}/{len(DATA)} instances annotated)"

# ==================== Build UI ====================

def build_app():
    with gr.Blocks(title="SWE-Bench ProMax Viewer", theme=gr.themes.Soft()) as app:
        gr.Markdown("# SWE-Bench ProMax Data Viewer")

        with gr.Tab("Statistics"):
            summary_text = gr.Textbox(label="Summary", interactive=False, value=STATS_SUMMARY)
            with gr.Row():
                gr.Plot(value=STATS_FIG1, show_label=False)
                gr.Plot(value=STATS_FIG2, show_label=False)
            with gr.Row():
                gr.Plot(value=STATS_FIG3, show_label=False)
                gr.Plot(value=STATS_FIG4, show_label=False)
            with gr.Accordion("Complexity Comparison (CDF & Buckets)", open=False):
                with gr.Row():
                    gr.Plot(value=STATS_FIG7, show_label=False)
                    gr.Plot(value=STATS_FIG8, show_label=False)
                with gr.Row():
                    gr.Plot(value=STATS_FIG9, show_label=False)
                    gr.Plot(value=STATS_FIG10, show_label=False)
            with gr.Accordion("Distribution Histograms (Files & LOC)", open=False):
                gr.Plot(value=STATS_FIG5, show_label=False)
                gr.Plot(value=STATS_FIG6, show_label=False)
            with gr.Accordion("Ours: Per-Language Distribution", open=False):
                for lang in sorted(STATS_LANG_FIGS.keys()):
                    fig_f, fig_l = STATS_LANG_FIGS[lang]
                    with gr.Row():
                        gr.Plot(value=fig_f, show_label=False)
                        gr.Plot(value=fig_l, show_label=False)

        with gr.Tab("Review & Annotate"):
            default_id = DATA[0]["instance_id"]
            with gr.Row():
                lang_filter = gr.Dropdown(choices=["All"] + ALL_LANGS, value="All", label="Language")
                repo_filter = gr.Dropdown(choices=["All"] + sorted(set(d["repo"] for d in DATA)), value="All", label="Repo")
                instance_dd = gr.Dropdown(choices=[d["instance_id"] for d in DATA], value=default_id, label="Instance", interactive=True)

            default_data = load_instance(default_id)
            meta_md = gr.Markdown(value=default_data[0])
            gr.Markdown("### Problem Statement")
            problem_md = gr.Markdown(value=default_data[1])
            gr.Markdown("### Hints")
            hints_md = gr.Markdown(value=default_data[2])
            gr.Markdown("### Patch (diff)")
            patch_md = gr.Markdown(value=default_data[3])
            gr.Markdown("### Test Patch (diff)")
            test_patch_md = gr.Markdown(value=default_data[4])
            gr.Markdown("### Eval Script")
            eval_md = gr.Markdown(value=default_data[5])

            gr.Markdown("---\n### Annotation")
            author_box = gr.Textbox(label="Your Name", placeholder="e.g. Alice", lines=1)
            with gr.Row():
                rating_radio = gr.Radio(choices=["good", "acceptable", "bad"], label="Quality Rating", value=default_data[6])
                comment_box = gr.Textbox(label="Comment", lines=3, placeholder="Write your notes here...", value=default_data[7])
            with gr.Row():
                save_btn = gr.Button("Save Annotation", variant="primary")
            gr.Markdown("### History")
            status_md = gr.Markdown(value=default_data[8])

            # Cascading filters: language → repo + instance, repo → instance
            review_outputs = [meta_md, problem_md, hints_md, patch_md, test_patch_md, eval_md, rating_radio, comment_box, status_md]

            lang_filter.change(on_lang_change, inputs=[lang_filter], outputs=[repo_filter, instance_dd])
            repo_filter.change(on_repo_change, inputs=[lang_filter, repo_filter], outputs=[instance_dd])
            instance_dd.change(load_instance, inputs=[instance_dd], outputs=review_outputs)
            save_btn.click(save_annotation, inputs=[instance_dd, author_box, rating_radio, comment_box], outputs=[status_md])

    return app

if __name__ == "__main__":
    app = build_app()
    app.launch(server_name="0.0.0.0", server_port=10888)
