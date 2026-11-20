#!/bin/bash
# Remove upstream history newer than the checked-out base commit (same idea as the
# official SWE-bench harness): drop refs that are not ancestors of HEAD, drop remotes,
# expire reflogs, prune unreachable objects. HEAD, its history and the worktree are kept.
set -euo pipefail
strip_repo() {  # $1 = git dir
  local g="$1"; local G="git --git-dir=$g"
  $G for-each-ref --format='%(refname)' | while read -r ref; do
    c=$($G rev-parse -q --verify "$ref^{commit}" 2>/dev/null) || { $G update-ref --no-deref -d "$ref"; continue; }
    $G merge-base --is-ancestor "$c" HEAD || $G update-ref --no-deref -d "$ref"
  done
  for r in $($G remote); do $G remote remove "$r" >/dev/null 2>&1 || $G config --remove-section "remote.$r" || true; done
  rm -f "$g"/FETCH_HEAD "$g"/ORIG_HEAD "$g"/MERGE_HEAD "$g"/CHERRY_PICK_HEAD "$g"/logs/refs/stash
  $G reflog expire --expire=now --all
  $G -c gc.auto=0 gc --prune=now -q
  local fut all reach
  fut=$($G rev-list --all --not HEAD | wc -l)
  all=$($G cat-file --batch-all-objects --batch-check='%(objecttype)' | grep -c '^commit' || true)
  reach=$($G rev-list --all HEAD | wc -l)
  echo "STRIP $g future=$fut commit_objects=$all reachable=$reach"
  [ "$fut" -eq 0 ] && [ "$all" -eq "$reach" ] || { echo "STRIP_FAIL $g"; exit 1; }
}
cd /testbed
before=$(git status --porcelain=v1 -uall | md5sum)
head_before=$(git rev-parse HEAD)
strip_repo "$(git rev-parse --absolute-git-dir)"
if [ -d .git/modules ]; then
  find .git/modules -name HEAD -type f -not -path '*/logs/*' -not -path '*/refs/*' | while read -r h; do
    d=$(dirname "$h"); [ -d "$d/objects" ] && strip_repo "$(cd "$d" && pwd)"
  done
fi
[ "$(git rev-parse HEAD)" = "$head_before" ] || { echo "STRIP_FAIL head changed"; exit 1; }
[ "$(git status --porcelain=v1 -uall | md5sum)" = "$before" ] || { echo "STRIP_FAIL worktree changed"; exit 1; }
# Some images chmod'ed the whole tree (644 -> 755) after checkout, so `git status` lists thousands of
# mode-only changes, and `git checkout .` / `git stash` would drop the exec bits. Make git ignore
# file modes in those repos; no file is changed.
if [ -n "$(git diff --summary | grep -m1 '^ mode change')" ]; then
  git config core.fileMode false
  echo "FILEMODE_IGNORED modified_now=$(git status --porcelain | grep -c '^ M' || true)"
fi
if [ -f .gitmodules ]; then
  git submodule foreach --quiet --recursive 'if [ -n "$(git diff --summary | grep -m1 "^ mode change")" ]; then git config core.fileMode false; echo "FILEMODE_IGNORED submodule $sm_path"; fi' || true
fi
echo STRIP_DONE
