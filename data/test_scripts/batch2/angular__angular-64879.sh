#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout faccf03ee046485241e327f808e0d63d5e03612d "packages/core/test/acceptance/BUILD.bazel" "packages/core/test/acceptance/profiler_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/acceptance/BUILD.bazel b/packages/core/test/acceptance/BUILD.bazel
--- a/packages/core/test/acceptance/BUILD.bazel
+++ b/packages/core/test/acceptance/BUILD.bazel
@@ -24,6 +24,7 @@ ts_project(
         "//packages/common/locales",
         "//packages/compiler",
         "//packages/core",
+        "//packages/core/primitives/profiler",
         "//packages/core/primitives/signals",
         "//packages/core/src/di/interface",
         "//packages/core/src/util",
diff --git a/packages/core/test/acceptance/profiler_spec.ts b/packages/core/test/acceptance/profiler_spec.ts
--- a/packages/core/test/acceptance/profiler_spec.ts
+++ b/packages/core/test/acceptance/profiler_spec.ts
@@ -7,7 +7,7 @@
  */
 
 import {setProfiler, profiler} from '../../src/render3/profiler';
-import {ProfilerEvent} from '../../src/render3/profiler_types';
+import {ProfilerEvent} from '../../primitives/profiler/src/profiler_types';
 import {TestBed} from '../../testing';
 
 import {
EOF_114329324912

# Execute the specific test target using pnpm and Bazel
# The profiler_spec.ts is part of the acceptance test target
# Using --test_output=all to capture detailed test output for analysis
pnpm test //packages/core/test/acceptance:acceptance --test_output=all
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout faccf03ee046485241e327f808e0d63d5e03612d "packages/core/test/acceptance/BUILD.bazel" "packages/core/test/acceptance/profiler_spec.ts"