from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SEAL_SCRIPT = REPO_ROOT / "src" / "evaluation" / "seal_git_history.sh"


class SealGitHistoryTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="promax-seal-test-")
        self.tmp = Path(self._tmp.name)
        self.repo = self.tmp / "repo"
        self.repo.mkdir()

        self._run("git", "init", "-q", "-b", "benchmark-base", str(self.repo))
        self.git("config", "user.name", "Test Author")
        self.git("config", "user.email", "test@example.invalid")

        (self.repo / "tracked.txt").write_text("root\n", encoding="utf-8")
        (self.repo / "nested" / "work").mkdir(parents=True)
        (self.repo / "nested" / "work" / "context.txt").write_text(
            "root context\n", encoding="utf-8"
        )
        self.git("add", "tracked.txt", "nested/work/context.txt")
        self.git("commit", "-q", "-m", "root")
        self.root_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.git("tag", "-a", "v1.0", "-m", "safe base tag")

        (self.repo / "tracked.txt").write_text("root\nbase\n", encoding="utf-8")
        self.git("add", "tracked.txt")
        self.git("commit", "-q", "-m", "benchmark base")
        self.base_commit = self.git("rev-parse", "HEAD").stdout.strip()

        self.git("switch", "-q", "-c", "future-answer")
        (self.repo / "answer.txt").write_text("gold answer\n", encoding="utf-8")
        self.git("add", "answer.txt")
        self.git("commit", "-q", "-m", "answer-bearing descendant")
        self.forbidden_commit = self.git("rev-parse", "HEAD").stdout.strip()
        self.git("tag", "-a", "v2.0", "-m", "future answer tag")
        self.git("switch", "-q", "benchmark-base")

        # An evaluator image can legitimately contain both dirty tracked files
        # and untracked build/dependency artifacts. Sealing history must not
        # mutate either category.
        with (self.repo / "tracked.txt").open("a", encoding="utf-8") as handle:
            handle.write("dirty image customization\n")
        (self.repo / "untracked-cache.bin").write_bytes(b"cached dependency\x00")

        # Exercise a task whose configured working directory reaches the
        # repository through a symlink rather than naming its root directly.
        self.working_dir_alias = self.tmp / "task-working-dir"
        self.working_dir_alias.symlink_to(self.repo / "nested" / "work", target_is_directory=True)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    @staticmethod
    def _run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            check=check,
            capture_output=True,
            text=True,
        )

    def git(self, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return self._run("git", "-C", str(self.repo), *args, check=check)

    def seal(self) -> subprocess.CompletedProcess[str]:
        result = self._run(
            "bash",
            str(SEAL_SCRIPT),
            str(self.working_dir_alias),
            self.base_commit,
            self.forbidden_commit,
            check=False,
        )
        self.assertEqual(
            result.returncode,
            0,
            msg=f"seal failed\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )
        return result

    def _assert_common_postconditions(self, before_status: str, before_describe: str) -> None:
        self.assertEqual(self.git("rev-parse", "HEAD").stdout.strip(), self.base_commit)

        retained = set(self.git("rev-list", "--all").stdout.splitlines())
        self.assertEqual(retained, {self.root_commit, self.base_commit})

        forbidden = self.git(
            "cat-file", "-e", f"{self.forbidden_commit}^{{commit}}", check=False
        )
        self.assertNotEqual(forbidden.returncode, 0)

        self.assertEqual(
            self.git("status", "--porcelain=v1", "--untracked-files=all").stdout,
            before_status,
        )
        self.assertEqual(
            self.git("describe", "--tags", "--always", "--dirty").stdout.strip(),
            before_describe,
        )
        self.assertEqual(
            (self.repo / "tracked.txt").read_text(encoding="utf-8"),
            "root\nbase\ndirty image customization\n",
        )
        self.assertEqual(
            (self.repo / "untracked-cache.bin").read_bytes(),
            b"cached dependency\x00",
        )
        self.assertEqual(self.git("tag", "--list").stdout.splitlines(), ["v1.0"])
        self.assertEqual(self.git("remote").stdout, "")
        self.assertEqual(
            self.git("fsck", "--full", "--no-reflogs", "--unreachable").stdout,
            "",
        )

    def test_seals_descendant_history_without_changing_branch_or_worktree(self) -> None:
        before_status = self.git(
            "status", "--porcelain=v1", "--untracked-files=all"
        ).stdout
        before_describe = self.git(
            "describe", "--tags", "--always", "--dirty"
        ).stdout.strip()
        before_branch = self.git("symbolic-ref", "--short", "HEAD").stdout.strip()

        result = self.seal()

        self.assertIn("SWE_BENCH_PROMAX_HISTORY_SEALED=1", result.stdout)
        self.assertEqual(
            self.git("symbolic-ref", "--short", "HEAD").stdout.strip(),
            before_branch,
            "sealing must preserve the task image's original branch name",
        )
        self._assert_common_postconditions(before_status, before_describe)

    def test_seals_descendant_history_without_attaching_detached_head(self) -> None:
        self.git("checkout", "-q", "--detach", self.base_commit)
        self.assertNotEqual(
            self.git("symbolic-ref", "-q", "HEAD", check=False).returncode,
            0,
        )
        before_status = self.git(
            "status", "--porcelain=v1", "--untracked-files=all"
        ).stdout
        before_describe = self.git(
            "describe", "--tags", "--always", "--dirty"
        ).stdout.strip()

        self.seal()

        self.assertNotEqual(
            self.git("symbolic-ref", "-q", "HEAD", check=False).returncode,
            0,
            "a detached task image must remain detached after sealing",
        )
        self._assert_common_postconditions(before_status, before_describe)


class RecursiveSubmoduleSealTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="promax-submodule-seal-test-")
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    @staticmethod
    def _run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            args,
            check=check,
            capture_output=True,
            text=True,
        )

    def git(
        self, repo: Path, *args: str, check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        return self._run("git", "-C", str(repo), *args, check=check)

    def initialize_repo(self, path: Path) -> None:
        path.mkdir()
        self._run("git", "init", "-q", "-b", "benchmark-base", str(path))
        self.git(path, "config", "user.name", "Test Author")
        self.git(path, "config", "user.email", "test@example.invalid")

    def test_recursively_seals_initialized_submodule_history(self) -> None:
        sub_source = self.tmp / "sub-source"
        self.initialize_repo(sub_source)
        (sub_source / "library.txt").write_text("root\n", encoding="utf-8")
        self.git(sub_source, "add", "library.txt")
        self.git(sub_source, "commit", "-q", "-m", "submodule root")
        sub_root = self.git(sub_source, "rev-parse", "HEAD").stdout.strip()
        (sub_source / "library.txt").write_text("root\nbase\n", encoding="utf-8")
        self.git(sub_source, "add", "library.txt")
        self.git(sub_source, "commit", "-q", "-m", "submodule base")
        sub_base = self.git(sub_source, "rev-parse", "HEAD").stdout.strip()
        self.git(sub_source, "switch", "-q", "-c", "future-answer")
        (sub_source / "answer.txt").write_text("submodule answer\n", encoding="utf-8")
        self.git(sub_source, "add", "answer.txt")
        self.git(sub_source, "commit", "-q", "-m", "submodule future answer")
        sub_forbidden = self.git(sub_source, "rev-parse", "HEAD").stdout.strip()
        self.git(sub_source, "switch", "-q", "benchmark-base")

        super_repo = self.tmp / "super"
        self.initialize_repo(super_repo)
        (super_repo / "README.md").write_text("super root\n", encoding="utf-8")
        self.git(super_repo, "add", "README.md")
        self.git(super_repo, "commit", "-q", "-m", "super root")
        super_root = self.git(super_repo, "rev-parse", "HEAD").stdout.strip()
        self.git(
            super_repo,
            "-c",
            "protocol.file.allow=always",
            "submodule",
            "add",
            "-q",
            str(sub_source),
            "deps/library",
        )
        self.git(super_repo, "commit", "-q", "-am", "add pinned submodule")
        super_base = self.git(super_repo, "rev-parse", "HEAD").stdout.strip()
        self.git(super_repo, "switch", "-q", "-c", "future-answer")
        (super_repo / "answer.txt").write_text("super answer\n", encoding="utf-8")
        self.git(super_repo, "add", "answer.txt")
        self.git(super_repo, "commit", "-q", "-m", "super future answer")
        super_forbidden = self.git(super_repo, "rev-parse", "HEAD").stdout.strip()
        self.git(super_repo, "switch", "-q", "benchmark-base")

        sub_worktree = super_repo / "deps" / "library"
        # A normal submodule clone has the source's future branch as a remote
        # ref, so the answer-bearing commit is exposed before sealing.
        self.assertEqual(
            self.git(sub_worktree, "rev-parse", "HEAD").stdout.strip(), sub_base
        )
        self.assertEqual(
            self.git(
                sub_worktree,
                "cat-file",
                "-e",
                f"{sub_forbidden}^{{commit}}",
                check=False,
            ).returncode,
            0,
        )
        (sub_worktree / "untracked-build-cache").write_text(
            "keep me\n", encoding="utf-8"
        )
        submodule_config_before = self.git(
            super_repo, "config", "--local", "--get-regexp", "^submodule\\."
        ).stdout

        sealed = self._run(
            "bash",
            str(SEAL_SCRIPT),
            str(super_repo),
            super_base,
            super_forbidden,
            check=False,
        )
        self.assertEqual(
            sealed.returncode,
            0,
            msg=f"seal failed\nstdout:\n{sealed.stdout}\nstderr:\n{sealed.stderr}",
        )

        self.assertEqual(
            set(self.git(super_repo, "rev-list", "--all").stdout.splitlines()),
            {super_root, super_base},
        )
        self.assertNotEqual(
            self.git(
                super_repo,
                "cat-file",
                "-e",
                f"{super_forbidden}^{{commit}}",
                check=False,
            ).returncode,
            0,
        )
        self.assertEqual(
            self.git(sub_worktree, "rev-parse", "HEAD").stdout.strip(), sub_base
        )
        self.assertEqual(
            set(self.git(sub_worktree, "rev-list", "--all").stdout.splitlines()),
            {sub_root, sub_base},
        )
        self.assertNotEqual(
            self.git(
                sub_worktree,
                "cat-file",
                "-e",
                f"{sub_forbidden}^{{commit}}",
                check=False,
            ).returncode,
            0,
        )
        self.assertEqual(self.git(sub_worktree, "remote").stdout, "")
        self.assertEqual(
            (sub_worktree / "untracked-build-cache").read_text(encoding="utf-8"),
            "keep me\n",
        )
        self.assertEqual(
            self.git(
                super_repo,
                "config",
                "--local",
                "--get-regexp",
                "^submodule\\.",
                check=False,
            ).stdout,
            submodule_config_before,
            "sealing must preserve initialized-submodule registration",
        )
        submodule_status = self.git(
            super_repo, "submodule", "status", "--recursive"
        ).stdout
        self.assertTrue(
            submodule_status.startswith(" "),
            msg=f"submodule no longer initialized after sealing: {submodule_status!r}",
        )


if __name__ == "__main__":
    unittest.main()
