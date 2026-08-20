"""Build a Git-history-safe task image before exposing it to an agent."""

from __future__ import annotations

import argparse
import json
import shlex
import shutil
import subprocess
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
DEFAULT_DATASET = HERE.parents[1] / "data" / "swe-bench-promax.json"
SEAL_SCRIPT = HERE / "seal_git_history.sh"


def load_instance(dataset_path: Path, instance_id: str) -> dict:
    records = json.loads(dataset_path.read_text(encoding="utf-8"))
    matches = [row for row in records if row.get("instance_id") == instance_id]
    if len(matches) != 1:
        raise ValueError(
            f"expected one dataset row for {instance_id!r}, found {len(matches)}"
        )
    return matches[0]


def render_dockerfile(instance: dict, forbidden_commit: str | None = None) -> str:
    required = ("image_name", "working_dir", "base_commit")
    missing = [key for key in required if not instance.get(key)]
    if missing:
        raise ValueError(f"instance is missing required fields: {', '.join(missing)}")

    seal_values = [instance["working_dir"], instance["base_commit"]]
    if forbidden_commit:
        seal_values.append(forbidden_commit)
    seal_args = " ".join(shlex.quote(str(value)) for value in seal_values)
    return (
        f"FROM {instance['image_name']}\n"
        "COPY seal_git_history.sh /tmp/seal_git_history.sh\n"
        f"RUN bash /tmp/seal_git_history.sh {seal_args} \\\n"
        "    && rm -f /tmp/seal_git_history.sh\n"
    )


def build_image(
    instance: dict,
    output_tag: str,
    docker: str = "docker",
    forbidden_commit: str | None = None,
) -> None:
    if not SEAL_SCRIPT.is_file():
        raise FileNotFoundError(SEAL_SCRIPT)

    with tempfile.TemporaryDirectory(prefix="swe-bench-promax-seal-") as tmp:
        context = Path(tmp)
        shutil.copy2(SEAL_SCRIPT, context / SEAL_SCRIPT.name)
        (context / "Dockerfile").write_text(
            render_dockerfile(instance, forbidden_commit=forbidden_commit),
            encoding="utf-8",
        )
        subprocess.run(
            [docker, "build", "--pull", "-t", output_tag, str(context)],
            check=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Derive a task image that keeps Git history through base_commit "
            "and removes answer-bearing future commits. Run this before the "
            "image is exposed to an agent."
        )
    )
    parser.add_argument("instance_id", help="Exact dataset instance_id")
    parser.add_argument(
        "--dataset",
        type=Path,
        default=DEFAULT_DATASET,
        help=f"Dataset JSON (default: {DEFAULT_DATASET})",
    )
    parser.add_argument(
        "--tag",
        help=(
            "Output image tag (default: "
            "swe-bench-promax-sealed:<instance_id>)"
        ),
    )
    parser.add_argument("--docker", default="docker", help="Docker executable")
    parser.add_argument(
        "--forbidden-commit",
        help=(
            "Optional known answer-bearing commit to require in the source "
            "image and prove absent from the derived image."
        ),
    )
    args = parser.parse_args()

    instance = load_instance(args.dataset, args.instance_id)
    output_tag = args.tag or f"swe-bench-promax-sealed:{args.instance_id}"
    build_image(
        instance,
        output_tag,
        docker=args.docker,
        forbidden_commit=args.forbidden_commit,
    )

    print(json.dumps({
        "instance_id": args.instance_id,
        "source_image": instance["image_name"],
        "sealed_image": output_tag,
        "base_commit": instance["base_commit"],
        "working_dir": instance["working_dir"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
