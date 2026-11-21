#!/bin/bash
# Build-time only. Runs the task's eval script with the EMPTY patch (no reference code enters the
# image) and network on, then removes every path that run created under /testbed (compiled hidden
# tests must not stay visible to the agent) and resets tracked files. Dependency caches outside
# /testbed (Gradle, Bazel/bazelisk) are kept; Gradle's build cache is dropped.
cd /testbed
git status --porcelain --ignored --untracked-files=all | sort > /tmp/warmup_before.txt
bash /tmp/warmup_eval.sh > /tmp/warmup.log 2>&1
echo "WARMUP_EVAL_RC=$? (non-zero is expected: the unfixed code fails the tests)"
tail -n 20 /tmp/warmup.log
cd /testbed
# Gradle: the unfixed code may not even compile the hidden tests, so the run above can stop before
# test-runtime configurations (e.g. jacocoAgent, testRuntimeClasspath) are resolved. Resolve every
# resolvable configuration of every project (downloads dependencies only, compiles nothing).
if [ -x ./gradlew ]; then
  cat > /tmp/harbor_resolve_all.gradle <<'GRADLE_EOF'
allprojects {
    tasks.register('harborResolveAll') {
        doLast {
            def cfgs = []
            cfgs.addAll(project.configurations)
            cfgs.addAll(project.buildscript.configurations)
            cfgs.findAll { it.canBeResolved }.each { c ->
                try { c.resolve() } catch (Throwable e) { println "harborResolveAll skip ${project.path}:${c.name}" }
            }
        }
    }
}
GRADLE_EOF
  ./gradlew --init-script /tmp/harbor_resolve_all.gradle harborResolveAll --no-daemon --console=plain --continue --no-configuration-cache > /tmp/warmup_resolve.log 2>&1 \
    || ./gradlew --init-script /tmp/harbor_resolve_all.gradle harborResolveAll --no-daemon --console=plain --continue >> /tmp/warmup_resolve.log 2>&1
  echo "WARMUP_GRADLE_RESOLVE_RC=$?"; tail -n 5 /tmp/warmup_resolve.log
  rm -f /tmp/harbor_resolve_all.gradle /tmp/warmup_resolve.log
fi
if command -v bazelisk >/dev/null 2>&1; then bazelisk clean >/dev/null 2>&1; bazelisk shutdown >/dev/null 2>&1; fi
git reset -q --hard
git status --porcelain --ignored --untracked-files=all | sort > /tmp/warmup_after.txt
comm -13 /tmp/warmup_before.txt /tmp/warmup_after.txt | sed -E 's/^(\?\?|!!) //' | while IFS= read -r f; do rm -rf -- "/testbed/$f"; done
echo "WARMUP_REMOVED_PATHS=$(comm -13 /tmp/warmup_before.txt /tmp/warmup_after.txt | wc -l)"
rm -rf /root/.gradle/caches/build-cache-* /root/.gradle/daemon /tmp/warmup.log /tmp/warmup_before.txt /tmp/warmup_after.txt
exit 0
