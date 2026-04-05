"""
从 result/test_result/<model>/<batch>/pass_rate.json 读取每条 model/golden 的 stdout，
输出：(1) 最终结果（reason）；(2) 对应 log_parsers 的分析结果。
不调用 test_run，仅复用 log_parsers 与常量。

运行方式（项目根目录）:
  PYTHONPATH=src python3 -m harness.parse_pass_rate -p result/test_result/<model>/<batch>/pass_rate.json -g <golden.json> -o <output.json>
或进入 src 后:
  python3 -m harness.parse_pass_rate -p ... -g ... -o ...
"""
import argparse
import inspect
import json
import re

from harness.log_parsers.python import MAP_REPO_TO_PARSER_PY
from harness.log_parsers.java import MAP_REPO_TO_PARSER_JAVA
from harness.log_parsers.go import MAP_REPO_TO_PARSER_GO
from harness.log_parsers.rust import MAP_REPO_TO_PARSER_RUST
from harness.log_parsers.c import MAP_REPO_TO_PARSER_C
from harness.log_parsers.cpp import MAP_REPO_TO_PARSER_CPP
from harness.log_parsers.typescript import MAP_REPO_TO_PARSER_TS

_OMNIGRIL_EXIT_RE = re.compile(r"OMNIGRIL_EXIT_CODE=(\d+)\s*$", re.MULTILINE)

# final_result 为以下情况时不跑 log_parser，仅在输出中说明
_SKIP_PARSER_REASONS = frozenset({
    "APPLY_FAILED",
    "TIMEOUT_APPLY",
    "TIMEOUT_EVAL",
})


def strip_omnigril_exit(text: str) -> str:
    """去掉 stdout 中的 OMNIGRIL_EXIT_CODE=... 行，供 parser 使用。"""
    return re.sub(_OMNIGRIL_EXIT_RE, "", text).strip("\n")


def get_log_parser(language: str, repo: str):
    """根据 language/repo 返回对应的 log parser 函数，无则返回 None。"""
    lang = (language or "").strip().lower()
    repo = (repo or "").strip()
    lang_to_repo_parser = {
        "python": MAP_REPO_TO_PARSER_PY,
        "java": MAP_REPO_TO_PARSER_JAVA,
        "go": MAP_REPO_TO_PARSER_GO,
        "rust": MAP_REPO_TO_PARSER_RUST,
        "c": MAP_REPO_TO_PARSER_C,
        "cpp": MAP_REPO_TO_PARSER_CPP,
        "c++": MAP_REPO_TO_PARSER_CPP,
        "typescript": MAP_REPO_TO_PARSER_TS,
    }
    repo_map = lang_to_repo_parser.get(lang)
    if not repo_map:
        return None
    return repo_map.get(repo)


def run_parser_on_log(stdout: str, stderr: str, language: str, repo: str) -> dict | None:
    """
    对已去掉 OMNIGRIL_EXIT 的 stdout 跑对应 log_parser（仅用 stdout，不用 stderr）。
    返回 parser 的 test_status_map，异常或无 parser 时返回 None。
    部分 parser 只接受 (log)，部分接受 (log, test_spec)，按签名调用。
    """
    cleaned = strip_omnigril_exit(stdout)
    parser = get_log_parser(language, repo)
    if parser is None:
        print(f'{repo}: parse is None')
        return None
    nparams = len(inspect.signature(parser).parameters)
    if nparams == 1:
        result = parser(cleaned)
    else:
        result = parser(cleaned, {})
    print('[Parse Log End]\n')
    return result


def _filter_parser_result_both_passed(
    model_parser: dict, golden_parser: dict
) -> tuple[dict, dict]:
    """
    若某具体测试在 model 与 golden 均为 PASSED，则从输出中省略该测试。
    返回 (filtered_model_parser, filtered_golden_parser)。
    """
    if not isinstance(model_parser, dict) or not isinstance(golden_parser, dict):
        return model_parser, golden_parser
    all_tests = set(model_parser.keys()) | set(golden_parser.keys())
    keep = {
        t
        for t in all_tests
        if not (
            model_parser.get(t) == "PASSED" and golden_parser.get(t) == "PASSED"
        )
    }
    m_out = {t: model_parser[t] for t in keep if t in model_parser}
    g_out = {t: golden_parser[t] for t in keep if t in golden_parser}
    return m_out, g_out


def _extract_side_info(entry: dict, key_new: str, key_old: str) -> dict:
    """
    兼容两种 pass_rate 格式：
    - 新格式 (test_run.py): model/golden 含 final_result, raw_reason, stdout, stderr
    - 旧格式 (stat_pass.py): model_info/golden_info 含 passed, reason, stdout, stderr
    返回统一的 { reason, stdout, stderr, passed } 字典。
    """
    new = entry.get(key_new)
    old = entry.get(key_old)
    if isinstance(old, dict) and old:
        return {
            "reason": old.get("reason", ""),
            "stdout": old.get("stdout", "") or "",
            "stderr": old.get("stderr", "") or "",
            "passed": old.get("passed", False),
        }
    if isinstance(new, dict) and new:
        raw_reason = (new.get("raw_reason") or "").strip()
        reason = raw_reason.upper().replace(" ", "_") if raw_reason else ""
        return {
            "reason": reason,
            "stdout": new.get("stdout", "") or "",
            "stderr": new.get("stderr", "") or "",
            "passed": new.get("final_result") == "success",
        }
    return {"reason": "", "stdout": "", "stderr": "", "passed": False}


def process_one_entry(entry: dict, lang_map: dict, repo_map: dict) -> dict:
    """
    处理一条 pass_rate 记录，始终返回一条输出（不因「均 pass」而跳过）。
    - model 或 golden 任一侧为 APPLY_FAILED / TIMEOUT_* 时，两侧均不跑 log_parser，输出中说明。
    - 具体测试若 model 与 golden 均为 PASSED，则从 parser_result 中省略。
    """
    instance_id = entry.get("instance_id", "")
    model_info = _extract_side_info(entry, "model", "model_info")
    golden_info = _extract_side_info(entry, "golden", "golden_info")

    lang = lang_map.get(instance_id, "")
    repo = repo_map.get(instance_id, "")

    # 任一侧为 apply error 或 timeout 时，model 和 golden 都不跑 log_parser
    skip_parser_both = (
        model_info.get("reason") in _SKIP_PARSER_REASONS
        or golden_info.get("reason") in _SKIP_PARSER_REASONS
    )

    def side_result(info: dict, skip_parser: bool) -> dict:
        reason = info.get("reason", "")
        reason_lower = reason.lower().replace(" ", "_") if reason else ""
        stdout = info.get("stdout", "") or ""
        stderr = info.get("stderr", "") or ""
        cleaned = strip_omnigril_exit(stdout)
        if skip_parser:
            return {
                "final_result": reason_lower,
                "parser_result": "skipped_apply_or_timeout",
                "parser_status": "skipped",
                "note": "因 model 或 golden 存在 APPLY_FAILED/超时，未执行 log_parser",
            }
        parser_out = run_parser_on_log(stdout, stderr, lang, repo)
        if repo == 'alibaba/nacos':
            print(parser_out)
        if parser_out is None:
            parser_result = "no_parser" if get_log_parser(lang, repo) is None else "parser_exception"
            parser_status = "no_parser" if parser_result == "no_parser" else "parser_exception"
        else:
            parser_result = parser_out
            parser_status = "ok"
        out = {"final_result": reason_lower, "parser_result": parser_result, "parser_status": parser_status}
        if not cleaned.strip():
            out["note"] = "去除了 OMNIGRIL_EXIT 行后 stdout 为空，未跑 log_parser"
            out["parser_status"] = "stdout_empty"
        elif isinstance(parser_result, dict) and not parser_result:
            out["note"] = "已执行 log_parser，但日志中未解析出具体测试（可能失败过早或格式不符）"
        return out

    model_out = side_result(model_info, skip_parser_both)
    golden_out = side_result(golden_info, skip_parser_both)
    # # 具体测试两方都 PASSED 的不输出
    m_pr, g_pr = model_out["parser_result"], golden_out["parser_result"]
    m_pr_f, g_pr_f = _filter_parser_result_both_passed(
        m_pr if isinstance(m_pr, dict) else {},
        g_pr if isinstance(g_pr, dict) else {},
    )
    model_out["parser_result"] = m_pr_f if isinstance(m_pr, dict) else m_pr
    golden_out["parser_result"] = g_pr_f if isinstance(g_pr, dict) else g_pr
    passed = (
        model_out.get("final_result") == "success"
        and golden_out.get("final_result") == "success"
    )
    row = {
        "instance_id": instance_id,
        "language": lang,
        "passed": passed,
        "model": model_out,
        "golden": golden_out,
    }
    # 任一侧为程序/parser 报错时在条目标注
    m_err = model_out.get("parser_status") not in ("ok",)
    g_err = golden_out.get("parser_status") not in ("ok",)
    if m_err or g_err:
        row["parser_error"] = True
        row["parser_error_note"] = "本条目存在 parser 未正常执行（no_parser/parser_exception/skipped/stdout_empty），非「都 pass」"
    return row


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


def parse_pass_rate(pass_rate_path: str, golden_path: str | None, output_path: str) -> None:
    """
    读取 pass_rate.json，对每条跑 log_parsers 并写入 output_path。
    APPLY_FAILED/TIMEOUT 不跑 parser 仅说明；具体测试两方都 PASSED 的从 parser_result 中省略。
    """
    with open(pass_rate_path, "r", encoding="utf-8") as f:
        pass_rate_list = json.load(f)
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

    out_list = [process_one_entry(entry, lang_map, repo_map) for entry in pass_rate_list]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(out_list, f, indent=2, ensure_ascii=False)

    print(f"已写入 {len(out_list)} 条 -> {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="解析 pass_rate.json 中每条 stdout，输出最终结果与 log_parsers 分析"
    )
    parser.add_argument(
        "--pass-rate", "-p",
        required=True,
        help="pass_rate.json 路径，如 result/test_result/modelx/batchn/pass_rate.json",
    )
    parser.add_argument(
        "--golden", "-g",
        default=None,
        help="golden JSON 路径，用于按 instance_id 取 language/repo（可选但推荐）",
    )
    parser.add_argument(
        "--output", "-o",
        required=True,
        help="输出 JSON 路径",
    )
    args = parser.parse_args()
    parse_pass_rate(args.pass_rate, args.golden, args.output)


if __name__ == "__main__":
    main()
