#!/usr/bin/env python3
"""Run mini-swe-agent on SWE-Bench-ProMax instances and write predictions for test_run.py.

The agent process runs on the host and executes its commands inside the task image with
`docker exec`; the task container is started with `--network none`, so the agent cannot fetch
the upstream fix or any other code from the internet. Model calls go out from the host.

For every instance:
  1. start the task image (`image_name`) with `--network none` (12 GB / 4 CPUs by default, the same caps
     test_run.py uses), working directory /testbed;
  2. run mini-swe-agent with its default `mini` config (the same config `mini-swe-agent -c mini`
     uses), in yolo mode with a wall-clock limit (default 7200 s);
  3. collect everything the agent changed relative to the base commit
     (`git add -N . && git diff --binary <base>`), whether or not the agent submitted;
  4. append the patch to <output>/preds.json and save the trajectory.

Then grade with the official runner:
    python src/evaluation/test_run.py --pred <output>/preds.json \
        --golden data/swe-bench-promax.json --eval data/eval.json --output <output>/pass_rate.json

Model access goes through litellm. For an OpenAI-compatible endpoint, set OPENAI_API_KEY and
OPENAI_BASE_URL (or pass --api-base) and use a model name such as `openai/<model>`.

Example:
    pip install mini-swe-agent==2.4.6
    export OPENAI_API_KEY=... OPENAI_BASE_URL=https://.../v1
    python src/inference/run_mini_swe_agent.py --model openai/deepseek-v4.1-flash \
        --instance-ids ids.txt --workers 4 --output runs/dsv41flash_run1
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import os
import shlex
import threading
import time
import traceback
from pathlib import Path

INSTRUCTION = """The repository is checked out at `/testbed`. Resolve the issue below by editing the source code in place. Do not modify existing tests.

<issue>
{problem_statement}
</issue>
"""

# Same command the Harbor adapter's [[verifier.collect]] step runs: every change relative to the base
# commit, including new files; mode-only changes and changes inside submodules' own trees are ignored.
COLLECT = "git add -N . && git -c core.filemode=false diff --binary --ignore-submodules=dirty {base}"

_preds_lock = threading.Lock()


def load_instances(dataset: Path, ids_file: Path | None) -> list[dict]:
    data = json.loads(dataset.read_text())
    if ids_file is not None:
        wanted = [l.strip() for l in ids_file.read_text().splitlines() if l.strip() and not l.startswith("#")]
        by_id = {x["instance_id"]: x for x in data}
        missing = [i for i in wanted if i not in by_id]
        if missing:
            raise SystemExit(f"unknown instance ids: {missing}")
        data = [by_id[i] for i in wanted]
    return data


def update_preds(path: Path, instance_id: str, model_name: str, patch: str) -> None:
    with _preds_lock:
        preds = json.loads(path.read_text()) if path.exists() else {}
        preds[instance_id] = {"instance_id": instance_id, "model_name_or_path": model_name, "model_patch": patch}
        path.write_text(json.dumps(preds, indent=2))


def run_instance(inst: dict, args: argparse.Namespace, out: Path) -> dict:
    from minisweagent.agents import get_agent
    from minisweagent.config import get_config_from_spec
    from minisweagent.environments.docker import DockerEnvironment
    from minisweagent.models import get_model
    from minisweagent.utils.serialize import recursive_merge

    iid = inst["instance_id"]
    inst_dir = out / iid
    inst_dir.mkdir(parents=True, exist_ok=True)
    rec: dict = {"instance_id": iid, "exit_status": None, "patch_bytes": 0, "error": None}
    t0 = time.time()

    config = recursive_merge(
        get_config_from_spec("mini"),
        {
            "agent": {
                "mode": "yolo",
                "confirm_exit": False,
                "cost_limit": args.cost_limit,
                "step_limit": args.step_limit,
                "wall_time_limit_seconds": args.time_limit,
                "output_path": str(inst_dir / f"{iid}.traj.json"),
            },
            "model": {"model_name": args.model},
        },
    )
    if args.api_base:
        config["model"].setdefault("model_kwargs", {})["api_base"] = args.api_base
    env_vars = dict(config.get("environment", {}).get("env", {}))

    env = DockerEnvironment(
        image=inst["image_name"],
        cwd="/testbed",
        env=env_vars,
        run_args=["--rm", "--network", "none", "--memory", args.memory, "--memory-swap", args.memory,
                  "--cpus", args.cpus],
        container_timeout=f"{args.time_limit + 1800}s",
        pull_timeout=args.pull_timeout,
    )
    agent = None
    try:
        base = env.execute({"command": "git rev-parse HEAD"})["output"].strip()
        if not base or base != inst["base_commit"]:
            raise RuntimeError(f"/testbed HEAD {base!r} != base_commit {inst['base_commit']!r}")
        model = get_model(config=config.get("model", {}))
        agent = get_agent(model, env, config.get("agent", {}), default_type="interactive")
        try:
            result = agent.run(INSTRUCTION.format(problem_statement=inst["problem_statement"]))
            rec["exit_status"] = result.get("exit_status")
        except Exception as e:  # keep going: the work done so far is still collected below
            rec["exit_status"] = type(e).__name__
            rec["error"] = "".join(traceback.format_exception_only(e)).strip()
        out_ = env.execute({"command": COLLECT.format(base=shlex.quote(base))}, timeout=300)
        patch = out_["output"] if out_["returncode"] == 0 else ""
        if out_["returncode"] != 0:
            rec["error"] = (rec["error"] or "") + f" | collect failed rc={out_['returncode']}"
        rec["patch_bytes"] = len(patch.encode())
        rec["cost"] = getattr(agent, "cost", None)
        rec["n_calls"] = getattr(agent, "n_calls", None)
        update_preds(out / "preds.json", iid, args.model, patch)
    except Exception as e:
        rec["exit_status"] = rec["exit_status"] or "RunnerError"
        rec["error"] = "".join(traceback.format_exception_only(e)).strip()
    finally:
        env.cleanup()
    rec["seconds"] = round(time.time() - t0, 1)
    (inst_dir / "run.json").write_text(json.dumps(rec, indent=2))
    return rec


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model", required=True, help="litellm model name, e.g. openai/deepseek-v4.1-flash")
    ap.add_argument("--api-base", default=None, help="OpenAI-compatible base URL (default: OPENAI_BASE_URL)")
    ap.add_argument("--dataset", type=Path, default=root / "data" / "swe-bench-promax.json")
    ap.add_argument("--instance-ids", type=Path, default=None, help="file with one instance id per line")
    ap.add_argument("--output", type=Path, required=True)
    ap.add_argument("--workers", type=int, default=1)
    ap.add_argument("--time-limit", type=int, default=7200, help="agent wall-clock limit per instance (s)")
    ap.add_argument("--step-limit", type=int, default=0, help="max agent steps; 0 = no limit (mini default)")
    ap.add_argument("--cost-limit", type=float, default=0.0, help="0 = no limit")
    ap.add_argument("--memory", default="12g", help="memory cap of the task container (same as test_run.py)")
    ap.add_argument("--cpus", default="4", help="CPU cap of the task container (same as test_run.py)")
    ap.add_argument("--pull-timeout", type=int, default=1800)
    ap.add_argument("--redo", action="store_true", help="rerun instances that already have a prediction")
    args = ap.parse_args()
    if args.api_base is None:
        args.api_base = os.environ.get("OPENAI_BASE_URL") or os.environ.get("OPENAI_API_BASE")
    os.environ.setdefault("MSWEA_CONFIGURED", "true")
    os.environ.setdefault("MSWEA_COST_TRACKING", "ignore_errors")

    args.output.mkdir(parents=True, exist_ok=True)
    instances = load_instances(args.dataset, args.instance_ids)
    preds_path = args.output / "preds.json"
    done = set(json.loads(preds_path.read_text())) if preds_path.exists() and not args.redo else set()
    todo = [x for x in instances if x["instance_id"] not in done]
    print(f"{len(instances)} instances, {len(done)} already done, running {len(todo)} with {args.workers} workers")

    with cf.ThreadPoolExecutor(args.workers) as pool:
        futs = {pool.submit(run_instance, x, args, args.output): x["instance_id"] for x in todo}
        for f in cf.as_completed(futs):
            r = f.result()
            print(f"{r['instance_id']}: {r['exit_status']} patch={r['patch_bytes']}B {r['seconds']}s"
                  + (f" error={r['error']}" if r.get("error") else ""), flush=True)
    print(f"predictions: {preds_path}")


if __name__ == "__main__":
    main()
