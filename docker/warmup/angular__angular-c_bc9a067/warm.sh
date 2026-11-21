#!/bin/bash
# warm-up: official eval script, empty patch, network on, offline switches removed
set -x
cd /testbed
git status --porcelain --ignored --untracked-files=all | sort > /tmp/before.txt
bash /tmp/warm_eval.sh > /tmp/warm.log 2>&1; echo "WARM_RC=$?"; tail -n 30 /tmp/warm.log
cd /testbed
command -v bazelisk >/dev/null && (bazelisk clean >/dev/null 2>&1; bazelisk shutdown >/dev/null 2>&1) || true
git reset -q --hard
git status --porcelain --ignored --untracked-files=all | sort > /tmp/after.txt
comm -13 /tmp/before.txt /tmp/after.txt | sed -E 's/^(\?\?|!!) //' | while IFS= read -r f; do rm -rf -- "/testbed/$f"; done
echo "NEW_PATHS_REMOVED=$(comm -13 /tmp/before.txt /tmp/after.txt | wc -l)"
rm -rf /root/.gradle/caches/build-cache-* /root/.gradle/daemon /tmp/warm_eval.sh /tmp/warm.log /tmp/before.txt /tmp/after.txt
