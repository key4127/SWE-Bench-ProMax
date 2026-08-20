#!/usr/bin/env bash

# Seal a task repository before an agent sees it. The replacement Git database
# contains BASE_COMMIT and its ancestors, but none of the answer-bearing future
# history that may be present in a published task image. The worktree itself is
# never checked out, reset, or cleaned.

set -euo pipefail

usage() {
  echo "usage: $0 WORKING_DIR BASE_COMMIT [FORBIDDEN_COMMIT]" >&2
  exit 2
}

die() {
  echo "seal_git_history: $*" >&2
  exit 1
}

test "$#" -ge 2 && test "$#" -le 3 || usage

working_dir=$1
base_input=$2
forbidden_input=${3:-}
write_marker=${PROMAX_SEAL_WRITE_MARKER:-1}
marker_path=${PROMAX_SEAL_MARKER:-}
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
script_path="$script_dir/$(basename -- "$0")"

case "$base_input" in
  *[!0-9a-fA-F]*|'') die "base commit must be a hexadecimal Git object ID" ;;
esac

repo_root=$(git -C "$working_dir" rev-parse --show-toplevel)
repo_root=$(CDPATH='' cd -- "$repo_root" && pwd -P)
base=$(git -C "$repo_root" rev-parse --verify "$base_input^{commit}")
test "$(git -C "$repo_root" rev-parse HEAD)" = "$base" || \
  die "HEAD does not equal base commit in $repo_root"

git_dir=$(git -C "$repo_root" rev-parse --absolute-git-dir 2>/dev/null || true)
if test -z "$git_dir"; then
  git_dir=$(git -C "$repo_root" rev-parse --git-dir)
  case "$git_dir" in
    /*) ;;
    *) git_dir="$repo_root/$git_dir" ;;
  esac
fi
git_dir=$(CDPATH='' cd -- "$git_dir" && pwd -P)

# Refuse linked worktrees and arbitrary external Git directories. A normal
# repository owns ROOT/.git; an initialized submodule has a .git file whose
# target lives below its superproject's .git/modules directory.
if test -d "$repo_root/.git"; then
  expected_git_dir=$(CDPATH='' cd -- "$repo_root/.git" && pwd -P)
  test "$git_dir" = "$expected_git_dir" || die "unexpected Git directory"
elif test -f "$repo_root/.git"; then
  gitfile_target=$(sed -n 's/^gitdir: //p' "$repo_root/.git")
  test -n "$gitfile_target" || die "invalid submodule .git file"
  case "$gitfile_target" in
    /*) ;;
    *) gitfile_target="$repo_root/$gitfile_target" ;;
  esac
  expected_git_dir=$(CDPATH='' cd -- "$gitfile_target" && pwd -P)
  test "$git_dir" = "$expected_git_dir" || die "unexpected submodule Git directory"
  case "$git_dir" in
    */.git/modules/*) ;;
    *) die "external Git directory is not a submodule Git directory" ;;
  esac
else
  die "repository has neither a .git directory nor a submodule .git file"
fi
if test -z "$marker_path"; then
  marker_path="$git_dir/swe-bench-promax-history-seal"
fi

original_head_ref=$(git -C "$repo_root" symbolic-ref -q HEAD || true)
original_tree=$(git -C "$repo_root" rev-parse "$base^{tree}")
tracked_before=$(
  git -C "$repo_root" diff --no-ext-diff --ignore-submodules=all \
    --binary "$base" -- | git -C "$repo_root" hash-object --stdin
)
base_describe=$(git -C "$repo_root" describe --tags --long "$base" 2>/dev/null || true)
base_tag=$(git -C "$repo_root" describe --tags --abbrev=0 "$base" 2>/dev/null || true)
describe_abbrev=''
if test -n "$base_describe"; then
  describe_suffix=${base_describe##*-g}
  describe_abbrev=${#describe_suffix}
fi

forbidden=''
if test -n "$forbidden_input"; then
  forbidden=$(git -C "$repo_root" rev-parse --verify "$forbidden_input^{commit}") || \
    die "forbidden commit does not exist in the source image"
  test "$forbidden" != "$base" || die "forbidden commit equals base commit"
fi

seal_tmp=$(mktemp -d /tmp/swe-bench-promax-seal.XXXXXX)
swap_started=0
swap_committed=0
temp_ref="refs/heads/swe-bench-promax-seal-$$"

cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  if test "$swap_started" = 1 && test "$swap_committed" = 0; then
    # Restore the exact original Git database if any post-swap assertion fails.
    if test -d "$git_dir/modules" && test -d "$seal_tmp/original.git"; then
      mv "$git_dir/modules" "$seal_tmp/original.git/modules"
    fi
    if test -e "$git_dir"; then
      mv "$git_dir" "$seal_tmp/failed.git"
    fi
    if test -d "$seal_tmp/original.git"; then
      mv "$seal_tmp/original.git" "$git_dir"
    fi
  fi
  git -C "$repo_root" update-ref -d "$temp_ref" >/dev/null 2>&1 || true
  rm -rf "$seal_tmp"
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM

# Recursively seal initialized submodules first. Each child is pinned to the
# gitlink recorded by its immediate superproject. Uninitialized submodules have
# no exposed object database and need no work.
if test -f "$repo_root/.gitmodules"; then
  export PROMAX_SEAL_SCRIPT="$script_path"
  # shellcheck disable=SC2016  # Expanded by `git submodule foreach`.
  git -C "$repo_root" submodule foreach --quiet '
    test "$(git rev-parse HEAD)" = "$sha1" || {
      echo "initialized submodule $displaypath is not at gitlink $sha1" >&2
      exit 1
    }
    PROMAX_SEAL_WRITE_MARKER=0 \
      bash "$PROMAX_SEAL_SCRIPT" "$toplevel/$sm_path" "$sha1"
  '
fi

git -C "$repo_root" update-ref "$temp_ref" "$base"
temp_branch=${temp_ref#refs/heads/}
git -c protocol.file.allow=always clone --quiet --no-tags \
  --single-branch --branch "$temp_branch" --no-checkout \
  "file://$repo_root" "$seal_tmp/repo"
git -C "$repo_root" update-ref -d "$temp_ref"

# Preserve the nearest tag reachable from BASE, including annotated-tag
# metadata. This keeps common build-time `git describe --tags` behavior while
# excluding tags and commits created after BASE.
if test -n "$base_tag"; then
  git -c protocol.file.allow=always -C "$seal_tmp/repo" fetch --quiet \
    --no-tags "file://$repo_root" \
    "refs/tags/$base_tag:refs/tags/$base_tag"
fi

# Preserve safe repository behavior that a fresh clone does not inherit.
core_filemode=$(git -C "$repo_root" config --local --get core.filemode || true)
core_ignorecase=$(git -C "$repo_root" config --local --get core.ignorecase || true)
core_symlinks=$(git -C "$repo_root" config --local --get core.symlinks || true)
core_autocrlf=$(git -C "$repo_root" config --local --get core.autocrlf || true)
core_eol=$(git -C "$repo_root" config --local --get core.eol || true)
core_sparse=$(git -C "$repo_root" config --local --get core.sparseCheckout || true)
core_sparse_cone=$(git -C "$repo_root" config --local --get core.sparseCheckoutCone || true)
core_worktree=$(git -C "$repo_root" config --local --get core.worktree || true)
mkdir -p "$seal_tmp/info"
if test -f "$git_dir/info/exclude"; then
  cp "$git_dir/info/exclude" "$seal_tmp/info/exclude"
fi
if test -f "$git_dir/info/sparse-checkout"; then
  cp "$git_dir/info/sparse-checkout" "$seal_tmp/info/sparse-checkout"
fi
git -C "$repo_root" config --local --get-regexp \
  '(^submodule\..*\.(url|active|update|branch|ignore)$)|(^submodule\.active$)' \
  > "$seal_tmp/submodule-config" 2>/dev/null || true

# Swap with rollback instead of deleting the original database. Initialized
# submodule databases have already been sealed and are re-homed intact.
mv "$git_dir" "$seal_tmp/original.git"
swap_started=1
mv "$seal_tmp/repo/.git" "$git_dir"
if test -d "$seal_tmp/original.git/modules"; then
  mv "$seal_tmp/original.git/modules" "$git_dir/modules"
fi

git -C "$repo_root" remote remove origin
git -C "$repo_root" reset --mixed "$base" >/dev/null

if test -n "$original_head_ref"; then
  git -C "$repo_root" update-ref "$original_head_ref" "$base"
  git -C "$repo_root" symbolic-ref HEAD "$original_head_ref"
else
  printf '%s\n' "$base" > "$git_dir/HEAD"
fi
git -C "$repo_root" update-ref -d "refs/heads/$temp_branch"

for ref in $(git -C "$repo_root" for-each-ref --format='%(refname)' refs/remotes); do
  git -C "$repo_root" update-ref -d "$ref"
done

set_config_if_present() {
  key=$1
  value=$2
  if test -n "$value"; then
    git -C "$repo_root" config --local "$key" "$value"
  fi
}
set_config_if_present core.filemode "$core_filemode"
set_config_if_present core.ignorecase "$core_ignorecase"
set_config_if_present core.symlinks "$core_symlinks"
set_config_if_present core.autocrlf "$core_autocrlf"
set_config_if_present core.eol "$core_eol"
set_config_if_present core.sparseCheckout "$core_sparse"
set_config_if_present core.sparseCheckoutCone "$core_sparse_cone"
set_config_if_present core.worktree "$core_worktree"
set_config_if_present core.abbrev "$describe_abbrev"
while IFS=' ' read -r key value; do
  if test -n "$key"; then
    git -C "$repo_root" config --local "$key" "$value"
  fi
done < "$seal_tmp/submodule-config"
git -C "$repo_root" config --local core.logAllRefUpdates false
git -C "$repo_root" config --local user.name "SWE-Bench ProMax"
git -C "$repo_root" config --local user.email "benchmark@localhost"

mkdir -p "$git_dir/info"
for info_file in exclude sparse-checkout; do
  if test -f "$seal_tmp/info/$info_file"; then
    cp "$seal_tmp/info/$info_file" "$git_dir/info/$info_file"
  fi
done

rm -rf "$git_dir/logs"
rm -f "$git_dir/FETCH_HEAD" "$git_dir/ORIG_HEAD"
git -C "$repo_root" gc --prune=now --quiet

# Fail closed if the main repository contains any commit that is not BASE or
# one of its ancestors.
test "$(git -C "$repo_root" rev-parse HEAD)" = "$base"
test "$(git -C "$repo_root" rev-parse "$base^{tree}")" = "$original_tree"
test -z "$(git -C "$repo_root" rev-list --all --not "$base")"

git -C "$repo_root" rev-list "$base" | LC_ALL=C sort > "$seal_tmp/expected-commits"
git -C "$repo_root" cat-file \
  --batch-check='%(objectname) %(objecttype)' --batch-all-objects | \
  awk '$2 == "commit" {print $1}' | LC_ALL=C sort > "$seal_tmp/stored-commits"
cmp "$seal_tmp/expected-commits" "$seal_tmp/stored-commits"

if test -n "$original_head_ref"; then
  test "$(git -C "$repo_root" symbolic-ref -q HEAD)" = "$original_head_ref"
  test "$(git -C "$repo_root" for-each-ref --format='%(refname)' refs/heads)" = \
    "$original_head_ref"
else
  test -z "$(git -C "$repo_root" symbolic-ref -q HEAD || true)"
  test -z "$(git -C "$repo_root" for-each-ref --format='%(refname)' refs/heads)"
fi

if test -n "$base_tag"; then
  test "$(git -C "$repo_root" for-each-ref --format='%(refname)' refs/tags)" = \
    "refs/tags/$base_tag"
  git -C "$repo_root" merge-base --is-ancestor \
    "refs/tags/$base_tag^{commit}" "$base"
  test "$(git -C "$repo_root" describe --tags --long "$base")" = "$base_describe"
else
  test -z "$(git -C "$repo_root" for-each-ref --format='%(refname)' refs/tags)"
fi

test -z "$(git -C "$repo_root" remote)"
test -z "$(git -C "$repo_root" for-each-ref --format='%(refname)' refs/replace)"
test ! -e "$git_dir/objects/info/alternates"
test ! -d "$git_dir/logs"
test -z "$(git -C "$repo_root" config --local --get-regexp \
  '^(extensions\.partialclone|remote\..*\.promisor)$' 2>/dev/null || true)"
test -z "$(find "$git_dir/objects/pack" -name '*.promisor' -print 2>/dev/null)"
test -z "$(git -C "$repo_root" fsck --full --no-reflogs --unreachable 2>/dev/null)"

if test -n "$forbidden"; then
  if git -C "$repo_root" cat-file -e "$forbidden^{commit}" 2>/dev/null; then
    die "forbidden commit remains reachable in the sealed repository"
  fi
fi

tracked_after=$(
  git -C "$repo_root" diff --no-ext-diff --ignore-submodules=all \
    --binary "$base" -- | git -C "$repo_root" hash-object --stdin
)
test "$tracked_after" = "$tracked_before"
git -C "$repo_root" diff --cached --quiet
git -C "$repo_root" status --porcelain=v1 --untracked-files=no >/dev/null
# shellcheck disable=SC2016  # Expanded by `git submodule foreach`.
git -C "$repo_root" submodule foreach --quiet --recursive '
  test "$(git rev-parse HEAD)" = "$sha1"
  git rev-parse --git-dir >/dev/null
  test -z "$(git rev-list --all --not "$sha1")"
'

if test "$write_marker" = 1; then
  umask 022
  {
    printf 'schema=1\n'
    printf 'base_commit=%s\n' "$base"
    printf 'base_tree=%s\n' "$original_tree"
    printf 'repo_root=%s\n' "$repo_root"
  } > "$marker_path"
fi

swap_committed=1
printf 'SWE_BENCH_PROMAX_HISTORY_SEALED=1 repo_root=%s base=%s\n' \
  "$repo_root" "$base"
