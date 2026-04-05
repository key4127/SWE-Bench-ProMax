#!/usr/bin/env python3
"""
Compute per-repo, per-language, and overall ratios of over-wide / over-narrow
from judge_result.json, and save plots to image/.
Requires: conda activate all (matplotlib, pandas).
"""

import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import pandas as pd

# ── Paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR   = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]

JUDGE_JSON = SCRIPT_DIR / "judge_result.json"
SWE_JSON   = PROJECT_ROOT / "result/strengthen/all_nl.json"
OUT_DIR    = SCRIPT_DIR / "image"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────────
with open(JUDGE_JSON, encoding="utf-8") as f:
    judge_data = json.load(f)

with open(SWE_JSON, encoding="utf-8") as f:
    swe_data = json.load(f)

meta = {d["instance_id"]: {"repo": d.get("repo", ""), "language": d.get("language", "")}
        for d in swe_data}

rows = []
for entry in judge_data:
    iid = entry["instance_id"]
    m   = meta.get(iid, {"repo": "unknown", "language": "unknown"})
    rows.append({
        "instance_id": iid,
        "repo":        m["repo"],
        "language":    m["language"],
        "over_wide":   bool(entry.get("over_wide_test")),
        "over_narrow": bool(entry.get("over_narrow_test")),
    })

df = pd.DataFrame(rows)
print(f"Total samples: {len(df)}")
print(f"Language distribution:\n{df['language'].value_counts()}\n")
print(f"Unique repos: {df['repo'].nunique()}")

METRICS = {
    "over_wide":   "Over-wide",
    "over_narrow": "Over-narrow",
}
COLORS = ["#E07B54", "#5B8DB8"]

# ── Helper: compute group ratios ──────────────────────────────────────
def group_ratio(df_sub: pd.DataFrame, by: str) -> pd.DataFrame:
    grouped = df_sub.groupby(by)[list(METRICS.keys())].agg(["sum", "count"])
    records = []
    first_col = list(METRICS.keys())[0]
    for grp_val, row in grouped.iterrows():
        r = {"group": grp_val, "n": int(row[(first_col, "count")])}
        for col in METRICS.keys():
            r[col] = row[(col, "sum")] / row[(col, "count")] * 100
        records.append(r)
    return pd.DataFrame(records).sort_values("group")

# ── Plot function ─────────────────────────────────────────────────────
def plot_grouped_bars(df_ratio: pd.DataFrame,
                      title: str,
                      out_path: Path,
                      x_label: str = "",
                      rotate: int = 0,
                      figsize: tuple = (10, 5)):
    groups = df_ratio["group"].tolist()
    width  = 0.22
    x      = range(len(groups))

    fig, ax = plt.subplots(figsize=figsize)
    for i, (col, label) in enumerate(METRICS.items()):
        offsets = [xi + (i - 1) * width for xi in x]
        bars = ax.bar(offsets, df_ratio[col], width=width,
                      label=label, color=COLORS[i], alpha=0.88, zorder=3)
        for bar, val in zip(bars, df_ratio[col]):
            if val > 0:
                ax.text(bar.get_x() + bar.get_width() / 2,
                        bar.get_height() + 0.5,
                        f"{val:.0f}%",
                        ha="center", va="bottom", fontsize=7.5, color="#333333")

    n_labels = [f"{g}\n(n={row['n']})"
                for g, row in zip(groups, df_ratio.to_dict("records"))]
    ax.set_xticks(list(x))
    ax.set_xticklabels(n_labels, rotation=rotate,
                       ha="right" if rotate else "center", fontsize=9)
    ax.yaxis.set_major_formatter(mticker.PercentFormatter(decimals=0))
    ax.set_ylim(0, 110)
    ax.set_ylabel("Ratio (%)")
    ax.set_xlabel(x_label)
    ax.legend(loc="upper right", fontsize=9)
    ax.grid(axis="y", linestyle="--", alpha=0.5, zorder=0)
    ax.spines[["top", "right"]].set_visible(False)

    fig.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved: {out_path}")


# ── 1. Overall ────────────────────────────────────────────────────────
overall = {col: df[col].mean() * 100 for col in METRICS}
overall["n"] = len(df)

fig, ax = plt.subplots(figsize=(6, 4))
for i, (col, label) in enumerate(METRICS.items()):
    ax.bar(i, overall[col], color=COLORS[i], alpha=0.88, zorder=3,
           label=label, width=0.5)
    ax.text(i, overall[col] + 0.5, f"{overall[col]:.1f}%",
            ha="center", va="bottom", fontsize=10, color="#333333")

ax.set_xticks(range(len(METRICS)))
ax.set_xticklabels(list(METRICS.values()), fontsize=10)
ax.yaxis.set_major_formatter(mticker.PercentFormatter(decimals=0))
ax.set_ylim(0, 110)
ax.set_ylabel("Ratio (%)")
ax.grid(axis="y", linestyle="--", alpha=0.5, zorder=0)
ax.spines[["top", "right"]].set_visible(False)
fig.tight_layout()
fig.savefig(OUT_DIR / "judge_stat_overall.pdf", dpi=150, bbox_inches="tight")
plt.close(fig)
print(f"Saved: {OUT_DIR / 'judge_stat_overall.pdf'}")

# ── 2. By language ────────────────────────────────────────────────────
df_lang = group_ratio(df, "language")
plot_grouped_bars(df_lang,
                  title="Statistics by Language",
                  out_path=OUT_DIR / "judge_stat_by_language.pdf",
                  x_label="Language",
                  rotate=0,
                  figsize=(10, 5))

# ── 3. By repo (batched, 20 per page) ────────────────────────────────
df_repo = group_ratio(df, "repo")
BATCH   = 20
n_batches = (len(df_repo) + BATCH - 1) // BATCH

for b in range(n_batches):
    sub = df_repo.iloc[b * BATCH : (b + 1) * BATCH].copy()
    plot_grouped_bars(sub,
                      title=f"Statistics by Repo (part {b+1}/{n_batches})",
                      out_path=OUT_DIR / f"judge_stat_by_repo_part{b+1}.pdf",
                      x_label="Repository",
                      rotate=30,
                      figsize=(max(10, len(sub) * 1.1), 6))

# ── Summary table ─────────────────────────────────────────────────────
print("\n=== Overall ===")
for col, label in METRICS.items():
    print(f"  {label}: {overall[col]:.1f}%")

print("\n=== By Language ===")
print(df_lang[["group", "n"] + list(METRICS.keys())].to_string(index=False))

print("\n=== By Repo ===")
print(df_repo[["group", "n"] + list(METRICS.keys())].to_string(index=False))
