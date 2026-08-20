from __future__ import annotations

import importlib.util
import json
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "src" / "evaluation" / "test_run.py"


def load_module():
    spec = importlib.util.spec_from_file_location("promax_test_run", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


test_run = load_module()


class ImageMapSelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="promax-image-map-test-")
        self.tmp = Path(self._tmp.name)
        self.pred = self._write_json(
            "pred.json",
            [
                {
                    "instance_id": "task-a",
                    "model_patch": "model patch",
                    # Prediction files are untrusted submissions and must not
                    # be able to select an answer-bearing task image.
                    "image_name": "attacker.example/leaky:gold-answer",
                }
            ],
        )
        self.golden = self._write_json(
            "golden.json",
            [
                {
                    "instance_id": "task-a",
                    "patch": "gold patch",
                    "image_name": "maintainer.example/public:task-a",
                    "language": "python",
                    "repo": "owner/repo",
                    "base_commit": "0123456789abcdef0123456789abcdef01234567",
                    "working_dir": "/workspace/project",
                }
            ],
        )
        self.eval = self._write_json(
            "eval.json", {"task-a": {"eval_script": "exit 0"}}
        )
        self.output = self.tmp / "result.json"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def _write_json(self, name: str, value) -> Path:
        path = self.tmp / name
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    @staticmethod
    def _fake_result(job):
        return (
            job[0],
            {
                "instance_id": job[0],
                "language": job[5],
                "passed": True,
                "model": {"final_result": "success"},
                "golden": {"final_result": "success"},
            },
        )

    def _run_and_capture_job(self, image_map_path=None, **stat_kwargs):
        captured = []

        def process(job):
            captured.append(job)
            return self._fake_result(job)

        with (
            mock.patch.object(test_run, "_process_one_instance", side_effect=process),
            mock.patch.object(test_run, "print_pass_rate_summary"),
        ):
            test_run.stat_pass_rate(
                self.pred,
                self.golden,
                self.eval,
                self.output,
                workers=1,
                image_map_path=image_map_path,
                **stat_kwargs,
            )
        self.assertEqual(len(captured), 1)
        return captured[0]

    def test_prediction_image_field_cannot_override_evaluator_dataset_image(self) -> None:
        job = self._run_and_capture_job()

        self.assertEqual(job[-1], "maintainer.example/public:task-a")
        self.assertNotEqual(job[-1], "attacker.example/leaky:gold-answer")

    def test_evaluator_owned_image_map_overrides_public_and_prediction_images(self) -> None:
        image_map = self._write_json(
            "image-map.json", {"task-a": "evaluator.example/sealed:task-a"}
        )

        job = self._run_and_capture_job(image_map)

        self.assertEqual(job[-1], "evaluator.example/sealed:task-a")

    def test_image_map_must_be_a_json_object(self) -> None:
        image_map = self._write_json("image-map.json", ["not", "a", "mapping"])

        with self.assertRaisesRegex(ValueError, "JSON object"):
            self._run_and_capture_job(image_map)

    def test_supplied_image_map_must_cover_every_evaluated_prediction(self) -> None:
        image_map = self._write_json("image-map.json", {})

        with self.assertRaisesRegex(ValueError, "task-a"):
            self._run_and_capture_job(image_map)

    def test_require_sealed_history_carries_dataset_coordinates_into_job(self) -> None:
        image_map = self._write_json(
            "image-map.json", {"task-a": "evaluator.example/sealed:task-a"}
        )

        job = self._run_and_capture_job(
            image_map,
            local_images_only=True,
            require_sealed_history=True,
        )

        self.assertEqual(job[7], "0123456789abcdef0123456789abcdef01234567")
        self.assertEqual(job[8], "/workspace/project")
        self.assertTrue(job[9])
        self.assertTrue(job[10])


class EvaluatorImageSafetyTests(unittest.TestCase):
    image_name = "evaluator.example/sealed:task-a"
    base_commit = "0123456789abcdef0123456789abcdef01234567"
    working_dir = "/workspace/project"

    def make_job(
        self,
        *,
        local_images_only: bool,
        require_sealed_history: bool = False,
        cleanup: bool = False,
    ):
        return (
            "task-a",
            {"instance_id": "task-a", "model_patch": "model patch"},
            "exit 0",
            "gold patch",
            cleanup,
            "python",
            "owner/repo",
            self.base_commit,
            self.working_dir,
            local_images_only,
            require_sealed_history,
            self.image_name,
        )

    @staticmethod
    def successful_patch_result():
        return (
            {
                "is_passed": True,
                "reason": "SUCCESS",
                "stdout": "tests passed",
                "stderr": "",
                "returncode": 0,
                "script_exit_code": 0,
                "apply_err": "",
            },
            None,
            False,
            True,
        )

    def test_local_only_missing_image_fails_without_attempting_pull(self) -> None:
        with (
            mock.patch.object(test_run, "_local_image_exists", return_value=False),
            mock.patch.object(test_run, "run_command") as run_command,
            mock.patch.object(test_run, "_local_image_id") as local_image_id,
        ):
            with self.assertRaisesRegex(RuntimeError, "local-images-only.*missing"):
                test_run._process_one_instance(
                    self.make_job(local_images_only=True)
                )

        run_command.assert_not_called()
        local_image_id.assert_not_called()

    def test_nonzero_pull_fails_before_image_inspection_or_execution(self) -> None:
        pull_failure = subprocess.CompletedProcess(
            "docker pull", 1, stdout="", stderr="registry denied"
        )
        with (
            mock.patch.object(
                test_run, "run_command", return_value=(pull_failure, False)
            ) as run_command,
            mock.patch.object(test_run, "_local_image_id") as local_image_id,
            mock.patch.object(test_run, "_run_single_patch_with_retry") as run_patch,
        ):
            with self.assertRaisesRegex(RuntimeError, "failed to pull.*registry denied"):
                test_run._process_one_instance(
                    self.make_job(local_images_only=False)
                )

        self.assertIn(
            f"docker pull {self.image_name}", run_command.call_args.args[0]
        )
        local_image_id.assert_not_called()
        run_patch.assert_not_called()

    def test_sealed_verification_uses_dataset_coordinates_and_result_records_image(self) -> None:
        image_id = "sha256:1234567890abcdef"
        with (
            mock.patch.object(test_run, "_local_image_exists", return_value=True),
            mock.patch.object(test_run, "_local_image_id", return_value=image_id),
            mock.patch.object(test_run, "_verify_sealed_history") as verify,
            mock.patch.object(
                test_run,
                "_run_single_patch_with_retry",
                return_value=self.successful_patch_result(),
            ) as run_patch,
        ):
            instance_id, result = test_run._process_one_instance(
                self.make_job(
                    local_images_only=True,
                    require_sealed_history=True,
                )
            )

        self.assertEqual(instance_id, "task-a")
        verify.assert_called_once_with(
            image_id, self.working_dir, self.base_commit
        )
        self.assertEqual(
            [call.args[1] for call in run_patch.call_args_list],
            [image_id, image_id],
        )
        self.assertEqual(
            result["image"],
            {
                "name": self.image_name,
                "id": image_id,
                "history_sealed": True,
            },
        )

    def test_verify_sealed_history_runs_ephemeral_container_with_expected_checks(self) -> None:
        success = subprocess.CompletedProcess("docker run", 0, stdout="", stderr="")
        with mock.patch.object(
            test_run, "run_command", return_value=(success, False)
        ) as run_command:
            test_run._verify_sealed_history(
                self.image_name, self.working_dir, self.base_commit
            )

        command = run_command.call_args.args[0]
        self.assertEqual(run_command.call_args.kwargs, {"timeout": 120})
        argv = shlex.split(command)
        self.assertEqual(
            argv[:6],
            [
                "docker",
                "run",
                "--rm",
                "--entrypoint",
                "bash",
                self.image_name,
            ],
        )
        self.assertEqual(argv[6], "-lc")
        verifier_script = argv[7]
        self.assertIn(f"working_dir={self.working_dir}", verifier_script)
        self.assertIn(f"expected_base={self.base_commit}", verifier_script)
        self.assertIn("swe-bench-promax-history-seal", verifier_script)
        self.assertIn("rev-list --all --not", verifier_script)
        self.assertIn("submodule foreach", verifier_script)

    def test_verify_sealed_history_propagates_failed_check(self) -> None:
        failure = subprocess.CompletedProcess(
            "docker run", 1, stdout="", stderr="marker missing"
        )
        with mock.patch.object(
            test_run, "run_command", return_value=(failure, False)
        ):
            with self.assertRaisesRegex(
                RuntimeError, "sealed-history verification failed.*marker missing"
            ):
                test_run._verify_sealed_history(
                    self.image_name, self.working_dir, self.base_commit
                )


if __name__ == "__main__":
    unittest.main()
