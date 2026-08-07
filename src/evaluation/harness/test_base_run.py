import argparse
import json
import os
import subprocess
import uuid
from concurrent.futures import ThreadPoolExecutor

try:
    from harness.test_run import (
        EVAL_TIMEOUT,
        FLAKY_MAX_RETRIES,
        _docker_network_flags,
        _extract_omnigril_exit,
        _is_flaky_result,
        _local_image_exists,
        _local_images_only_enabled,
        _run_single_patch_with_retry,
        _to_result_info,
        analyze_test_output,
        create_temp_file,
        run_command,
    )
except ImportError:
    from test_run import (
        EVAL_TIMEOUT,
        FLAKY_MAX_RETRIES,
        _docker_network_flags,
        _extract_omnigril_exit,
        _is_flaky_result,
        _local_image_exists,
        _local_images_only_enabled,
        _run_single_patch_with_retry,
        _to_result_info,
        analyze_test_output,
        create_temp_file,
        run_command,
    )


def run_base_commit(container_name, image_name, eval_script, language="", repo=""):
    """Run the eval script on the clean image state, without applying a patch."""
    net_flags = _docker_network_flags()
    run_command(
        f"docker run -d --name {container_name} {net_flags} "
        f"{image_name} tail -f /dev/null"
    )

    eval_file = None
    try:
        eval_file = create_temp_file(eval_script, suffix=".sh")
        run_command(f"docker cp {eval_file} {container_name}:/tmp/evaluate.sh")
        eval_cmd = (
            f"docker exec -u root {container_name} "
            "bash -c 'chmod a+r /tmp/evaluate.sh && bash /tmp/evaluate.sh'"
        )
        eval_res, is_timeout = run_command(eval_cmd, timeout=EVAL_TIMEOUT)

        if is_timeout:
            return {
                "is_passed": False,
                "reason": "TIMEOUT_EVAL",
                "stdout": eval_res.stdout,
                "stderr": eval_res.stderr,
                "returncode": eval_res.returncode,
                "script_exit_code": _extract_omnigril_exit(
                    eval_res.stdout + "\n" + eval_res.stderr
                ),
                "apply_err": "",
            }, None, "EVAL", True

        is_passed, reason = analyze_test_output(
            eval_res.stdout,
            eval_res.stderr,
            eval_res.returncode,
            apply_success=True,
            language=language,
            repo=repo,
        )
        return {
            "is_passed": is_passed,
            "reason": reason,
            "stdout": eval_res.stdout,
            "stderr": eval_res.stderr,
            "returncode": eval_res.returncode,
            "script_exit_code": _extract_omnigril_exit(
                eval_res.stdout + "\n" + eval_res.stderr
            ),
            "apply_err": "",
        }, None, False, True
    finally:
        subprocess.run(
            f"docker rm -f {container_name}",
            shell=True,
            capture_output=True,
        )
        if eval_file and os.path.exists(eval_file):
            os.unlink(eval_file)


def _run_base_commit_with_retry(image_name, eval_script, language, repo):
    last = (None, None, False, True)
    for attempt in range(FLAKY_MAX_RETRIES + 1):
        container_name = f"b_{uuid.uuid4().hex[:6]}"
        res, err, timeout_loc, app = run_base_commit(
            container_name,
            image_name,
            eval_script,
            language=language,
            repo=repo,
        )
        last = (res, err, timeout_loc, app)
        if timeout_loc:
            return last
        if not _is_flaky_result(res):
            return last
        if attempt < FLAKY_MAX_RETRIES:
            print(
                f"[flaky-retry] role=b attempt {attempt + 1}/"
                f"{FLAKY_MAX_RETRIES} hit flaky pattern, retrying..."
            )
    return last


def _missing_eval_result():
    return {
        "is_passed": False,
        "reason": "EVAL_SCRIPT_MISSING",
        "stdout": "",
        "stderr": "",
        "returncode": None,
        "script_exit_code": None,
        "apply_err": "",
    }, None, False, True


def _process_one_instance(job):
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
            run_command(f"docker pull {image_name}", timeout=300)

        if eval_script:
            b_res, b_err, b_timeout_loc, _ = _run_base_commit_with_retry(
                image_name,
                eval_script,
                language=language,
                repo=repo,
            )
            g_res, g_err, g_timeout_loc, _ = _run_single_patch_with_retry(
                "g",
                image_name,
                golden_patch,
                eval_script,
                language=language,
                repo=repo,
            )
        else:
            b_res, b_err, b_timeout_loc, _ = _missing_eval_result()
            g_res, g_err, g_timeout_loc, _ = _missing_eval_result()
    finally:
        if cleanup:
            run_command(f"docker rmi {image_name}", timeout=60)

    base_info = (
        b_res
        if b_res
        else {"reason": b_err, "stdout": "", "stderr": "", "apply_err": ""}
    )
    golden_info = (
        g_res
        if g_res
        else {"reason": g_err, "stdout": "", "stderr": "", "apply_err": ""}
    )
    base_parsed = _to_result_info(base_info, b_err or "")
    golden_parsed = _to_result_info(golden_info, g_err or "")

    result = {
        "instance_id": instance_id,
        "repo": repo,
        "language": language,
        "base_commit": item.get("base_commit", ""),
        "image_name": image_name,
        "passed": (
            base_parsed["final_result"] == "success"
            and golden_parsed["final_result"] == "success"
        ),
        "base_passes": base_parsed["final_result"] == "success",
        "golden_passes": golden_parsed["final_result"] == "success",
        "timeout_at": b_timeout_loc or g_timeout_loc or False,
        "base": base_parsed,
        "golden": golden_parsed,
    }
    return instance_id, result


def _entries_from_benchmark(data):
    if isinstance(data, dict):
        return list(data.values())
    if isinstance(data, list):
        return data
    return []


def stat_base_golden(
    golden_path,
    eval_path,
    output_path,
    workers=1,
    cleanup=False,
    instance_ids=None,
    limit=None,
):
    with open(golden_path, "r", encoding="utf-8") as f:
        golden_data = json.load(f)
    with open(eval_path, "r", encoding="utf-8") as f:
        eval_data = json.load(f)

    golden_entries = _entries_from_benchmark(golden_data)
    if instance_ids:
        wanted = set(instance_ids)
        golden_entries = [
            item for item in golden_entries if item.get("instance_id") in wanted
        ]
    if limit is not None:
        golden_entries = golden_entries[:limit]

    lang_map = {
        it["instance_id"]: it.get("language", "unknown") or "unknown"
        for it in golden_entries
        if it.get("instance_id") is not None
    }

    jobs = []
    for item in golden_entries:
        instance_id = item.get("instance_id")
        if instance_id is None:
            continue
        eval_script = eval_data.get(instance_id, {}).get("eval_script", "")
        image_name = item.get("image_name") or f"key4127/refactor-dockerhub:{instance_id}"
        jobs.append(
            (
                instance_id,
                item,
                eval_script,
                item.get("patch"),
                cleanup,
                item.get("language", ""),
                item.get("repo", "") or "",
                image_name,
            )
        )

    if workers <= 1:
        results_list = [_process_one_instance(job)[1] for job in jobs]
    else:
        with ThreadPoolExecutor(max_workers=workers) as executor:
            results_list = [result for _, result in executor.map(_process_one_instance, jobs)]

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results_list, f, indent=2, ensure_ascii=False)

    print_base_golden_summary(results_list, lang_map)


def _normalize_result(reason):
    return (reason or "").strip().lower()


def print_base_golden_summary(results_list, lang_map):
    total_instances = len(results_list)
    if total_instances == 0:
        print("\nNo results to summarize.")
        return

    golden_success_results = [
        r
        for r in results_list
        if _normalize_result(r.get("golden", {}).get("final_result")) == "success"
    ]
    golden_success = len(golden_success_results)
    base_success = sum(
        1
        for r in results_list
        if _normalize_result(r.get("base", {}).get("final_result")) == "success"
    )
    base_success_with_golden = sum(
        1
        for r in golden_success_results
        if _normalize_result(r.get("base", {}).get("final_result")) == "success"
    )

    print(f"\n{'=' * 60}")
    print(
        f"  Base success on golden-success instances: "
        f"{base_success_with_golden}/{golden_success} "
        f"({100 * base_success_with_golden / golden_success:.1f}%)"
        if golden_success
        else "  Base success on golden-success instances: n/a"
    )
    print(f"  Instances:                  {total_instances}")
    print(
        f"  Base success:               {base_success}/{total_instances} "
        f"({100 * base_success / total_instances:.1f}%)"
    )
    print(
        f"  Golden success:             {golden_success}/{total_instances} "
        f"({100 * golden_success / total_instances:.1f}%)"
    )
    print(f"{'=' * 60}")

    lang_stats = {}
    for r in golden_success_results:
        lang = lang_map.get(r["instance_id"], "unknown")
        stats = lang_stats.setdefault(lang, {"total": 0, "base_passed": 0})
        stats["total"] += 1
        if _normalize_result(r.get("base", {}).get("final_result")) == "success":
            stats["base_passed"] += 1

    if lang_stats:
        print(f"  {'Language':<15} {'BasePass':>8} {'GoldenOK':>8} {'Rate':>8}")
        print(f"  {'-' * 15} {'-' * 8} {'-' * 8} {'-' * 8}")
        for lang in sorted(lang_stats, key=lambda l: -lang_stats[l]["total"]):
            s = lang_stats[lang]
            rate = 100 * s["base_passed"] / s["total"] if s["total"] else 0
            print(
                f"  {lang:<15} {s['base_passed']:>8} "
                f"{s['total']:>8} {rate:>7.1f}%"
            )

    base_reason_counts = {}
    golden_reason_counts = {}
    for r in results_list:
        base_reason = r.get("base", {}).get("final_result") or "unknown"
        golden_reason = r.get("golden", {}).get("final_result") or "unknown"
        base_reason_counts[base_reason] = base_reason_counts.get(base_reason, 0) + 1
        golden_reason_counts[golden_reason] = golden_reason_counts.get(golden_reason, 0) + 1

    print(f"\n  Base results ({total_instances} instances):")
    for reason, count in sorted(base_reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_instances
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")

    print(f"\n  Golden results ({total_instances} instances):")
    for reason, count in sorted(golden_reason_counts.items(), key=lambda x: -x[1]):
        pct = 100 * count / total_instances
        print(f"    {reason:<25} {count:>4} ({pct:.1f}%)")
    print(f"{'=' * 60}")


def main():
    parser = argparse.ArgumentParser(
        description="Evaluate clean base commits and golden patches with SWE-Cascade eval scripts"
    )
    parser.add_argument(
        "--golden",
        "-g",
        default="./golden.json",
        help="Benchmark/golden patches JSON path (default: ./golden.json)",
    )
    parser.add_argument(
        "--eval",
        "-e",
        default="./eval.json",
        help="Eval scripts JSON path (default: ./eval.json)",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="./base_pass_rate.json",
        help="Output results JSON path (default: ./base_pass_rate.json)",
    )
    parser.add_argument(
        "--workers",
        "-w",
        type=int,
        default=1,
        help="Number of parallel workers (default: 1)",
    )
    parser.add_argument(
        "--cleanup",
        action="store_true",
        help="Remove docker images after evaluation (default: keep)",
    )
    parser.add_argument(
        "--instance-id",
        action="append",
        default=[],
        help="Run only this instance id. Repeatable.",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Run only the first N selected instances.",
    )
    args = parser.parse_args()
    stat_base_golden(
        args.golden,
        args.eval,
        args.output,
        workers=args.workers,
        cleanup=args.cleanup,
        instance_ids=args.instance_id,
        limit=args.limit,
    )


if __name__ == "__main__":
    main()
