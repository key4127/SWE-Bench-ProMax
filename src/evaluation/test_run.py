import os
import json
import uuid
import tempfile
import subprocess
import re
import argparse
import shlex
from concurrent.futures import ThreadPoolExecutor

LOCAL_IMAGES_ONLY = False
DOCKER_NETWORK = "host"
DOCKER_DNS = ()
DOCKER_ENV = {}
FLAKY_MAX_RETRIES = 2
EVAL_TIMEOUT = 2400
_PROXY_ENV_KEYS = (
    "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
    "http_proxy", "https_proxy", "all_proxy", "no_proxy",
)

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
    except subprocess.TimeoutExpired as exc:
        print(f"CRITICAL ERROR: Command timed out after {timeout}s")
        stdout = _decode_timeout_stream(exc.stdout)
        stderr = _decode_timeout_stream(exc.stderr)
        timeout_msg = f"TIMEOUT AFTER {timeout}s"
        stderr = f"{stderr.rstrip()}\n{timeout_msg}" if stderr else timeout_msg
        return subprocess.CompletedProcess(cmd, 124, stdout=stdout, stderr=stderr), True


def _decode_timeout_stream(value) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def _local_images_only_enabled() -> bool:
    return LOCAL_IMAGES_ONLY


def _local_image_exists(image_name: str) -> bool:
    result, _ = run_command(f"docker image inspect {image_name}", timeout=30)
    return result.returncode == 0


_OMNIGRIL_EXIT_RE = re.compile(r"OMNIGRIL_EXIT_CODE=(\d+)\s*$", re.MULTILINE)
_TEST_PATCH_APPLY_FAILED_MARKER = "OMNIGRIL_TEST_PATCH_APPLY_FAILED=1"


def _extract_omnigril_exit(text: str) -> int | None:
    match = _OMNIGRIL_EXIT_RE.search(text or "")
    return int(match.group(1)) if match else None


# ---------------------------------------------------------------------------
# Docker network/proxy configuration. Edit the constants above for defaults;
# proxy variables are copied from the host environment when present.
def _docker_network_flags() -> str:
    """Build network/proxy-related `docker run` flags from host settings."""
    flags = []
    if DOCKER_NETWORK:
        flags.append(f"--network {shlex.quote(DOCKER_NETWORK)}")
    for dns in DOCKER_DNS:
        if dns:
            flags.append(f"--dns {shlex.quote(dns)}")
    for key, val in DOCKER_ENV.items():
        if val:
            flags.append(f"-e {shlex.quote(f'{key}={val}')}")
    for key in _PROXY_ENV_KEYS:
        if os.environ.get(key):
            # `-e KEY` lets docker copy the value from the host environment,
            # avoiding shell quoting issues and keeping proxy secrets out of logs.
            flags.append(f"-e {key}")
    return " ".join(flags)


def _execution_info(reason: str, proc, apply_success: bool, apply_res=None) -> dict:
    stdout = proc.stdout if proc else ""
    stderr = proc.stderr if proc else ""
    return {
        "is_passed": False,
        "reason": reason,
        "stdout": stdout,
        "stderr": stderr,
        "returncode": proc.returncode if proc else 124,
        "script_exit_code": _extract_omnigril_exit(stdout + "\n" + stderr),
        "apply_err": apply_res.stderr if apply_res is not None and not apply_success else "",
    }


# ---------------------------------------------------------------------------
# Flaky-test retry configuration
# ---------------------------------------------------------------------------
# Some instances exhibit transient NON_ZERO_EXIT caused by cold-start timeouts
# (e.g. codex-rs `archive_conversation_moves_rollout_into_archived_directory`
# whose mcp-server initialize handshake races against a hard tokio timeout).
# When the log matches one of these signatures we transparently re-run the
# whole patch (golden or model) up to FLAKY_MAX_RETRIES additional times.
_FLAKY_RETRY_PATTERNS = (
    r"initialize timeout: Elapsed",
    r"timeout: Elapsed\(\(\)\)",
)
_FLAKY_MAX_RETRIES = FLAKY_MAX_RETRIES


def _is_flaky_result(res) -> bool:
    """Return True if `res` looks like a known transient failure worth retrying."""
    if not res:
        return False
    if res.get("reason") != "NON_ZERO_EXIT":
        return False
    blob = (res.get("stdout") or "") + "\n" + (res.get("stderr") or "")
    return any(re.search(p, blob) for p in _FLAKY_RETRY_PATTERNS)

# reason -> final_result.  The eval script is now authoritative, so no
# repo-specific log parsing is used.
_REASON_TO_FINAL_RESULT = {
    "SUCCESS": "success",
    "APPLY_FAILED": "apply_failed",
    "TEST_PATCH_APPLY_FAILED": "test_patch_apply_failed",
    "TIMEOUT_APPLY": "timeout_apply",
    "TIMEOUT_EVAL": "timeout_eval",
    "NON_ZERO_EXIT": "non zero exit",
    "NEED_HUMAN_REVIEW": "need_human_review",
}


def _to_result_info(info: dict, reason_fallback: str) -> dict:
    """Normalize model/golden execution details for pass_rate.json."""
    reason = info.get("reason") if isinstance(info.get("reason"), str) else reason_fallback
    final_result = _REASON_TO_FINAL_RESULT.get(
        reason, reason.lower().replace(" ", "_") if reason else "not run"
    )
    raw_reason = reason.lower().replace(" ", "_") if reason else "not run"
    return {
        "final_result": final_result,
        "raw_reason": raw_reason,
        "eval_reason": raw_reason,
        "returncode": info.get("returncode"),
        "script_exit_code": info.get("script_exit_code"),
        "stdout": info.get("stdout", ""),
        "stderr": info.get("stderr", ""),
    }


def analyze_test_output(stdout: str, stderr: str, returncode: int, apply_success: bool, language: str = "", repo: str = ""):
    """Determine pass/fail from the eval script exit status."""
    if not apply_success:
        return False, "APPLY_FAILED"

    combined_raw = stdout + "\n" + stderr
    if _TEST_PATCH_APPLY_FAILED_MARKER in combined_raw:
        return False, "TEST_PATCH_APPLY_FAILED"

    script_exit_code = _extract_omnigril_exit(combined_raw)
    if script_exit_code is not None:
        if script_exit_code == 0 and returncode == 0:
            return True, "SUCCESS"
        return False, "NON_ZERO_EXIT"
    if returncode != 0:
        return False, "NON_ZERO_EXIT"
    return True, "SUCCESS"

def run_single_patch(container_name, image_name, patch_content, eval_script, language="", repo=""):
    net_flags = _docker_network_flags()
    run_command(
        f"docker run -d --name {container_name} {net_flags} "
        f"{image_name} tail -f /dev/null"
    )
    
    apply_res = None
    eval_res = None
    apply_success = False

    try:
        repo_path = "/testbed"
        # 1. Apply patch phase
        patch_file = create_temp_file(patch_content or "", suffix=".diff")
        run_command(f"docker cp {patch_file} {container_name}:/tmp/patch.diff")
        
        apply_cmd = f"docker exec -u root {container_name} bash -c 'cd {repo_path} && (git apply -v /tmp/patch.diff || patch -p1 < /tmp/patch.diff)'"
        apply_res, is_timeout = run_command(apply_cmd, timeout=60)
        if os.path.exists(patch_file): os.unlink(patch_file)
        
        if is_timeout: 
            return _execution_info("TIMEOUT_APPLY", apply_res, False, apply_res), None, "APPLY", False
        
        apply_success = (apply_res.returncode == 0)

        # 2. Evaluate phase
        eval_file = create_temp_file(eval_script, suffix=".sh")
        run_command(f"docker cp {eval_file} {container_name}:/tmp/evaluate.sh")
        eval_cmd = f"docker exec -u root {container_name} bash -c 'chmod a+r /tmp/evaluate.sh && bash /tmp/evaluate.sh'"
        eval_res, is_timeout = run_command(eval_cmd, timeout=EVAL_TIMEOUT)
        if os.path.exists(eval_file): os.unlink(eval_file)
        
        if is_timeout: 
            return _execution_info("TIMEOUT_EVAL", eval_res, apply_success, apply_res), None, "EVAL", apply_success

        # Analyze results from the eval script itself. The script's exit code
        # or OMNIGRIL_EXIT_CODE marker is authoritative.
        is_passed, reason = analyze_test_output(
            eval_res.stdout, eval_res.stderr, eval_res.returncode, apply_success,
            language=language, repo=repo,
        )
        
        return {
            "is_passed": is_passed,
            "reason": reason,
            "stdout": eval_res.stdout,
            "stderr": eval_res.stderr,
            "returncode": eval_res.returncode,
            "script_exit_code": _extract_omnigril_exit(eval_res.stdout + "\n" + eval_res.stderr),
            "apply_err": apply_res.stderr if not apply_success else ""
        }, None, False, apply_success

    finally:
        subprocess.run(f"docker rm -f {container_name}", shell=True, capture_output=True)

def _run_single_patch_with_retry(role, image_name, patch_content, eval_script, language, repo):
    """Run `run_single_patch` and transparently retry on known flaky failures.

    `role` is a short prefix used for the container name ("m" / "g"). A fresh
    uuid suffix is generated per attempt so retried runs use a clean container.
    """
    last = (None, None, False, False)
    for attempt in range(_FLAKY_MAX_RETRIES + 1):
        container_name = f"{role}_{uuid.uuid4().hex[:6]}"
        res, err, timeout_loc, app = run_single_patch(
            container_name, image_name, patch_content, eval_script,
            language=language, repo=repo,
        )
        last = (res, err, timeout_loc, app)
        if timeout_loc:
            return last
        if not _is_flaky_result(res):
            return last
        if attempt < _FLAKY_MAX_RETRIES:
            print(
                f"[flaky-retry] role={role} attempt {attempt + 1}/"
                f"{_FLAKY_MAX_RETRIES} hit flaky pattern, retrying..."
            )
    return last


def _process_one_instance(job):
    """Process a single instance: pull image, run model/golden patch, return (instance_id, result_dict)."""
    instance_id, item, eval_script, golden_patch, cleanup, language, repo, image_name = job
    print(f"Processing {instance_id}...")

    try:
        if _local_images_only_enabled():
            if not _local_image_exists(image_name):
                raise RuntimeError(
                    f"LOCAL_IMAGES_ONLY is enabled but image is missing locally: {image_name}"
                )
            print(f"Using local image {image_name}")
        else:
            # Pull image
            _, is_pull_timeout = run_command(f'docker pull {image_name}', timeout=300)

        # Run model patch (with flaky-pattern retry)
        m_res, m_err, m_timeout_loc, m_app = _run_single_patch_with_retry(
            "m", image_name, item.get('model_patch'), eval_script,
            language=language, repo=repo,
        )
        # Run golden patch (with flaky-pattern retry)
        g_res, g_err, g_timeout_loc, g_app = _run_single_patch_with_retry(
            "g", image_name, golden_patch, eval_script,
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

    # Keep the model/golden shape stable for downstream pass_rate consumers.
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
    model_parsed = _to_result_info(model_info, m_err or "")
    golden_parsed = _to_result_info(golden_info, g_err or "")
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
        image_name = golden_entry.get("image_name") or f"key4127/refactor-dockerhub:{instance_id}"
        jobs.append((instance_id, item, eval_script, golden_patch, cleanup, language, repo, image_name))

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


def _normalize_result(reason: str) -> str:
    return (reason or "").strip().lower()


def print_pass_rate_summary(results_list, lang_map):
    total_instances = len(results_list)
    golden_success_results = [
        r for r in results_list
        if _normalize_result(_get_golden_result(r)) == "success"
    ]
    total = len(golden_success_results)
    if total == 0:
        print("\nNo results to summarize.")
        return

    passed = sum(1 for r in golden_success_results if _is_passed(r))
    model_passed = sum(
        1 for r in results_list if _normalize_result(_get_model_result(r)) == "success"
    )

    print(f"\n{'='*60}")
    print(f"  Overall: {passed}/{total} passed ({100 * passed / total:.1f}%)")
    print(f"  Instances:                  {total_instances}")
    print(
        f"  Model success:              {model_passed}/{total_instances} "
        f"({100 * model_passed / total_instances:.1f}%)"
    )
    print(
        f"  Golden success:             {total}/{total_instances} "
        f"({100 * total / total_instances:.1f}%)"
    )
    print(f"{'='*60}")

    lang_stats = {}
    for r in golden_success_results:
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

    model_reason_counts = {}
    golden_reason_counts = {}
    for r in results_list:
        model_reason = _get_model_result(r) or "unknown"
        golden_reason = _get_golden_result(r) or "unknown"
        model_reason_counts[model_reason] = model_reason_counts.get(model_reason, 0) + 1
        golden_reason_counts[golden_reason] = golden_reason_counts.get(golden_reason, 0) + 1

    print(f"\n  Model results ({total_instances} instances):")
    for reason, count in sorted(model_reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_instances
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")

    print(f"\n  Golden results ({total_instances} instances):")
    for reason, count in sorted(golden_reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_instances
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")
    print(f"{'='*60}")


def main():
    parser = argparse.ArgumentParser(description='Evaluate model patches against golden patches and report pass rate')
    parser.add_argument('--pred', '-p', default='./preds.json', help='Predictions JSON path (default: ./preds.json)')
    parser.add_argument('--golden', '-g', default='./data/swe-bench-promax.json', help='Golden patches JSON path (default: ./data/swe-bench-promax.json)')
    parser.add_argument('--eval', '-e', default='./data/eval.json', help='Eval scripts JSON path (default: ./data/eval.json)')
    parser.add_argument('--output', '-o', default='./pass_rate.json', help='Output results JSON path (default: ./pass_rate.json)')
    parser.add_argument('--workers', '-w', type=int, default=1, help='Number of parallel workers (default: 1)')
    parser.add_argument('--cleanup', action='store_true', help='Remove docker images after evaluation (default: keep)')
    args = parser.parse_args()
    stat_pass_rate(args.pred, args.golden, args.eval, args.output, workers=args.workers, cleanup=args.cleanup)


if __name__ == '__main__':
    main()
