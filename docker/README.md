# Task images

`data/swe-bench-promax.json` names one Docker image per instance. This directory holds what is needed to
rebuild those images from the original ones.

## What the build changes

1. **Upstream history newer than the base commit is removed** (`strip_future_history.sh`). The original
   images kept every branch and tag of the upstream clone, so `git log --all` / `git show <sha>` inside
   `/testbed` could reach the commit that fixed the issue (169 of 170 images exposed such commits; an
   agent was observed copying the fix this way). The script deletes every ref that is not an ancestor of
   `HEAD`, removes remotes, expires reflogs and prunes unreachable objects, in `/testbed` and in its
   submodules. `HEAD`, its history and the working tree are unchanged; the build fails if any commit
   outside `HEAD`'s history remains. The same approach is used by the official SWE-bench harness.
   Repositories whose working tree shows mode-only changes (the original build ran `chmod` on the whole
   tree) get `core.fileMode=false`, so `git status` / `git diff` show only real edits.
2. **Offline test dependencies are baked in for 11 instances** (`warmup/`): six Angular instances download
   Bazel at test time, and four PlantUML and one Hibernate instance miss Gradle jars that
   `gradlew --offline` needs. Their image runs the instance's own eval script once at build time with the
   empty patch and network on, then removes everything that run created under `/testbed`.

Every image passes the reference patch and fails the empty patch with `src/evaluation/test_run.py`
under `--network none`.

3. **Build-site HTTP proxy settings are cleared** from the image ENV (some original images carried an
   unreachable proxy), the working directory is `/testbed`, and `/logs` exists (used by Harbor).

4. **`git status` is clean in a fresh container.** The image's own untracked files are listed in
   `.git/info/exclude` (19 images ship build outputs or generated files), and the image's own edits to
   tracked files are marked skip-worktree (2 Bazel images rewrite `.bazelversion`). A candidate patch
   collected with `git add -A` / `git diff` then contains only what the agent changed.

5. **Agent install prerequisites for 15 images** (`Dockerfile.agent-deps`, list in `agent_deps.txt`).
   Agents that install themselves inside the task container (Harbor's `mini-swe-agent`, `codex`,
   `claude-code`, ...) need `curl`, `bash`, `git`, `gcc` and `make`, and fall back to `apt-get install`
   when one is missing. 12 images (11 C/C++, 1 Go) lacked `curl` and 3 Java images lacked `gcc`/`make`; they get those
   packages, nothing else. All Go images already had `gcc`, so cgo defaults are unchanged.

## Rebuild

```bash
bash docker/build_images.sh <your-repo>                  # all instances
bash docker/build_images.sh <your-repo> <instance_id>    # some instances
bash docker/check_images.sh <your-repo>                  # HEAD == base commit, no newer commits
```

Builds run one at a time with the classic builder: with Docker 20.10's built-in BuildKit, building
several tags of the same local repository at once can resolve `FROM` to the wrong tag.
