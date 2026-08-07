import argparse
import json
import os
import signal
import shutil
import subprocess
import uuid
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed

from harness.test_run import (
    _docker_network_flags,
    _extract_omnigril_exit,
    analyze_test_output,
    create_temp_file,
)


def _run_command(cmd, timeout=600):
    print(f"execute: {cmd}", flush=True)
    proc = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return subprocess.CompletedProcess(cmd, proc.returncode, stdout=stdout, stderr=stderr), False
    except subprocess.TimeoutExpired:
        print(f"CRITICAL ERROR: Command timed out after {timeout}s", flush=True)
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            stdout, stderr = proc.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = proc.communicate()
        return (
            subprocess.CompletedProcess(
                cmd,
                1,
                stdout=(stdout or "") + "\nTIMEOUT",
                stderr=(stderr or "") + f"\nTIMEOUT AFTER {timeout}s",
            ),
            True,
        )


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _benchmark_entries(data):
    if isinstance(data, dict):
        return list(data.values())
    if isinstance(data, list):
        return data
    raise TypeError("benchmark JSON must be a list or dict")


def _result(
    item,
    *,
    passed=False,
    reason="UNKNOWN",
    stdout="",
    stderr="",
    returncode=None,
    script_exit_code=None,
    image_name=None,
    docker_image_source=None,
):
    final_result = "success" if passed else reason.lower().replace("_", " ")
    image_source = docker_image_source or item.get("_docker_image_source") or "not_checked"
    return {
        "instance_id": item.get("instance_id"),
        "repo": item.get("repo", ""),
        "language": item.get("language", ""),
        "base_commit": item.get("base_commit", ""),
        "image_name": image_name or item.get("image_name", ""),
        "docker_image_source": image_source,
        "base_passes": bool(passed),
        "base": {
            "final_result": final_result,
            "raw_reason": reason.lower(),
            "parse_reason": "success" if passed else "not run",
            "returncode": returncode,
            "script_exit_code": script_exit_code,
            "stdout": stdout or "",
            "stderr": stderr or "",
        },
    }


def _write_results(output_path, results):
    if not output_path:
        return
    completed = [row for row in results if row is not None]
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(completed, f, indent=2, ensure_ascii=False)


def _local_image_exists(image_name):
    res, timed_out = _run_command(f"docker image inspect {image_name}", timeout=30)
    return (not timed_out) and res.returncode == 0, res


def _run_base_instance(job):
    item, eval_entry, pull, cleanup, eval_timeout, pull_timeout = job
    item = dict(item)
    instance_id = item["instance_id"]
    image_name = item.get("image_name") or f"key4127/refactor-dockerhub:{instance_id}"
    container_name = f"base_{uuid.uuid4().hex[:8]}"
    eval_file = None

    print(f"Processing base {instance_id}...", flush=True)
    try:
        if pull:
            pull_res, did_pull_timeout = _run_command(f"docker pull {image_name}", timeout=pull_timeout)
            if did_pull_timeout:
                item["_docker_image_source"] = "remote_pull_timeout"
                return _result(item, reason="TIMEOUT_PULL", image_name=image_name)
            if pull_res.returncode != 0:
                item["_docker_image_source"] = "remote_pull_failed"
                return _result(
                    item,
                    reason="IMAGE_PULL_FAILED",
                    stdout=pull_res.stdout,
                    stderr=pull_res.stderr,
                    returncode=pull_res.returncode,
                    image_name=image_name,
                )
            item["_docker_image_source"] = "remote_pulled"

        exists, inspect_res = _local_image_exists(image_name)
        if not exists:
            item["_docker_image_source"] = "remote_pulled_but_missing" if pull else "local_missing"
            return _result(
                item,
                reason="LOCAL_IMAGE_NOT_FOUND",
                stdout=inspect_res.stdout,
                stderr=inspect_res.stderr,
                returncode=inspect_res.returncode,
                image_name=image_name,
            )
        if not pull:
            item["_docker_image_source"] = "local"

        net_flags = _docker_network_flags()
        run_res, run_timeout = _run_command(
            f"docker run -d --name {container_name} --cpus='4' {net_flags} {image_name} tail -f /dev/null",
            timeout=120,
        )
        if run_timeout:
            return _result(item, reason="TIMEOUT_DOCKER_RUN", image_name=image_name)
        if run_res.returncode != 0:
            return _result(
                item,
                reason="DOCKER_RUN_FAILED",
                stdout=run_res.stdout,
                stderr=run_res.stderr,
                returncode=run_res.returncode,
                image_name=image_name,
            )

        eval_script = eval_entry.get("eval_script", "")
        eval_file = create_temp_file(eval_script, suffix=".sh", prefix=f"{instance_id}_eval_")
        cp_res, cp_timeout = _run_command(f"docker cp {eval_file} {container_name}:/tmp/evaluate.sh", timeout=120)
        if cp_timeout:
            return _result(item, reason="TIMEOUT_DOCKER_CP", image_name=image_name)
        if cp_res.returncode != 0:
            return _result(
                item,
                reason="DOCKER_CP_FAILED",
                stdout=cp_res.stdout,
                stderr=cp_res.stderr,
                returncode=cp_res.returncode,
                image_name=image_name,
            )

        eval_res, timed_out = _run_command(
            f"docker exec -u root {container_name} bash -c 'chmod a+r /tmp/evaluate.sh && bash /tmp/evaluate.sh'",
            timeout=eval_timeout,
        )
        if timed_out:
            return _result(
                item,
                reason="TIMEOUT_EVAL",
                stdout=eval_res.stdout,
                stderr=eval_res.stderr,
                returncode=eval_res.returncode,
                script_exit_code=_extract_omnigril_exit(eval_res.stdout + "\n" + eval_res.stderr),
                image_name=image_name,
            )

        passed, reason = analyze_test_output(
            eval_res.stdout,
            eval_res.stderr,
            eval_res.returncode,
            apply_success=True,
            language=item.get("language", ""),
            repo=item.get("repo", ""),
        )
        return _result(
            item,
            passed=passed,
            reason=reason,
            stdout=eval_res.stdout,
            stderr=eval_res.stderr,
            returncode=eval_res.returncode,
            script_exit_code=_extract_omnigril_exit(eval_res.stdout + "\n" + eval_res.stderr),
            image_name=image_name,
        )
    finally:
        subprocess.run(f"docker rm -f {container_name}", shell=True, capture_output=True)
        if cleanup:
            _run_command(f"docker rmi {image_name}", timeout=60)
        if eval_file and os.path.exists(eval_file):
            os.unlink(eval_file)


def _filter_entries(entries, instance_ids, limit):
    if instance_ids:
        wanted = set(instance_ids)
        entries = [item for item in entries if item.get("instance_id") in wanted]
    if limit is not None:
        entries = entries[:limit]
    return entries


def _print_summary(results):
    total = len(results)
    base_pass = sum(1 for row in results if row.get("base_passes"))
    print("\n" + "=" * 72)
    print(f"Base-pass check: {base_pass}/{total} instances pass on base")
    print("=" * 72)

    by_reason = Counter(row.get("base", {}).get("raw_reason", "unknown") for row in results)
    print("Reasons:")
    for reason, count in by_reason.most_common():
        pct = (100 * count / total) if total else 0
        print(f"  {reason:<24} {count:>4} ({pct:5.1f}%)")

    by_lang = defaultdict(lambda: {"total": 0, "base_pass": 0})
    for row in results:
        lang = row.get("language") or "unknown"
        by_lang[lang]["total"] += 1
        by_lang[lang]["base_pass"] += int(bool(row.get("base_passes")))

    print("\nBy language:")
    for lang, stats in sorted(by_lang.items(), key=lambda kv: (-kv[1]["base_pass"], kv[0])):
        total_lang = stats["total"]
        passed_lang = stats["base_pass"]
        pct = (100 * passed_lang / total_lang) if total_lang else 0
        print(f"  {lang:<15} {passed_lang:>4}/{total_lang:<4} ({pct:5.1f}%)")
    print("=" * 72)


def check_base_pass(
    benchmark_path,
    eval_path,
    output_path,
    *,
    workers=1,
    pull=False,
    cleanup=False,
    instance_ids=None,
    limit=None,
    eval_timeout=1800,
    pull_timeout=1800,
):
    benchmark = _benchmark_entries(_load_json(benchmark_path))
    eval_data = _load_json(eval_path)
    entries = _filter_entries(benchmark, instance_ids or [], limit)

    if output_path:
        output_dir = os.path.dirname(os.path.abspath(output_path))
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)

    if not shutil.which("docker"):
        results = [
            _result(
                item,
                reason="DOCKER_NOT_AVAILABLE",
                image_name=item.get("image_name") or f"key4127/refactor-dockerhub:{item['instance_id']}",
                docker_image_source="not_checked",
            )
            for item in entries
        ]
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        _print_summary(results)
        print("Docker executable not found; base-pass evals were not run.")
        print(f"Wrote {len(results)} results to {output_path}")
        return

    info_res, info_timeout = _run_command("docker info", timeout=30)
    if info_timeout or info_res.returncode != 0:
        results = [
            _result(
                item,
                reason="DOCKER_DAEMON_UNAVAILABLE",
                stdout=info_res.stdout,
                stderr=info_res.stderr,
                returncode=info_res.returncode,
                image_name=item.get("image_name") or f"key4127/refactor-dockerhub:{item['instance_id']}",
                docker_image_source="not_checked",
            )
            for item in entries
        ]
        _write_results(output_path, results)
        _print_summary(results)
        print("Docker daemon is unavailable; base-pass evals were not run.")
        print(f"Wrote {len(results)} results to {output_path}")
        return

    jobs = []
    for item in entries:
        instance_id = item.get("instance_id")
        if instance_id not in eval_data:
            jobs.append((item, {"eval_script": ""}, pull, cleanup, eval_timeout, pull_timeout))
            continue
        jobs.append((item, eval_data[instance_id], pull, cleanup, eval_timeout, pull_timeout))

    if workers <= 1:
        results = [None] * len(jobs)
        for idx, job in enumerate(jobs):
            results[idx] = _run_base_instance(job)
            row = results[idx]
            print(
                f"[{idx + 1}/{len(jobs)}] Finished {row['instance_id']}: "
                f"{row['base']['raw_reason']}",
                flush=True,
            )
            _write_results(output_path, results)
    else:
        results = [None] * len(jobs)
        with ThreadPoolExecutor(max_workers=workers) as executor:
            future_to_idx = {
                executor.submit(_run_base_instance, job): idx
                for idx, job in enumerate(jobs)
            }
            completed = 0
            for future in as_completed(future_to_idx):
                idx = future_to_idx[future]
                item = jobs[idx][0]
                try:
                    results[idx] = future.result()
                except Exception as exc:
                    results[idx] = _result(
                        item,
                        reason="HARNESS_EXCEPTION",
                        stderr=repr(exc),
                        image_name=item.get("image_name") or f"key4127/refactor-dockerhub:{item['instance_id']}",
                    )
                completed += 1
                row = results[idx]
                print(
                    f"[{completed}/{len(jobs)}] Finished {row['instance_id']}: "
                    f"{row['base']['raw_reason']}",
                    flush=True,
                )
                _write_results(output_path, results)

    results = [row for row in results if row is not None]
    _write_results(output_path, results)

    _print_summary(results)
    print(f"Wrote {len(results)} results to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "Run every SWE-Cascade eval script on the base image without applying "
            "a model patch. Any successful result means the base version already "
            "passes the benchmark test."
        )
    )
    parser.add_argument("--benchmark", "-b", default="data/swe-cascade.json")
    parser.add_argument("--eval", "-e", default="data/eval.json")
    parser.add_argument("--output", "-o", default="base_pass_results.json")
    parser.add_argument("--workers", "-w", type=int, default=1)
    parser.add_argument("--instance-id", action="append", default=[], help="Run only this instance id. Repeatable.")
    parser.add_argument("--limit", type=int, default=None, help="Run only the first N selected instances.")
    parser.add_argument("--eval-timeout", type=int, default=1800, help="Per-instance eval timeout in seconds.")
    parser.add_argument("--pull-timeout", type=int, default=1800, help="Per-instance docker pull timeout in seconds.")
    parser.add_argument("--pull", action="store_true", help="Opt in to docker pull before running. Default is local images only.")
    parser.add_argument("--no-pull", action="store_true", help="Deprecated no-op; local images only is now the default.")
    parser.add_argument("--cleanup", action="store_true", help="Remove Docker images after each instance.")
    args = parser.parse_args()

    check_base_pass(
        args.benchmark,
        args.eval,
        args.output,
        workers=args.workers,
        pull=args.pull and not args.no_pull,
        cleanup=args.cleanup,
        instance_ids=args.instance_id,
        limit=args.limit,
        eval_timeout=args.eval_timeout,
        pull_timeout=args.pull_timeout,
    )


if __name__ == "__main__":
    main()
