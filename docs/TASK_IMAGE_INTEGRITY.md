# Task image Git-history integrity

## Why this matters

Checking out a repository at `base_commit` does not ensure that a benchmark
agent sees only information available at that commit. Descendant commits may
remain in local branches, tags, reflogs, alternate object stores, submodule Git
directories, or as unreachable objects. Those objects are directly searchable
with standard Git commands and may contain the reference solution.

The integrity boundary is therefore **before agent inference**:

1. Start from the evaluator-owned task image declared by the dataset.
2. Derive and inspect a history-sealed image.
3. Run the agent in that image.
4. Evaluate its patch in the same image selected by the evaluator.

Changing the image only after a prediction has been produced does not repair a
contaminated trajectory.

## What the preparation utility does

`src/evaluation/prepare_task_image.py` adds a build layer that runs
`seal_git_history.sh`. For the main repository and each initialized submodule,
the script:

- resolves the real Git root instead of assuming `/testbed`;
- requires `HEAD` to equal the dataset's base commit (or submodule gitlink);
- records the checked-out tree and dirty tracked-worktree fingerprint;
- clones only the base branch and its ancestors into a replacement Git database;
- preserves the nearest tag reachable from the base for `git describe --tags`;
- removes remotes, reflogs, alternates, replace refs, promisor state, descendant
  commits, and unreachable objects;
- preserves the original attached/detached HEAD state, selected safe Git config,
  sparse-checkout files, untracked/ignored assets, and initialized submodules;
- swaps Git directories with rollback and checks every postcondition before
  writing a seal marker.

The script never runs `git checkout`, `git reset --hard`, or `git clean` against
the task worktree. Existing build products and image-specific tracked changes
remain in place. The index is reset to the base, so an existing staged change
becomes an ordinary unstaged worktree change without changing its bytes.

## Evaluation controls

`test_run.py --image-map` accepts an evaluator-owned JSON object keyed by exact
`instance_id`. If the map is present, every evaluated prediction must have an
entry. Image-like fields in prediction rows are ignored.

Use both of these options for locally derived images:

- `--local-images-only`: never pull or silently fall back to another tag;
- `--require-sealed-history`: check the marker, base commit, exposed refs,
  unreachable objects, remotes, and recursively initialized submodules before
  applying either patch.

Each result records the selected image name and local Docker image ID.

## Publishing repaired images

The preparation helper hides the source image's old Git database from an
ordinary unprivileged task container. Because Docker layers are immutable, the
old bytes still exist in lower image layers. Agents must not receive the Docker
socket, host filesystem, or image-layer export access.

For a benchmark release, prefer rebuilding or squashing the prepared images,
publishing versioned immutable digests, and updating the evaluator-owned image
metadata. Run the reference patch and environment checks for every rebuilt
image before changing the public image map.

Model-created commits after launch are valid. Extract a submitted patch against
the immutable dataset `base_commit`, not against `HEAD`, or a committed solution
will appear as an empty diff.
