#!/usr/bin/env python3
"""
读取 pass_rate.json（格式参考 result/harness_result/strengthen/v2/glm.json），
按语言筛选实例，对每条记录的 model/golden 的 stdout 重新应用 harness 的 log_parser，
并覆盖写回原文件或指定输出文件。

用法（项目根目录，PYTHONPATH=src）:
  # 只处理语言为 c 的实例，覆盖写回原文件（需提供 -g 以解析 repo，否则无 log_parser 的条目会被跳过）
  python3 -m filters.final.reapply_log_parser -p result/harness_result/strengthen/v2/glm.json -l c -g result/strengthen/v2/all_nl_enhanced.json
  python3 -m filters.final.reapply_log_parser -p path/to/pass_rate.json -l cpp -g path/to/golden.json
  # 输出到新文件
  python3 -m filters.final.reapply_log_parser -p path/to/pass_rate.json -l c -g result/strengthen/v2/all_nl_enhanced.json -o path/to/out.json
"""

import argparse
import json
import sys
from pathlib import Path

# 仅复用 harness 的 process_instance，不修改 harness
from harness.log_parse import get_log_parser, process_instance

_LANG_ALIASES = {"c++": "cpp", "cplusplus": "cpp"}


def _normalize_lang(lang: str) -> str:
    """将 'c++' 等别名统一为 'cpp'，便于比较。"""
    return _LANG_ALIASES.get(lang, lang)


def load_lang_repo_maps(golden_path: Path | None, pass_rate_list: list) -> tuple[dict[str, str], dict[str, str]]:
    """从 golden 或 pass_rate 列表构建 instance_id -> language / repo。"""
    lang_map: dict[str, str] = {}
    repo_map: dict[str, str] = {}
    if golden_path and golden_path.exists():
        with open(golden_path, "r", encoding="utf-8") as f:
            golden = json.load(f)
        if isinstance(golden, list):
            for it in golden:
                iid = it.get("instance_id")
                if iid is not None:
                    lang_map[iid] = (it.get("language") or "").strip()
                    repo_map[iid] = (it.get("repo") or "").strip()
        elif isinstance(golden, dict):
            for iid, it in golden.items():
                if isinstance(it, dict):
                    lang_map[iid] = (it.get("language") or "").strip()
                    repo_map[iid] = (it.get("repo") or "").strip()
    # 再从 pass_rate 补全/覆盖：每条可能有 language，部分有 repo
    for entry in pass_rate_list:
        iid = entry.get("instance_id")
        if iid is None:
            continue
        if entry.get("language") is not None:
            lang_map[iid] = (entry.get("language") or "").strip()
        if entry.get("repo") is not None:
            repo_map[iid] = (entry.get("repo") or "").strip()
    return lang_map, repo_map


def side_to_reason_entry(side: dict) -> dict:
    """将 pass_rate 中的 model/golden 转为 process_instance 需要的 { reason, stdout, stderr }。"""
    return {
        "reason": side.get("raw_reason") or side.get("final_result") or side.get("reason") or "",
        "stdout": side.get("stdout") or "",
        "stderr": side.get("stderr") or "",
    }


def reapply_one_entry(
    entry: dict,
    lang_map: dict[str, str],
    repo_map: dict[str, str],
) -> bool:
    """
    对一条记录重新跑 log_parser，更新 entry["model"]、entry["golden"]、entry["passed"]。
    返回是否进行了更新（有 parser 且未异常）。
    """
    instance_id = entry.get("instance_id", "")
    lang = lang_map.get(instance_id) or entry.get("language") or ""
    repo = repo_map.get(instance_id) or entry.get("repo") or ""
    lang = (lang or "").strip()
    repo = (repo or "").strip()

    if get_log_parser(lang, repo) is None:
        return False

    model_side = entry.get("model") or entry.get("model_info") or {}
    golden_side = entry.get("golden") or entry.get("golden_info") or {}

    def run_and_update(side: dict) -> dict:
        inp = side_to_reason_entry(side)
        try:
            return process_instance(inp, lang, repo)
        except Exception:
            return {
                "final_result": side.get("final_result", "parser_exception"),
                "raw_reason": side.get("raw_reason", ""),
                "parse_reason": "parser_exception",
                "stdout": side.get("stdout", ""),
                "stderr": side.get("stderr", ""),
            }

    entry["model"] = run_and_update(model_side)
    entry["golden"] = run_and_update(golden_side)
    entry["passed"] = (
        entry["model"].get("final_result") == "success"
        and entry["golden"].get("final_result") == "success"
    )
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="对 pass_rate.json 中指定语言的实例重新应用 log_parser 并写回"
    )
    parser.add_argument(
        "--pass-rate",
        "-p",
        required=True,
        help="pass_rate.json 路径（如 result/harness_result/strengthen/v2/glm.json）",
    )
    parser.add_argument(
        "--language",
        "-l",
        required=True,
        help="只处理该语言的实例（如 c, cpp, python）",
    )
    parser.add_argument(
        "--golden",
        "-g",
        default=None,
        help="golden JSON 路径，用于按 instance_id 取 language/repo（可选）",
    )
    parser.add_argument(
        "--output",
        "-o",
        default=None,
        help="输出 JSON 路径；不指定则覆盖更新原 pass_rate 文件",
    )
    args = parser.parse_args()

    pass_rate_path = Path(args.pass_rate)
    if not pass_rate_path.exists():
        print(f"Error: pass_rate 文件不存在: {pass_rate_path}", file=sys.stderr)
        sys.exit(1)

    with open(pass_rate_path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, list):
        print("Error: pass_rate.json 应为 list 格式", file=sys.stderr)
        sys.exit(1)

    lang_filter = _normalize_lang((args.language or "").strip().lower())
    golden_path = Path(args.golden) if args.golden else None
    lang_map, repo_map = load_lang_repo_maps(golden_path, data)

    updated = 0
    skipped_no_parser = 0
    for entry in data:
        iid = entry.get("instance_id", "")
        entry_lang = _normalize_lang((entry.get("language") or lang_map.get(iid, "")).strip().lower())
        if entry_lang != lang_filter:
            continue
        if get_log_parser(lang_map.get(iid) or entry_lang, repo_map.get(iid) or entry.get("repo") or "") is None:
            skipped_no_parser += 1
            continue
        if reapply_one_entry(entry, lang_map, repo_map):
            updated += 1

    if skipped_no_parser:
        print(f"跳过 {skipped_no_parser} 条（无对应 log_parser）。", file=sys.stderr)
    print(f"已用 log_parser 更新 {updated} 条（语言={args.language}）。", file=sys.stderr)

    out_path = Path(args.output) if args.output else pass_rate_path
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"已写入 {len(data)} 条 -> {out_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
