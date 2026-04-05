#!/usr/bin/env python3
"""
从 scale 数据集（各 batch 的 result.json）按语言汇总出现过的所有 GitHub 仓库，
通过 GitHub REST API 获取 star 数（与 src/pipeline 中 bulk_collect 系列相同方式），
输出每种语言中这些仓库的最低 star 数及对应仓库。

默认扫描: <仓库根>/scale/docker/batch*/result/result.json
可选合并: <仓库根>/scale/language-repos/*.json 中的仓库（若文件非空，格式为 owner/repo 字符串数组）

需要环境变量：优先 GITHUB_TOKEN，否则 GH_TOKEN（通过 os.getenv 从进程环境读取）。

重试策略：按队列依次请求各仓库；仅当连续 3 个仓库请求都失败时，对这三个中的第一个仓库按 --pause-on-error 间隔再请求 3 次；若成功则把后两个失败仓库插回队列前端继续。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from collections import defaultdict
from pathlib import Path

import requests

# language-repos 文件名（不含扩展名） -> 与实例中 language 字段一致的 key
_LANGUAGE_REPO_FILENAME_TO_KEY: dict[str, str] = {
    "python": "python",
    "java": "java",
    "go": "go",
    "rust": "rust",
    "c": "c",
    "c++": "c++",
    "ts": "typescript",
}


def _repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def _load_result_json(path: Path) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        raise ValueError(f"期望 JSON 数组: {path}")
    return [x for x in data if isinstance(x, dict)]


def collect_repos_from_batch_results(scale_root: Path) -> dict[str, set[str]]:
    """从 scale/docker/batch*/result/result.json 收集每种语言出现过的 repo。"""
    out: dict[str, set[str]] = defaultdict(set)
    for path in sorted(Path(scale_root).glob("docker/batch*/result/result.json")):
        for item in _load_result_json(path):
            lang = item.get("language")
            repo = item.get("repo")
            if isinstance(lang, str) and isinstance(repo, str) and repo.strip():
                out[lang.strip().lower()].add(repo.strip())
    return dict(out)


def _parse_repo_entry(entry: object) -> str | None:
    if isinstance(entry, str) and "/" in entry:
        return entry.strip()
    if isinstance(entry, dict):
        r = entry.get("repo") or entry.get("full_name")
        if isinstance(r, str) and "/" in r:
            return r.strip()
    return None


def collect_repos_from_language_repos_dir(lang_repos_dir: Path) -> dict[str, set[str]]:
    """合并 scale/language-repos 下各 JSON（若存在且非空）。"""
    out: dict[str, set[str]] = defaultdict(set)
    if not lang_repos_dir.is_dir():
        return dict(out)
    for json_path in sorted(lang_repos_dir.glob("*.json")):
        key = _LANGUAGE_REPO_FILENAME_TO_KEY.get(json_path.stem.lower())
        if not key:
            continue
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, list) or not data:
            continue
        for entry in data:
            r = _parse_repo_entry(entry)
            if r:
                out[key].add(r)
    return dict(out)


def merge_repo_sets(
    a: dict[str, set[str]], b: dict[str, set[str]]
) -> dict[str, set[str]]:
    keys = set(a) | set(b)
    return {k: set(a.get(k, set())) | set(b.get(k, set())) for k in keys}


def _respect_rate_limit(resp: requests.Response) -> None:
    remaining = resp.headers.get("X-RateLimit-Remaining")
    if remaining is not None and int(remaining) <= 1:
        reset = resp.headers.get("X-RateLimit-Reset")
        if reset:
            wait = max(0.0, float(reset) - time.time()) + 1.0
            print(f"[速率限制] 接近上限，等待 {wait:.1f} 秒", file=sys.stderr)
            time.sleep(wait)


def _exit_on_unauthorized(resp: requests.Response) -> None:
    """401 表示 token 无效/过期，重试无意义，直接退出。"""
    if resp.status_code != 401:
        return
    print(
        "GitHub 返回 401 Unauthorized：当前 GITHUB_TOKEN / GH_TOKEN 无效、已撤销或格式不对。\n"
        "请在本机重新生成 Personal Access Token（classic 或 fine-grained 且具备读公开仓库权限），"
        "并 export 后再运行。",
        file=sys.stderr,
    )
    sys.exit(1)


def _fetch_one_repo_stars_once(owner: str, name: str, token: str) -> int:
    """单次 GET /repos/{owner}/{repo}；401 直接退出进程。"""
    r = requests.get(
        f"https://api.github.com/repos/{owner}/{name}",
        headers={
            "Accept": "application/vnd.github.v3+json",
            "Authorization": f"Bearer {token}",
        },
        timeout=30,
    )
    _exit_on_unauthorized(r)
    _respect_rate_limit(r)
    r.raise_for_status()
    return int(r.json().get("stargazers_count", 0))


def fetch_stars_for_repos(
    repos: set[str], token: str, pause_on_error: float
) -> dict[str, int]:
    """
    repo 全名 -> star 数。
    连续 3 个仓库请求均失败后，仅对其中第一个仓库再请求 3 次（每次间隔 pause_on_error 秒）；
    若成功，将后两个失败仓库插回队列前端。
    """
    stars: dict[str, int] = {}
    queue = list(sorted(repos))
    consecutive_failures: list[str] = []
    total = len(queue)

    while queue:
        full = queue.pop(0)
        owner, _, name = full.partition("/")
        if not owner or not name:
            print(f"[跳过] 非法 repo 名: {full}", file=sys.stderr)
            continue

        try:
            stars[full] = _fetch_one_repo_stars_once(owner, name, token)
            consecutive_failures = []
        except Exception:
            consecutive_failures.append(full)
            if len(consecutive_failures) < 3:
                continue

            first = consecutive_failures[0]
            fo, _, fn = first.partition("/")
            print(
                f"[重试] 连续 3 个仓库失败 {consecutive_failures}，"
                f"对第一个 {first} 间隔 {pause_on_error:.0f}s 后重试 3 次",
                file=sys.stderr,
            )
            last_err: Exception | None = None
            for attempt in range(3):
                time.sleep(pause_on_error)
                try:
                    stars[first] = _fetch_one_repo_stars_once(fo, fn, token)
                    rest = consecutive_failures[1:]
                    queue = rest + queue
                    consecutive_failures = []
                    print(
                        f"[重试] {first} 成功，将后 {len(rest)} 个仓库插回队列",
                        file=sys.stderr,
                    )
                    break
                except Exception as e2:
                    last_err = e2
                    print(
                        f"[重试] {first} 第 {attempt + 1}/3 次仍失败: {e2}",
                        file=sys.stderr,
                    )
            else:
                assert last_err is not None
                raise last_err

            continue

        if len(stars) % 50 == 0 and len(stars) > 0:
            print(f"  已成功 {len(stars)}/{total} 个仓库", file=sys.stderr)

    return stars


def main() -> None:
    parser = argparse.ArgumentParser(description="统计 scale 各语言出现仓库的最低 star 数")
    parser.add_argument(
        "--scale-root",
        type=Path,
        default=_repo_root() / "scale",
        help="scale 目录（默认: 仓库根/scale）",
    )
    parser.add_argument(
        "--no-batch-results",
        action="store_true",
        help="不读取 docker/batch*/result/result.json（仅用于调试）",
    )
    parser.add_argument(
        "--no-language-repos",
        action="store_true",
        help="不合并 language-repos/*.json",
    )
    parser.add_argument(
        "--output-json",
        type=Path,
        default=None,
        help="将结果写入 JSON 文件",
    )
    parser.add_argument(
        "--pause-on-error",
        type=float,
        default=60.0,
        help="连续 3 个仓库失败后，对第一个仓库重试 3 次时每次间隔秒数（默认 60）",
    )
    args = parser.parse_args()

    token = (os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN") or "").strip()
    if not token:
        print("请设置环境变量 GITHUB_TOKEN 或 GH_TOKEN", file=sys.stderr)
        sys.exit(1)

    scale_root = args.scale_root.resolve()
    merged: dict[str, set[str]] = defaultdict(set)

    if not args.no_batch_results:
        merged = merge_repo_sets(merged, collect_repos_from_batch_results(scale_root))
    if not args.no_language_repos:
        merged = merge_repo_sets(
            merged, collect_repos_from_language_repos_dir(scale_root / "language-repos")
        )

    if not merged:
        print("未找到任何仓库（检查 scale 路径或是否被 --no-* 禁用）", file=sys.stderr)
        sys.exit(1)

    all_repos: set[str] = set()
    for s in merged.values():
        all_repos |= s

    print(f"共 {len(merged)} 种语言，去重后 {len(all_repos)} 个唯一仓库，开始请求 GitHub API…")
    stars_map = fetch_stars_for_repos(all_repos, token, args.pause_on_error)

    per_lang: list[dict] = []
    for lang in sorted(merged.keys()):
        repos = merged[lang]
        if not repos:
            continue
        min_star = None
        min_repo = None
        for r in repos:
            s = stars_map.get(r)
            if s is None:
                continue
            if min_star is None or s < min_star:
                min_star = s
                min_repo = r
        per_lang.append(
            {
                "language": lang,
                "repo_count": len(repos),
                "min_stargazers": min_star,
                "min_stargazers_repo": min_repo,
            }
        )
        ms = min_star if min_star is not None else "?"
        print(f"  {lang}: min_stars={ms} (仓库数 {len(repos)}) 最低: {min_repo}")

    if args.output_json:
        out = {
            "scale_root": str(scale_root),
            "unique_repos_total": len(all_repos),
            "by_language": per_lang,
        }
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        with open(args.output_json, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
        print(f"已写入 {args.output_json}")


if __name__ == "__main__":
    main()
