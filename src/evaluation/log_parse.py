import argparse
import json
import os
import re

from harness.log_parsers.python import MAP_REPO_TO_PARSER_PY
from harness.log_parsers.java import MAP_REPO_TO_PARSER_JAVA
from harness.log_parsers.go import MAP_REPO_TO_PARSER_GO
from harness.log_parsers.rust import MAP_REPO_TO_PARSER_RUST
from harness.log_parsers.c import MAP_REPO_TO_PARSER_C
from harness.log_parsers.cpp import MAP_REPO_TO_PARSER_CPP
from harness.log_parsers.typescript import MAP_REPO_TO_PARSER_TS


_LANG_TO_REPO_PARSER = {
    "python": MAP_REPO_TO_PARSER_PY,
    "java": MAP_REPO_TO_PARSER_JAVA,
    "go": MAP_REPO_TO_PARSER_GO,
    "rust": MAP_REPO_TO_PARSER_RUST,
    "c": MAP_REPO_TO_PARSER_C,
    "cpp": MAP_REPO_TO_PARSER_CPP,
    "c++": MAP_REPO_TO_PARSER_CPP,
    "typescript": MAP_REPO_TO_PARSER_TS
}


def get_log_parser(language: str, repo: str):
    """Return the log parser for (language, repo), or None if none registered."""
    lang = (language or "").strip().lower()
    repo = (repo or "").strip()
    if not repo:
        return None
    repo_map = _LANG_TO_REPO_PARSER.get(lang)
    if not repo_map:
        return None
    return repo_map.get(repo)


def process_instance(entry: dict, language, repo) -> dict:
    reason = entry.get("reason", "")
    stdout = entry.get("stdout", "")
    stderr = entry.get("stderr", "")

    _OMNIGRIL_EXIT_RE = re.compile(r"OMNIGRIL_EXIT_CODE=(\d+)\s*$", re.MULTILINE)
    cleaned_stdout = re.sub(_OMNIGRIL_EXIT_RE, "", stdout).strip("\n")

    omnigril_match = _OMNIGRIL_EXIT_RE.search(stdout)

    if reason == 'TIMEOUT_EVAL' or reason == 'APPLY_FAILED' or reason == 'TIMEOUT_APPLY':
        final_result = reason.lower()
        parse_reason = 'not run'
    elif omnigril_match and int(omnigril_match.group(1)) != 0:
        final_result = 'non zero exit'
        parse_reason = 'not run'
    else:
        parser = get_log_parser(language, repo)
        parse_result = parser(cleaned_stdout, {})
        if parse_result is None:
            final_result = 'parse error'
            parse_reason = 'parse error'
        else:
            final_result = 'success'
            parse_reason = 'success'
            for test_entry in parse_result.items():
                result = test_entry[1]
                if result == 'FAILED' or result == 'ERROR':
                    final_result = 'test fail'
                    parse_reason = 'fail'
                    break


    return {
        'final_result': final_result,
        'raw_reason': reason.lower(),
        'parse_reason': parse_reason,
        'stdout': stdout,
        'stderr': stderr
    }


def process_one_entry(entry: dict, lang_map: dict, repo_map: dict) -> dict:
    """
    处理一条 pass_rate 记录，始终返回一条输出（不因「均 pass」而跳过）。
    - model 或 golden 任一侧为 APPLY_FAILED / TIMEOUT_* 时，两侧均不跑 log_parser，输出中说明。
    - 具体测试若 model 与 golden 均为 PASSED，则从 parser_result 中省略。
    """
    instance_id = entry.get("instance_id", "")
    model_info = entry.get("model_info") or {}
    golden_info = entry.get("golden_info") or {}

    lang = lang_map.get(instance_id, "")
    repo = repo_map.get(instance_id, "")

    model_result = process_instance(model_info, lang, repo)
    golden_result = process_instance(golden_info, lang, repo)

    result = {
        'instance_id': instance_id,
        'language': lang,
        'passed': model_result.get('final_result') == 'success' \
              and golden_result.get('final_result') == 'success',
        'model': model_result,
        'golden': golden_result
    }
    
    return result


def build_lang_repo_maps(golden_list: list) -> tuple[dict, dict]:
    """从 golden 列表构建 instance_id -> language / repo。"""
    lang_map = {}
    repo_map = {}
    for it in golden_list:
        iid = it.get("instance_id")
        if iid is None:
            continue
        lang_map[iid] = (it.get("language") or "").strip()
        repo_map[iid] = (it.get("repo") or "").strip()
    return lang_map, repo_map


def print_pass_rate_summary(results_list, lang_map):
    total = sum(1 for r in results_list if r['golden']['final_result'] == 'success')
    passed = sum(1 for r in results_list if r["passed"])
    print(f"\n{'='*60}")
    print(f"  Overall: {passed}/{total} passed ({100*passed/total:.1f}%)")
    print(f"{'='*60}")

    # Per-language stats
    lang_stats = {}
    for r in results_list:
        lang = lang_map.get(r["instance_id"], "unknown")
        stats = lang_stats.setdefault(lang, {"total": 0, "passed": 0})
        if r['golden']['final_result'] == 'success':
            stats["total"] += 1
            if r["passed"]:
                stats["passed"] += 1

    print(f"  {'Language':<15} {'Passed':>8} {'Total':>8} {'Rate':>8}")
    print(f"  {'-'*15} {'-'*8} {'-'*8} {'-'*8}")
    for lang in sorted(lang_stats, key=lambda l: -lang_stats[l]["total"]):
        s = lang_stats[lang]
        rate = 100 * s["passed"] / s["total"] if s['total'] else 0
        print(f"  {lang:<15} {s['passed']:>8} {s['total']:>8} {rate:>7.1f}%")

    # Failure reason breakdown
    reason_counts = {}
    for r in results_list:
        reason = r["model"]["final_result"]
        reason_counts[reason] = reason_counts.get(reason, 0) + 1

    print(f"\n  Results:")
    for reason, count in sorted(reason_counts.items(), key=lambda x: -x[1]):
        print(f"    {reason:<25} {count:>4} ({100*count/total:.1f}%)")
    print(f"{'='*60}")


def _process_pass_rate_list(pass_rate_list, golden_path, output_path):
    """统一处理 pass_rate 列表并写入 output_path。"""
    if not isinstance(pass_rate_list, list):
        pass_rate_list = [pass_rate_list]

    lang_map = {}
    repo_map = {}
    if golden_path:
        with open(golden_path, "r", encoding="utf-8") as f:
            golden_list = json.load(f)
        if isinstance(golden_list, list):
            lang_map, repo_map = build_lang_repo_maps(golden_list)
        elif isinstance(golden_list, dict):
            for iid, it in golden_list.items():
                if isinstance(it, dict):
                    lang_map[iid] = (it.get("language") or "").strip()
                    repo_map[iid] = (it.get("repo") or "").strip()

    # 只处理 golden 里存在且存在对应 parser 的条目，其余跳过且不写入
    out_list = []
    skipped = 0
    for entry in pass_rate_list:
        instance_id = entry.get("instance_id", "")
        lang = lang_map.get(instance_id, "")
        repo = repo_map.get(instance_id, "")
        if get_log_parser(lang, repo) is None:
            skipped += 1
            continue
        out_list.append(process_one_entry(entry, lang_map, repo_map))

    if skipped:
        print(f"已跳过 {skipped} 条（不在 golden 或无对应 parser）")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(out_list, f, indent=2, ensure_ascii=False)

    print(f"已写入 {len(out_list)} 条 -> {output_path}")
    print_pass_rate_summary(out_list, lang_map)


def parse_logs(pass_rate_path, golden_path, output_path):
    """从单个文件加载 pass_rate 并处理。"""
    with open(pass_rate_path, "r", encoding="utf-8") as f:
        pass_rate_list = json.load(f)
    _process_pass_rate_list(pass_rate_list, golden_path, output_path)


def main():
    parser = argparse.ArgumentParser(description='Evaluate model patches against golden patches and report pass rate')
    parser.add_argument('--pred', '-p', default='./preds.json', help='Predictions JSON 文件或文件夹路径；为文件夹时遍历其中所有 .json 文件 (default: ./preds.json)')
    parser.add_argument('--golden', '-g', default='./golden.json', help='Golden patches JSON path (default: ./golden.json)')
    parser.add_argument('--output', '-o', default='./pass_rate.json', help='Output results JSON path (default: ./pass_rate.json)')
    args = parser.parse_args()

    pred_path = args.pred
    golden_path = args.golden
    output_path = args.output

    if os.path.isfile(pred_path):
        parse_logs(pred_path, golden_path, output_path)
    elif os.path.isdir(pred_path):
        json_files = sorted(
            f for f in os.listdir(pred_path)
            if f.endswith('.json') and os.path.isfile(os.path.join(pred_path, f))
        )
        if not json_files:
            print(f"文件夹内无 .json 文件: {pred_path}")
            return
        pass_rate_list = []
        for name in json_files:
            inp = os.path.join(pred_path, name)
            with open(inp, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, list):
                pass_rate_list.extend(data)
            else:
                pass_rate_list.append(data)
        _process_pass_rate_list(pass_rate_list, golden_path, output_path)
    else:
        raise FileNotFoundError(f"-p 路径不存在或不可用: {pred_path}")


if __name__ == '__main__':
    main()