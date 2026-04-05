import os
import json
import uuid
import tempfile
import subprocess
import re
import argparse
from concurrent.futures import ThreadPoolExecutor

from harness.constants import TestStatus
from harness.log_parsers.python import MAP_REPO_TO_PARSER_PY
from harness.log_parsers.java import MAP_REPO_TO_PARSER_JAVA
from harness.log_parsers.go import MAP_REPO_TO_PARSER_GO
from harness.log_parsers.rust import MAP_REPO_TO_PARSER_RUST
from harness.log_parsers.c import MAP_REPO_TO_PARSER_C
from harness.log_parsers.cpp import MAP_REPO_TO_PARSER_CPP
from harness.log_parsers.typescript import MAP_REPO_TO_PARSER_TS

def create_temp_file(content, suffix="", prefix="tmp"):
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', suffix=suffix, prefix=prefix, delete=False) as f:
        f.write(content)
        return f.name

def run_command(cmd, check=False, timeout=600):
    print(f"execute: {cmd}")
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        if check and result.returncode != 0:
            print(f"Command failed with retcode {result.returncode}")
        return result, False
    except subprocess.TimeoutExpired:
        print(f"CRITICAL ERROR: Command timed out after {timeout}s")
        return subprocess.CompletedProcess(cmd, 1, stdout="TIMEOUT", stderr=f"TIMEOUT AFTER {timeout}s"), True

_OMNIGRIL_EXIT_RE = re.compile(r"OMNIGRIL_EXIT_CODE=(\d+)\s*$", re.MULTILINE)


def _strip_omnigril_exit(text: str) -> str:
    """Remove OMNIGRIL_EXIT_CODE=... line from text (so parsers see clean log)."""
    return re.sub(_OMNIGRIL_EXIT_RE, "", text).strip("\n")

# Language key -> (repo -> parser) mapping
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


# 与 log_parse.py 输出对齐：reason -> (final_result, parse_reason)
_REASON_TO_FINAL_RESULT = {
    "SUCCESS": ("success", "success"),
    "APPLY_FAILED": ("apply_failed", "not run"),
    "TIMEOUT_APPLY": ("timeout_apply", "not run"),
    "TIMEOUT_EVAL": ("timeout_eval", "not run"),
    "NON_ZERO_EXIT": ("non zero exit", "not run"),
    "LOG_CONTAINS_FAILURE": ("test fail", "fail"),
    "NETWORK_ERROR": ("network_error", "not run"),
    "NO_PASS_SIGNAL": ("test fail", "fail"),
    "NEED_HUMAN_REVIEW": ("need_human_review", "fail"),
}


def _to_log_parse_style_info(info: dict, reason_fallback: str) -> dict:
    """将 test_run 的 model_info/golden_info 转为 log_parse 输出的 model/golden 结构。"""
    reason = info.get("reason") if isinstance(info.get("reason"), str) else reason_fallback
    final_result, parse_reason = _REASON_TO_FINAL_RESULT.get(
        reason, (reason.lower().replace(" ", "_") if reason else "not run", "not run")
    )
    raw_reason = reason.lower().replace(" ", "_") if reason else "not run"
    return {
        "final_result": final_result,
        "raw_reason": raw_reason,
        "parse_reason": parse_reason,
        "stdout": info.get("stdout", ""),
        "stderr": info.get("stderr", ""),
    }


def _analyze_with_heuristic(stdout: str, stderr: str, returncode: int) -> tuple[bool, str]:
    """Fallback when no language/repo parser is available."""
    combined_raw = stdout + "\n" + stderr
    combined_log = combined_raw.lower()
    connect_fail_patterns = [
        r"couldn't connect",
        r"failed to connect",
        r"error downloading",
    ]
    fail_patterns = [
        r"failed to build",
        r"--- fail",
        r"\bfail\b",
        r"error:",
        r"panic:",
        r"runtime error",
        r"segmentation fault",
        r"test failed",
        r"traceback \(most recent call last\)",
        r"\[error\]",
        r"fail\t",
    ]
    for pattern in connect_fail_patterns:
        if re.search(pattern, combined_log):
            return False, "NETWORK_ERROR"
    omnigril_match = _OMNIGRIL_EXIT_RE.search(combined_raw)
    if omnigril_match:
        exit_code = int(omnigril_match.group(1))
        if exit_code != 0:
            return False, "NON_ZERO_EXIT"
        for pattern in fail_patterns:
            if re.search(pattern, combined_log):
                return False, "LOG_CONTAINS_FAILURE"
        return True, "SUCCESS"
    if returncode != 0:
        return False, "NON_ZERO_EXIT"
    for pattern in fail_patterns:
        if re.search(pattern, combined_log):
            return False, "LOG_CONTAINS_FAILURE"
    if "pass" in combined_log or "ok" in combined_log:
        return True, "SUCCESS"
    return False, "NO_PASS_SIGNAL"


def analyze_test_output(stdout: str, stderr: str, returncode: int, apply_success: bool, language: str = "", repo: str = ""):
    """Determine pass/fail from test output. Uses log_parsers by language/repo when available."""
    # 1) apply fail → 直接返回
    if not apply_success:
        return False, "APPLY_FAILED"

    combined_raw = stdout + "\n" + stderr
    omnigril_match = _OMNIGRIL_EXIT_RE.search(combined_raw)
    # 2) omit code (OMNIGRIL_EXIT_CODE) 非 0 → 直接返回
    if omnigril_match and int(omnigril_match.group(1)) != 0:
        return False, "NON_ZERO_EXIT"

    # 去掉 stdout 中的 omit code 行，再交给 parser / 启发式
    cleaned_stdout = _strip_omnigril_exit(stdout)
    combined_log = cleaned_stdout + "\n" + stderr
    parser = get_log_parser(language, repo)

    if parser is not None:
        test_spec = {}
        try:
            test_status_map = parser(combined_log, test_spec)
        except Exception:
            return _analyze_with_heuristic(cleaned_stdout, stderr, returncode)
        if test_status_map:
            failed_statuses = {TestStatus.FAILED.value, TestStatus.ERROR.value}
            if any(s in failed_statuses for s in test_status_map.values()):
                return False, "LOG_CONTAINS_FAILURE"
            return True, "SUCCESS"
        # Parser 返回空 map：回退到启发式
    return _analyze_with_heuristic(cleaned_stdout, stderr, returncode)

def run_single_patch(container_name, image_name, patch_content, eval_script, language="", repo=""):
    run_command(f"docker run -d --name {container_name} --memory='4g' --cpus='4' {image_name} tail -f /dev/null")
    
    apply_res = None
    eval_res = None
    apply_success = False

    try:
        repo_path = "/testbed"
        # 1. Apply patch phase
        patch_file = create_temp_file(patch_content or "", suffix=".diff")
        run_command(f"docker cp {patch_file} {container_name}:/tmp/patch.diff")
        
        apply_cmd = f"docker exec {container_name} bash -c 'cd {repo_path} && (git apply -v /tmp/patch.diff || patch -p1 < /tmp/patch.diff)'"
        apply_res, is_timeout = run_command(apply_cmd, timeout=60)
        if os.path.exists(patch_file): os.unlink(patch_file)
        
        if is_timeout: 
            return None, "TIMEOUT_APPLY", "APPLY", False
        
        apply_success = (apply_res.returncode == 0)

        # 2. Evaluate phase
        eval_file = create_temp_file(eval_script, suffix=".sh")
        run_command(f"docker cp {eval_file} {container_name}:/tmp/evaluate.sh")
        eval_cmd = f"docker exec {container_name} bash -c 'chmod +x /tmp/evaluate.sh && /tmp/evaluate.sh'"
        eval_res, is_timeout = run_command(eval_cmd, timeout=1200)
        if os.path.exists(eval_file): os.unlink(eval_file)
        
        if is_timeout: 
            return None, "TIMEOUT_EVAL", "EVAL", apply_success

        # Analyze results (use log_parsers by language/repo when available)
        is_passed, reason = analyze_test_output(
            eval_res.stdout, eval_res.stderr, eval_res.returncode, apply_success,
            language=language, repo=repo,
        )
        
        return {
            "is_passed": is_passed,
            "reason": reason,
            "stdout": eval_res.stdout,
            "stderr": eval_res.stderr,
            "apply_err": apply_res.stderr if not apply_success else ""
        }, None, False, apply_success

    finally:
        subprocess.run(f"docker rm -f {container_name}", shell=True, capture_output=True)

def _process_one_instance(job):
    """Process a single instance: pull image, run model/golden patch, return (instance_id, result_dict)."""
    instance_id, item, eval_script, golden_patch, cleanup, language, repo = job
    print(f"Processing {instance_id}...")
    image_name = f'key4127/refactor-dockerhub:{instance_id}'

    try:
        # Pull image
        _, is_pull_timeout = run_command(f'docker pull {image_name}', timeout=300)

        # Run model patch
        m_res, m_err, m_timeout_loc, m_app = run_single_patch(
            f"m_{uuid.uuid4().hex[:6]}", image_name, item.get('model_patch'), eval_script,
            language=language, repo=repo,
        )
        # Run golden patch
        g_res, g_err, g_timeout_loc, g_app = run_single_patch(
            f"g_{uuid.uuid4().hex[:6]}", image_name, golden_patch, eval_script,
            language=language, repo=repo,
        )

    finally:
        if cleanup:
            run_command(f"docker rmi {image_name}", timeout=60)

    # Aggregate status
    timeout_at = m_timeout_loc or g_timeout_loc or False
    m_passed = m_res["is_passed"] if m_res else False
    g_passed = g_res["is_passed"] if g_res else False

    m_stdout = m_res["stdout"] if m_res else ""
    m_stderr = m_res["stderr"] if m_res else ""
    g_stdout = g_res["stdout"] if g_res else ""
    g_stderr = g_res["stderr"] if g_res else ""

    m_reason = m_res["reason"] if m_res else m_err
    g_reason = g_res["reason"] if g_res else g_err

    is_match = ((m_stdout == g_stdout) and (m_stderr == g_stderr) and (m_reason == g_reason))

    apply_fail = m_res["apply_err"] if m_res else ""

    if not timeout_at and not apply_fail:
        if is_match:
            m_passed = True
            g_passed = True
            m_reason = "SUCCESS"
            g_reason = "SUCCESS"
        elif g_reason != "SUCCESS" and m_reason == g_reason:
            m_reason = "NEED_HUMAN_REVIEW"
            g_reason = "NEED_HUMAN_REVIEW"

    # 与 log_parse.py 输出格式对齐：model/golden 使用 final_result, raw_reason, parse_reason
    model_info = (
        m_res
        if m_res
        else {"reason": m_err, "stdout": m_stdout, "stderr": m_stderr, "apply_err": ""}
    )
    golden_info = (
        g_res
        if g_res
        else {"reason": g_err, "stdout": g_stdout, "stderr": g_stderr, "apply_err": ""}
    )
    model_parsed = _to_log_parse_style_info(model_info, m_err or "")
    golden_parsed = _to_log_parse_style_info(golden_info, g_err or "")
    passed = model_parsed["final_result"] == "success" and golden_parsed["final_result"] == "success"

    result = {
        "instance_id": instance_id,
        "language": language,
        "passed": passed,
        "model": model_parsed,
        "golden": golden_parsed,
    }
    return (instance_id, result)


def stat_pass_rate(pred_path, golden_path, eval_path, output_path, workers=1, cleanup=False):
    with open(pred_path, 'r', encoding='utf-8') as f: pred_data = json.load(f)
    with open(golden_path, 'r', encoding='utf-8') as f: golden_list = json.load(f)
    with open(eval_path, 'r', encoding='utf-8') as f: eval_data = json.load(f)

    # 以 preds 为主表：归一化为条目列表
    if isinstance(pred_data, dict):
        pred_entries = list(pred_data.values())
    else:
        pred_entries = pred_data if isinstance(pred_data, list) else []

    # golden 做 instance_id -> entry 查找；支持 list 或 dict 格式
    if isinstance(golden_list, dict):
        golden_lookup = golden_list
        golden_entries = list(golden_list.values())
    else:
        golden_entries = golden_list or []
        golden_lookup = {it["instance_id"]: it for it in golden_entries if it.get("instance_id") is not None}

    lang_map = {it["instance_id"]: it.get("language", "unknown") or "unknown" for it in golden_entries}
    repo_map = {it["instance_id"]: it.get("repo", "") or "" for it in golden_entries}

    jobs = []
    for item in pred_entries:
        instance_id = item.get("instance_id")
        if instance_id is None:
            continue
        golden_entry = golden_lookup.get(instance_id)
        if golden_entry is None:
            continue  # preds 中有但 golden 中无，跳过
        eval_script = eval_data.get(instance_id, {}).get('eval_script', "")
        golden_patch = golden_entry.get('patch')
        language = lang_map.get(instance_id, "")
        repo = repo_map.get(instance_id, "")
        jobs.append((instance_id, item, eval_script, golden_patch, cleanup, language, repo))

    if workers <= 1:
        results_list = [_process_one_instance(job)[1] for job in jobs]
    else:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            # map preserves job order
            results_list = [result for _, result in executor.map(_process_one_instance, jobs)]

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(results_list, f, indent=2, ensure_ascii=False)

    # Print pass rate summary
    print_pass_rate_summary(results_list, lang_map)


def _get_golden_result(r):
    """兼容两种 pass_rate.json 格式，提取 golden 的结果字符串（统一小写）。"""
    if "golden" in r:
        return r["golden"]["final_result"]
    if "golden_info" in r:
        return r["golden_info"].get("reason", "").lower()
    return ""


def _get_model_result(r):
    """兼容两种格式，提取 model 的结果字符串。"""
    if "model" in r:
        return r["model"]["final_result"]
    if "model_info" in r:
        return r["model_info"].get("reason", "")
    return ""


def _is_passed(r):
    """兼容两种格式，判断该条目是否 passed。"""
    if "passed" in r:
        return r["passed"]
    if "model_info" in r:
        return r["model_info"].get("passed", False)
    return False


def print_pass_rate_summary(results_list, lang_map):
    total = sum(1 for r in results_list if _get_golden_result(r) == "success")
    if total == 0:
        print("\nNo results to summarize.")
        return

    passed = sum(1 for r in results_list if _is_passed(r))
    print(f"\n{'='*60}")
    print(f"  Overall: {passed}/{total} passed ({100*passed/total:.1f}%)")
    print(f"{'='*60}")

    lang_stats = {}
    for r in results_list:
        if _get_golden_result(r) != "success":
            continue
        lang = lang_map.get(r["instance_id"], "unknown")
        stats = lang_stats.setdefault(lang, {"total": 0, "passed": 0})
        stats["total"] += 1
        if _is_passed(r):
            stats["passed"] += 1

    print(f"  {'Language':<15} {'Passed':>8} {'Total':>8} {'Rate':>8}")
    print(f"  {'-'*15} {'-'*8} {'-'*8} {'-'*8}")
    for lang in sorted(lang_stats, key=lambda l: -lang_stats[l]["total"]):
        s = lang_stats[lang]
        rate = 100 * s["passed"] / s["total"] if s["total"] else 0
        print(f"  {lang:<15} {s['passed']:>8} {s['total']:>8} {rate:>7.1f}%")

    reason_counts = {}
    for r in results_list:
        reason = _get_model_result(r)
        reason_counts[reason] = reason_counts.get(reason, 0) + 1
    total_results = len(results_list)

    print(f"\n  Results:")
    for reason, count in sorted(reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_results if total_results else 0
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")
    print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(description='Evaluate model patches against golden patches and report pass rate')
    parser.add_argument('--pred', '-p', default='./preds.json', help='Predictions JSON path (default: ./preds.json)')
    parser.add_argument('--golden', '-g', default='./golden.json', help='Golden patches JSON path (default: ./golden.json)')
    parser.add_argument('--eval', '-e', default='./eval.json', help='Eval scripts JSON path (default: ./eval.json)')
    parser.add_argument('--output', '-o', default='./pass_rate.json', help='Output results JSON path (default: ./pass_rate.json)')
    parser.add_argument('--workers', '-w', type=int, default=1, help='Number of parallel workers (default: 1)')
    parser.add_argument('--cleanup', action='store_true', help='Remove docker images after evaluation (default: keep)')
    args = parser.parse_args()
    stat_pass_rate(args.pred, args.golden, args.eval, args.output, workers=args.workers, cleanup=args.cleanup)


if __name__ == '__main__':
    main()