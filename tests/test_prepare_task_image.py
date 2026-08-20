from __future__ import annotations

import importlib.util
import json
import shlex
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "src" / "evaluation" / "prepare_task_image.py"


def load_module():
    spec = importlib.util.spec_from_file_location("promax_prepare_task_image", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare_task_image = load_module()


class PrepareTaskImageTests(unittest.TestCase):
    def test_render_dockerfile_uses_source_image_and_shell_quotes_seal_arguments(self) -> None:
        instance = {
            "instance_id": "owner__repo-c_deadbeef",
            "image_name": "registry.example/promax/task@sha256:abc123",
            "working_dir": "/workspace/it's a repo",
            "base_commit": "0123456789abcdef",
        }

        rendered = prepare_task_image.render_dockerfile(instance)

        expected_args = " ".join(
            shlex.quote(instance[key]) for key in ("working_dir", "base_commit")
        )
        self.assertTrue(rendered.startswith(f"FROM {instance['image_name']}\n"))
        self.assertIn(
            f"RUN bash /tmp/seal_git_history.sh {expected_args} \\\n",
            rendered,
        )
        self.assertIn("COPY seal_git_history.sh /tmp/seal_git_history.sh\n", rendered)
        self.assertTrue(rendered.endswith("&& rm -f /tmp/seal_git_history.sh\n"))

    def test_render_dockerfile_rejects_missing_or_empty_required_fields(self) -> None:
        complete = {
            "image_name": "registry.example/task:latest",
            "working_dir": "/testbed",
            "base_commit": "deadbeef",
        }
        for missing_key in complete:
            with self.subTest(missing_key=missing_key):
                instance = complete.copy()
                instance[missing_key] = ""
                with self.assertRaisesRegex(ValueError, missing_key):
                    prepare_task_image.render_dockerfile(instance)

    def test_load_instance_requires_exactly_one_matching_dataset_row(self) -> None:
        with tempfile.TemporaryDirectory(prefix="promax-data-test-") as tmp:
            dataset = Path(tmp) / "dataset.json"
            rows = [
                {"instance_id": "task-a", "image_name": "a"},
                {"instance_id": "task-b", "image_name": "b"},
            ]
            dataset.write_text(json.dumps(rows), encoding="utf-8")

            self.assertEqual(
                prepare_task_image.load_instance(dataset, "task-b"), rows[1]
            )
            with self.assertRaisesRegex(ValueError, "found 0"):
                prepare_task_image.load_instance(dataset, "missing")

            rows.append(dict(rows[1]))
            dataset.write_text(json.dumps(rows), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "found 2"):
                prepare_task_image.load_instance(dataset, "task-b")

    def test_build_image_uses_an_isolated_context_and_pull_enabled_build(self) -> None:
        instance = {
            "image_name": "registry.example/task:source",
            "working_dir": "/testbed",
            "base_commit": "deadbeef",
        }
        observed = {}

        def inspect_build(command, check):
            context = Path(command[-1])
            observed["command"] = command
            observed["check"] = check
            observed["dockerfile"] = (context / "Dockerfile").read_text(
                encoding="utf-8"
            )
            observed["seal_script"] = (context / "seal_git_history.sh").read_text(
                encoding="utf-8"
            )

        with mock.patch.object(
            prepare_task_image.subprocess, "run", side_effect=inspect_build
        ):
            prepare_task_image.build_image(
                instance, "promax-sealed:task-a", docker="docker-test"
            )

        self.assertEqual(
            observed["command"][:5],
            ["docker-test", "build", "--pull", "-t", "promax-sealed:task-a"],
        )
        self.assertTrue(observed["check"])
        self.assertEqual(
            observed["dockerfile"], prepare_task_image.render_dockerfile(instance)
        )
        self.assertIn("SWE_BENCH_PROMAX_HISTORY_SEALED", observed["seal_script"])


if __name__ == "__main__":
    unittest.main()
