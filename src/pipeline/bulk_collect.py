#!/usr/bin/env python3
"""
大规模运行 curl_commits 与 format_data，按语言和排除列表从 GitHub 按 star 由高到低爬取
该语言占比超过 80% 的仓库，直到通过 commit 数达到 2000 或剩余仓库 star < 50。
多数配置硬编码在下方常量中；语言与并发可通过命令行指定:
  python bulk_collect.py --language Python --workers 4
"""

import argparse
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

# 保证从 pipeline 目录运行时能导入 collection
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from collection.curl_commits import curl_filtered_commits
from collection.format_data import format_data

# ---------- 硬编码配置 ----------
# 默认目标语言：仅当命令行未传 --language 时使用，传参则覆盖（不算「唯一写死的语言」）
DEFAULT_LANGUAGE = "Python"
# 排除的仓库，格式 owner/repo
EXCLUDED_REPOS = {
}  # 例如: {"owner1/repo1", "owner2/repo2"}
# 排除列表文件路径（每行一个 owner/repo，# 为注释），空字符串表示不使用
EXCLUDED_FILE = ""
# 输出目录（curl_commits 与 format_data 的写入路径）
OUTPUT_DIR = "./scale/docker/batch4"
# commit 时间下限，ISO 8601
SINCE_TIME = "2025-01-01T00:00:00Z"
# GitHub token：环境变量 GITHUB_TOKEN 或 GH_TOKEN（在 main() 中读取）
# API 报错后暂停秒数
PAUSE_ON_ERROR_SECONDS = 60
# 只保留 license 在该列表中的仓库（与 fetch_the_same_jsons.py 一致）
ALLOWED_LICENSES = {
    "mit",
    "apache-2.0",
    "bsd-2-clause",
    "bsd-3-clause",
    "bsd-3-clause-clear",
    "0bsd",
    "gpl-2.0",
    "gpl-3.0",
    "lgpl-2.1",
    "lgpl-3.0",
    "agpl-3.0",
    "unlicense",
}
# ---------- 以下为固定逻辑 ----------

TARGET_COMMIT_COUNT = 400
MIN_STARS_THRESHOLD = 50
# star 上界（写死）：与 MIN 一起在搜索条件与逐条校验中使用，排除超大仓库
MAX_STARS_THRESHOLD = 500_000
LANGUAGE_RATIO_THRESHOLD = 0.8
SEARCH_PER_PAGE = 100
DEFAULT_WORKERS = 4


def load_excluded():
    excluded = set(EXCLUDED_REPOS)
    if EXCLUDED_FILE and os.path.isfile(EXCLUDED_FILE):
        with open(EXCLUDED_FILE, "r", encoding="utf-8") as f:
            for line in f:
                s = line.strip()
                if s and not s.startswith("#"):
                    excluded.add(s)
    return excluded


def search_repos_by_language(language, token, page=1):
    """调用 GitHub 搜索 API：指定语言，按 star 降序，返回一页结果。"""
    url = "https://api.github.com/search/repositories"
    # 使用 stars:min..max 在搜索端先过滤，减少无效请求
    q = f"language:{language} stars:{MIN_STARS_THRESHOLD}..{MAX_STARS_THRESHOLD}"
    params = {
        "q": q,
        "sort": "stars",
        "order": "desc",
        "per_page": SEARCH_PER_PAGE,
        "page": page,
    }
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json",
    }
    resp = requests.get(url, params=params, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json()


def get_repo_license_key(owner, repo, token):
    """请求 GitHub API 获取仓库的 license.key，无 license 或请求失败返回 None。"""
    url = f"https://api.github.com/repos/{owner}/{repo}"
    headers = {"Accept": "application/vnd.github.v3+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        resp = requests.get(url, headers=headers, timeout=30)
        resp.raise_for_status()
        return (resp.json().get("license") or {}).get("key")
    except Exception:
        return None


def get_repo_languages(owner, repo, token):
    """获取仓库各语言字节数，返回 { language_name: bytes }。"""
    url = f"https://api.github.com/repos/{owner}/{repo}/languages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.v3+json",
    }
    resp = requests.get(url, headers=headers, timeout=30)
    resp.raise_for_status()
    return resp.json()


def language_ratio_at_least(languages_dict, target_language, ratio=0.8):
    """
    判断 target_language 在仓库中的占比是否 >= ratio。
    target_language 与 GitHub 返回的 key 做大小写不敏感匹配。
    """
    if not languages_dict:
        return False
    total = sum(languages_dict.values())
    if total == 0:
        return False
    target_lower = target_language.strip().lower()
    for lang_name, bytes_count in languages_dict.items():
        if lang_name.strip().lower() == target_lower:
            return (bytes_count / total) >= ratio
    return False


def run_with_retry_on_error(fn, max_retries=3, pause_seconds=60):
    """执行 fn()，若抛错则暂停 pause_seconds 后重试，最多 max_retries 次。"""
    last_error = None
    for attempt in range(max_retries):
        try:
            return fn()
        except Exception as e:
            last_error = e
            if attempt < max_retries - 1:
                print(f"[API 报错] {e}，暂停 {pause_seconds} 秒后重试 ({attempt + 1}/{max_retries})")
                time.sleep(pause_seconds)
    raise last_error


def parse_args():
    p = argparse.ArgumentParser(description="按语言从 GitHub 批量拉取并格式化 commit")
    p.add_argument(
        "--language",
        default=DEFAULT_LANGUAGE,
        help=f"目标语言（默认: {DEFAULT_LANGUAGE}）",
    )
    p.add_argument(
        "--workers",
        type=int,
        default=DEFAULT_WORKERS,
        help=f"并发处理仓库数（默认: {DEFAULT_WORKERS}）",
    )
    return p.parse_args()


def main():
    args = parse_args()
    target_language = args.language.strip()
    workers = max(1, args.workers)

    token = (os.getenv("GITHUB_TOKEN") or os.getenv("GH_TOKEN") or "").strip()
    if not token:
        print("未配置 GITHUB_TOKEN 或 GH_TOKEN，退出", file=sys.stderr)
        sys.exit(1)

    excluded = load_excluded()
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    total_passed_commits = 0
    total_lock = threading.Lock()
    page = 1
    seen_full_names = set()

    print(f"目标语言: {target_language}, 排除: {len(excluded)} 个仓库")
    print(
        f"目标通过 commit 数: {TARGET_COMMIT_COUNT}, "
        f"star 范围: [{MIN_STARS_THRESHOLD}, {MAX_STARS_THRESHOLD}]"
    )
    print(f"输出目录: {OUTPUT_DIR}, workers: {workers}")

    def mark_seen_and_collect_candidates(items_batch):
        """在主线程中按搜索顺序登记 seen，并返回本页待并发处理的 repo_item 列表。"""
        out = []
        for repo_item in items_batch:
            owner = repo_item.get("owner", {}).get("login")
            repo = repo_item.get("name")
            stars = repo_item.get("stargazers_count", 0)
            full_name = f"{owner}/{repo}"
            if stars < MIN_STARS_THRESHOLD:
                return out, True, "low"
            if stars > MAX_STARS_THRESHOLD:
                continue
            if full_name in excluded or full_name in seen_full_names:
                continue
            seen_full_names.add(full_name)
            out.append(repo_item)
        return out, False, None

    while total_passed_commits < TARGET_COMMIT_COUNT:
        try:
            search_result = run_with_retry_on_error(
                lambda: search_repos_by_language(target_language, token, page),
                pause_seconds=PAUSE_ON_ERROR_SECONDS,
            )
        except Exception as e:
            print(f"搜索仓库失败: {e}")
            break

        items = search_result.get("items", [])
        if not items:
            print("当前语言下已无更多符合条件的仓库")
            break

        candidates, stopped_low_stars, _ = mark_seen_and_collect_candidates(items)
        if stopped_low_stars:
            print(f"剩余仓库 star 已低于 {MIN_STARS_THRESHOLD}，停止")
            break

        if not candidates:
            page += 1
            time.sleep(1)
            continue

        def worker_job(repo_item):
            owner = repo_item.get("owner", {}).get("login")
            repo = repo_item.get("name")
            stars = repo_item.get("stargazers_count", 0)
            full_name = f"{owner}/{repo}"

            if stars > MAX_STARS_THRESHOLD:
                return full_name, 0

            try:
                languages = run_with_retry_on_error(
                    lambda: get_repo_languages(owner, repo, token),
                    pause_seconds=PAUSE_ON_ERROR_SECONDS,
                )
            except Exception as e:
                print(f"获取语言失败 {full_name}: {e}，跳过")
                return full_name, 0

            if not language_ratio_at_least(languages, target_language, LANGUAGE_RATIO_THRESHOLD):
                return full_name, 0

            license_key = (repo_item.get("license") or {}).get("key")
            if license_key is None:
                try:
                    license_key = run_with_retry_on_error(
                        lambda: get_repo_license_key(owner, repo, token),
                        pause_seconds=PAUSE_ON_ERROR_SECONDS,
                    )
                except Exception:
                    license_key = None
                time.sleep(0.5)
            if license_key not in ALLOWED_LICENSES:
                print(f"license不符合要求: {full_name}")
                return full_name, 0

            print(f"处理 {full_name} (stars={stars}) ...")

            def do_curl_and_format():
                commits_data = curl_filtered_commits(
                    owner=owner,
                    repo=repo,
                    output_path=OUTPUT_DIR,
                    since_time=SINCE_TIME,
                    token=token,
                )
                n = len(commits_data.get("commits", []))
                if n > 0:
                    format_data(data=commits_data, output=OUTPUT_DIR, token=token)
                return n

            try:
                return full_name, run_with_retry_on_error(
                    do_curl_and_format,
                    pause_seconds=PAUSE_ON_ERROR_SECONDS,
                )
            except Exception as e:
                print(f"  处理 {full_name} 失败: {e}，跳过")
                return full_name, 0

        with ThreadPoolExecutor(max_workers=workers) as executor:
            futures = [executor.submit(worker_job, r) for r in candidates]
            for fut in as_completed(futures):
                try:
                    full_name, passed = fut.result()
                except Exception as e:
                    print(f"任务异常: {e}")
                    continue
                with total_lock:
                    total_passed_commits += passed
                    cur = total_passed_commits
                if passed:
                    print(f"  {full_name} 本仓库通过 commit 数: {passed}, 累计: {cur}")
                if cur >= TARGET_COMMIT_COUNT:
                    break

        if total_passed_commits >= TARGET_COMMIT_COUNT:
            break

        page += 1
        time.sleep(1)

    print(f"结束。总通过 commit 数: {total_passed_commits}")


if __name__ == "__main__":
    main()
