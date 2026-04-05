#!/usr/bin/env python3
"""
统计某个 traj 目录下，按 harness 通过与否分组的平均步数，并生成可视化图表。

- traj_dir: 例如 result/preds_result/strengthen/v2/kimi，会遍历其下每个子目录里的 .json 文件，
  从每个 json 中读取 instance_id 与步数（messages 中 role=='assistant' 的数量）。
- pass_rate_path: 例如 result/harness_result/strengthen/v2/kimi.json，为 harness 结果 JSON，
  每项含 instance_id 与 passed（bool）。据此将 traj 分为通过/未通过两组，分别计算平均步数。

运行前请先: conda activate all
"""

import argparse
import json
import sys
from pathlib import Path

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


def get_steps_from_traj(data: dict) -> int:
    """从 traj 的 messages 中统计步数：role 为 assistant 的消息数量。"""
    messages = data.get("messages") or []
    return sum(1 for m in messages if isinstance(m, dict) and m.get("role") == "assistant")


def load_traj_steps(traj_dir: Path) -> dict[str, int]:
    """
    遍历 traj_dir 下每个子目录中的 .json 文件，读取 instance_id 与步数。
    返回 instance_id -> steps。若 json 中无 instance_id 则用文件名推导（去掉 .traj.json 后缀）。
    """
    traj_dir = traj_dir.resolve()
    if not traj_dir.is_dir():
        raise FileNotFoundError(f"traj 目录不存在: {traj_dir}")

    id_to_steps = {}
    for jf in sorted(traj_dir.rglob("*.traj.json")):
        try:
            with open(jf, encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, OSError) as e:
            print(f"[跳过] {jf}: {e}", file=sys.stderr)
            continue
        if not isinstance(data, dict):
            print(f"[跳过] {jf}: 根节点不是 dict", file=sys.stderr)
            continue
        iid = data.get("instance_id")
        if iid is None:
            # 用文件名：xxx.traj.json -> xxx
            stem = jf.stem
            if stem.endswith(".traj"):
                iid = stem[:-5]  # 去掉 .traj
            else:
                iid = stem
        steps = get_steps_from_traj(data)
        id_to_steps[iid] = steps
    return id_to_steps


def load_pass_map(pass_rate_path: Path) -> dict[str, bool]:
    """加载 harness 结果 JSON，返回 instance_id -> passed。"""
    pass_rate_path = pass_rate_path.resolve()
    if not pass_rate_path.is_file():
        raise FileNotFoundError(f"pass_rate 文件不存在: {pass_rate_path}")
    with open(pass_rate_path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        return {}
    out = {}
    for item in data:
        if not isinstance(item, dict):
            continue
        iid = item.get("instance_id")
        if iid is None:
            continue
        out[iid] = item.get("passed") is True
    return out


# ── 可视化（风格参照 src/yl_ui/stat_preds_cdf.py）────────────────────────────────

C_PASSED = "#43B581"   # teal green  — 通过
C_FAILED = "#E07B54"   # warm orange — 未通过
C_ALL    = "#5B8DEF"   # soft blue   — 全部


def _plot_cdf(ax, vals, color: str, label: str):
    if not vals:
        return
    sorted_v = np.sort(vals)
    cdf = np.arange(1, len(sorted_v) + 1) / len(sorted_v) * 100
    ax.plot(sorted_v, cdf, color=color, linewidth=2.2, label=label, zorder=3)


def plot_cdf_steps(steps_passed: list, steps_failed: list, title_suffix: str, out_path: Path) -> None:
    """步数 CDF：通过 vs 未通过。"""
    fig, ax = plt.subplots(figsize=(10, 5))
    _plot_cdf(ax, steps_passed, C_PASSED, f"通过（共 {len(steps_passed)} 条）")
    _plot_cdf(ax, steps_failed, C_FAILED, f"未通过（共 {len(steps_failed)} 条）")
    ax.set_xlabel("步数", fontsize=10, color="#555")
    ax.set_ylabel("累积百分比", fontsize=10, color="#555")
    ax.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=9, loc="lower right")
    all_steps = steps_passed + steps_failed
    x_max = max(all_steps) * 1.05 if all_steps else 250
    ax.set_xlim(0, min(x_max, 300))
    ax.set_ylim(0, 105)
    plt.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


def plot_avg_bars(avg_passed: float, avg_failed: float, avg_all: float,
                  n_passed: int, n_failed: int, title_suffix: str, out_path: Path) -> None:
    """柱状图：通过/未通过/全部 平均步数。"""
    fig, ax = plt.subplots(figsize=(7, 5))
    labels = [f"通过\n（共 {n_passed} 条）", f"未通过\n（共 {n_failed} 条）", "全部"]
    vals = [avg_passed if n_passed else 0, avg_failed if n_failed else 0, avg_all]
    colors = [C_PASSED, C_FAILED, C_ALL]
    x = np.arange(len(labels))
    bars = ax.bar(x, vals, color=colors, edgecolor="#333", linewidth=0.8)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=10)
    ax.set_ylabel("平均步数", fontsize=10, color="#555")
    for b, v in zip(bars, vals):
        if v > 0:
            ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1, f"{v:.1f}",
                    ha="center", va="bottom", fontsize=10, fontweight="bold", fontfamily="sans-serif")
    ax.set_ylim(0, max(vals) * 1.2 if vals else 120)
    plt.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


def plot_hist_steps(steps_passed: list, steps_failed: list, title_suffix: str, out_path: Path) -> None:
    """步数分布直方图：通过 vs 未通过。"""
    fig, ax = plt.subplots(figsize=(10, 5))
    all_steps = steps_passed + steps_failed
    bins = np.linspace(0, min(max(all_steps) * 1.02, 260), 26) if all_steps else np.linspace(0, 250, 26)
    if steps_passed:
        ax.hist(steps_passed, bins=bins, color=C_PASSED, alpha=0.7, label=f"通过（共 {len(steps_passed)} 条）", density=True)
    if steps_failed:
        ax.hist(steps_failed, bins=bins, color=C_FAILED, alpha=0.7, label=f"未通过（共 {len(steps_failed)} 条）", density=True)
    ax.set_xlabel("步数", fontsize=10, color="#555")
    ax.set_ylabel("密度", fontsize=10, color="#555")
    ax.legend(frameon=True, fancybox=True, framealpha=0.9, fontsize=9)
    ax.set_xlim(0, min(max(all_steps) * 1.05, 300) if all_steps else 250)
    plt.tight_layout()
    fig.savefig(out_path, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"已保存: {out_path}")


def main():
    parser = argparse.ArgumentParser(
        description="按 harness 通过与否统计 traj 平均步数并生成图表（traj 目录 + pass_rate JSON）"
    )
    parser.add_argument(
        "traj_dir",
        type=Path,
        help="traj 根目录，如 result/preds_result/strengthen/v2/kimi",
    )
    parser.add_argument(
        "pass_rate",
        type=Path,
        help="harness 结果 JSON，如 result/harness_result/strengthen/v2/kimi.json",
    )
    parser.add_argument(
        "-o", "--out-dir",
        type=Path,
        default=None,
        help="图表输出目录，默认与脚本同目录 src/stat",
    )
    parser.add_argument(
        "--no-plot",
        action="store_true",
        help="只打印统计，不生成图",
    )
    args = parser.parse_args()

    id_to_steps = load_traj_steps(args.traj_dir)
    id_to_passed = load_pass_map(args.pass_rate)

    steps_passed = []
    steps_failed = []
    for iid, steps in id_to_steps.items():
        if iid not in id_to_passed:
            continue
        if id_to_passed[iid]:
            steps_passed.append(steps)
        else:
            steps_failed.append(steps)

    n_traj = len(id_to_steps)
    n_in_harness = len(steps_passed) + len(steps_failed)
    n_passed = len(steps_passed)
    n_failed = len(steps_failed)

    def avg(xs):
        return sum(xs) / len(xs) if xs else float("nan")

    avg_passed = avg(steps_passed)
    avg_failed = avg(steps_failed)
    avg_all = avg(steps_passed + steps_failed) if (steps_passed or steps_failed) else float("nan")

    print("traj 目录:", args.traj_dir)
    print("pass_rate 文件:", args.pass_rate)
    print("traj 文件数（instance 数）:", n_traj)
    print("在 harness 中且匹配到的 instance 数:", n_in_harness)
    print("通过数:", n_passed, "  未通过数:", n_failed)
    print()
    print("平均步数（通过）:   ", f"{avg_passed:.2f}" if n_passed else "N/A")
    print("平均步数（未通过）: ", f"{avg_failed:.2f}" if n_failed else "N/A")
    print("平均步数（全部）:   ", f"{avg_all:.2f}" if n_in_harness else "N/A")

    if not args.no_plot and (steps_passed or steps_failed):
        out_dir = args.out_dir
        if out_dir is None:
            out_dir = Path(__file__).resolve().parent
        out_dir = out_dir.resolve()
        out_dir.mkdir(parents=True, exist_ok=True)
        title_suffix = args.traj_dir.name
        plot_cdf_steps(
            steps_passed, steps_failed,
            title_suffix,
            out_dir / f"traj_steps_cdf_{title_suffix}.pdf",
        )
        plot_avg_bars(
            avg_passed, avg_failed, avg_all,
            n_passed, n_failed,
            title_suffix,
            out_dir / f"traj_steps_avg_{title_suffix}.pdf",
        )
        plot_hist_steps(
            steps_passed, steps_failed,
            title_suffix,
            out_dir / f"traj_steps_hist_{title_suffix}.pdf",
        )


if __name__ == "__main__":
    main()
