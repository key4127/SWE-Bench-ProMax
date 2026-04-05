#!/usr/bin/env python3
"""
遍历 data_for_agent/swe-format/batchn/batchn.json，用每条记录的 base_commit 匹配
scale/docker/batchn/result/detail.json 中的 commit。
base_commit 与 src/pipeline/collection/format_data.py 一致：即 commit 的 parents[0].sha，
即「该 commit 的父 commit」。detail 中每条 commit 有 parents，用 (owner, repo, parents[0].sha)
建索引，swe 的 base_commit 与之对应即可找到唯一的 detail 条。
合并结果写入 result/final_stat_result/batchn/raw.json，每条包含 swe-format 全部字段、
detail 的 html_url，以及由 files 统计的 loc、num_files、num_non_test、num_test。
"""

import argparse
import json
import os
import sys
from collections import defaultdict
from typing import Optional

# 项目根目录（脚本在 src/result/ 下）
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = os.path.normpath(os.path.join(_SCRIPT_DIR, "..", ".."))
if _PROJECT_ROOT not in sys.path:
    sys.path.insert(0, _PROJECT_ROOT)


def parse_repo(repo_slash: str):
    """swe 中 repo 格式为 'owner/repo'，拆成 (owner, repo)。"""
    if not repo_slash or "/" not in repo_slash:
        return None, None
    parts = repo_slash.strip().split("/", 1)
    return parts[0].strip(), parts[1].strip() if len(parts) > 1 else None


def load_swe_format(project_root: str, batch_name: str) -> list:
    path = os.path.join(project_root, "data_for_agent", "swe-format", batch_name, f"{batch_name}.json")
    if not os.path.isfile(path):
        raise FileNotFoundError(f"swe-format 文件不存在: {path}")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, list) else [data]


def load_detail(project_root: str, batch_name: str) -> list:
    path = os.path.join(project_root, "scale", "docker", batch_name, "result", "detail.json")
    if not os.path.isfile(path):
        raise FileNotFoundError(f"detail 文件不存在: {path}")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    raw = data if isinstance(data, list) else [data]
    return _flatten_detail(raw)


def _flatten_detail(detail_list: list) -> list:
    """
    将 detail 统一展平为「每条一条 commit」的列表。
    - 若项含顶层 sha/owner/repo：视为已是 commit 级，原样保留。
    - 若项含 commits 数组：按 repo 展开，每条 commit 变成一条，带上 owner/repo/sha/html_url/files。
    """
    out = []
    for item in detail_list:
        if not isinstance(item, dict):
            continue
        if "sha" in item and "owner" in item and "repo" in item:
            out.append(item)
            continue
        if "commits" not in item:
            continue
        owner = item.get("owner")
        repo = item.get("repo")
        if not owner or not repo:
            continue
        for c in item.get("commits") or []:
            if not isinstance(c, dict) or not c.get("sha"):
                continue
            out.append({
                "owner": owner,
                "repo": repo,
                "sha": c.get("sha"),
                "html_url": c.get("html_url"),
                "files": c.get("files") or [],
                "parents": c.get("parents") or [],
            })
    return out


# 各语言扩展名集合
_C_STYLE_EXTS = {
    # C 族
    ".c", ".h", ".cpp", ".cc", ".cxx", ".hpp", ".hh", ".hxx", ".m", ".mm",
    # Go
    ".go",
    # Java / JVM
    ".java", ".kt", ".kts", ".scala", ".groovy",
    # JavaScript / TypeScript
    ".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx", ".mts",
    # Rust
    ".rs",
    # C# / Swift
    ".cs", ".swift",
    # PHP
    ".php",
}
_PYTHON_EXTS = {".py", ".pyx", ".pyi", ".pxd"}
_HASH_ONLY_EXTS = {
    ".sh", ".bash", ".zsh", ".fish",
    ".rb", ".pl", ".r", ".jl",
    ".yaml", ".yml", ".toml", ".ini", ".cfg",
}
# 文档类扩展名/路径：此类文件不计入 loc 与修改文件数
_DOC_EXTS = {
    ".md", ".markdown", ".rst", ".txt",
    ".adoc", ".asciidoc", ".tex", ".texi", ".org",
    ".htm", ".html",
}


def _is_doc_file(filename: str) -> bool:
    """若文件为文档（按扩展名），返回 True，不计入 loc/文件数。"""
    if not (filename or filename.strip()):
        return False
    ext = os.path.splitext(filename.strip().lower())[1]
    return ext in _DOC_EXTS


def _count_file_non_comment_loc(patch: str, filename: str) -> tuple:
    """
    解析单个文件的 patch，返回 (non_comment_loc, only_comments)。
    追踪多行注释状态（/* ... */ 和 Python 三引号），确保多行注释内的所有行都被正确识别。
    - non_comment_loc: 非注释的增删行数
    - only_comments: 所有变更行均为注释（或无变更）时为 True
    """
    if not patch:
        return 0, True

    ext = os.path.splitext(filename)[1].lower() if filename else ""
    use_c_style = ext in _C_STYLE_EXTS
    use_python = ext in _PYTHON_EXTS
    use_hash = use_python or ext in _HASH_ONLY_EXTS

    in_block = False   # 当前是否在 /* ... */ 块注释内
    triple = None      # 当前是否在 Python 三引号内，值为引号字符 '"' 或 "'"

    non_comment = 0
    has_any = False

    for raw in patch.splitlines():
        # 跳过 diff 元数据行
        if raw.startswith(("+++", "---", "@@", "\\")):
            continue

        is_change = raw[:1] in ("+", "-")
        content = raw[1:] if raw[:1] in ("+", "-", " ") else raw
        stripped = content.strip()

        # ---- 判断本行是否为注释（基于行首状态）----
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

        # ---- 更新 /* ... */ 多行注释状态 ----
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
                    # // 出现在 /* 之前：本行后续为行注释，不会开启块注释
                    if 0 <= sl < bl:
                        break
                    in_block = True
                    j = content.find("*/", bl + 2)
                    if j < 0:
                        break
                    in_block = False
                    i = j + 2

        # ---- 更新 Python 三引号状态 ----
        if use_python:
            if triple is None:
                for q in ('"""', "'''"):
                    idx = content.find(q)
                    if idx >= 0:
                        # 同一行内关闭则不改变状态
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


def stats_from_files(files: list) -> dict:
    """
    根据 files 列表计算统计量，不保留 files 内容。
    文件数按不重复的 filename 计；loc 仅统计非注释的增删行数。
    若某文件仅修改了注释，则该文件不计入 num_files。
    返回: loc, num_files, num_non_test, num_test
    """
    if not files:
        return {"loc": 0, "num_files": 0, "num_non_test": 0, "num_test": 0}
    loc = 0
    seen = set()
    num_test = 0
    num_non_test = 0
    for f in files:
        name = (f.get("filename") or "").strip()
        patch = f.get("patch")
        if patch is not None:
            file_loc, only_comments = _count_file_non_comment_loc(patch, name)
        else:
            # 无 patch 时回退到 API 提供的 additions/deletions，不做注释过滤
            file_loc = f.get("additions", 0) + f.get("deletions", 0)
            only_comments = False
        # 仅修改注释的文件不计入文件数；文档文件不计入
        if only_comments or not name or name in seen:
            continue
        if _is_doc_file(name):
            continue
        seen.add(name)
        if "test" in name.lower():
            num_test += 1
        else:
            # loc 只统计非测试文件
            loc += file_loc
            num_non_test += 1
    return {
        "loc": loc,
        "num_files": len(seen),
        "num_non_test": num_non_test,
        "num_test": num_test,
    }


def stats_from_patch(patch_str: str) -> dict:
    """
    解析合并 patch 字符串，返回 loc（非注释非测试非文档）和 num_non_test。
    与 stats_from_files 规则一致：文档按扩展名排除。
    """
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


def build_detail_index_by_base_commit(detail_list: list) -> dict:
    """
    按 base_commit（即 commit 的 parents[0].sha）建索引，与 format_data 中 base_commit 含义一致。
    返回 (owner, repo, base_commit[:7]) -> [detail_item, ...]（该 base 对应的 commit 条，按 detail 顺序）
    """
    index = defaultdict(list)
    for item in detail_list:
        owner = item.get("owner")
        repo = item.get("repo")
        parents = item.get("parents")
        if not owner or not repo or not parents or not isinstance(parents, list):
            continue
        first_parent = parents[0]
        if not isinstance(first_parent, dict):
            continue
        parent_sha = first_parent.get("sha")
        if not parent_sha:
            continue
        key = (owner, repo, parent_sha[:7])
        index[key].append({"html_url": item.get("html_url"), "files": item.get("files") or []})
    return index


def merge_batch(project_root: str, batch_name: str, token: Optional[str] = None) -> list:  # noqa: ARG001
    """
    以 swe-format 为驱动，用 base_commit 匹配 detail。
    swe 每条有 base_commit 和 repo（格式 owner/repo）；detail 每条 commit 有 parents[0].sha。
    用 (owner, repo, base_commit[:7]) 在「按 parents[0].sha 建的索引」中查找，得到对应 detail。
    输出顺序与 swe_list 一致。token 保留参数兼容，不再使用。
    """
    swe_list = load_swe_format(project_root, batch_name)
    detail_list = load_detail(project_root, batch_name)
    detail_index = build_detail_index_by_base_commit(detail_list)

    default_stats = {"loc": 0, "num_files": 0, "num_non_test": 0, "num_test": 0}
    merged = [None] * len(swe_list)

    for idx, swe_item in enumerate(swe_list):
        base_commit = swe_item.get("base_commit")
        repo_slash = swe_item.get("repo")
        owner, repo = parse_repo(repo_slash if isinstance(repo_slash, str) else "")
        if not base_commit or not owner or not repo:
            merged[idx] = {**swe_item, "html_url": None, **default_stats}
            continue
        key = (owner, repo, base_commit[:7])
        queue = detail_index.get(key)
        if not queue:
            merged[idx] = {**swe_item, "html_url": None, **default_stats}
            continue
        detail_part = queue.pop(0)
        if not queue:
            del detail_index[key]
        file_stats = stats_from_files(detail_part["files"])
        merged[idx] = {
            **swe_item,
            "html_url": detail_part["html_url"],
            **file_stats,
        }

    for idx in range(len(merged)):
        if merged[idx] is None:
            merged[idx] = {**swe_list[idx], "html_url": None, **default_stats}
    return merged


def main():
    parser = argparse.ArgumentParser(
        description="按 base_commit 合并 swe-format 与 detail，输出到 result/final_stat_result/batchn/raw.json"
    )
    parser.add_argument(
        "batch_name",
        help="批次名，如 batch1、batch2",
    )
    args = parser.parse_args()

    merged = merge_batch(_PROJECT_ROOT, args.batch_name)
    out_dir = os.path.join(_PROJECT_ROOT, "result", "final_stat_result", args.batch_name)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "raw.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
    print(f"已写入 {len(merged)} 条到 {out_path}")


if __name__ == "__main__":
    main()
