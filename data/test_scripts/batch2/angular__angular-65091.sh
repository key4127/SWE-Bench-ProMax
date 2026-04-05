#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 4c31f8ebf484a9d34b87685cd72edab7c31aece2 \
  "packages/core/test/acceptance/BUILD.bazel" \
  "packages/core/test/acceptance/profiler_spec.ts" \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/acceptance/BUILD.bazel b/packages/core/test/acceptance/BUILD.bazel
--- a/packages/core/test/acceptance/BUILD.bazel
+++ b/packages/core/test/acceptance/BUILD.bazel
@@ -24,7 +24,7 @@ ts_project(
         "//packages/common/locales",
         "//packages/compiler",
         "//packages/core",
-        "//packages/core/primitives/profiler",
+        "//packages/core/primitives/devtools",
         "//packages/core/primitives/signals",
         "//packages/core/src/di/interface",
         "//packages/core/src/util",
diff --git a/packages/core/test/acceptance/profiler_spec.ts b/packages/core/test/acceptance/profiler_spec.ts
--- a/packages/core/test/acceptance/profiler_spec.ts
+++ b/packages/core/test/acceptance/profiler_spec.ts
@@ -7,7 +7,7 @@
  */
 
 import {setProfiler, profiler} from '../../src/render3/profiler';
-import {ProfilerEvent} from '../../primitives/profiler/src/profiler_types';
+import {ProfilerEvent} from '../../primitives/devtools';
 import {TestBed} from '../../testing';
 
 import {
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -201,6 +201,7 @@
       "PRESERVE_HOST_CONTENT",
       "PRESERVE_HOST_CONTENT_DEFAULT",
       "PendingTasksInternal",
+      "ProfilerEvent",
       "QUERIES",
       "QUEUED_CLASSNAME",
       "QUEUED_SELECTOR",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -201,6 +201,7 @@
       "PRESERVE_HOST_CONTENT_DEFAULT",
       "PendingTasks",
       "PendingTasksInternal",
+      "ProfilerEvent",
       "QUERIES",
       "R3Injector",
       "REACTIVE_LVIEW_CONSUMER_NODE",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -205,6 +205,7 @@
       "PendingTasksInternal",
       "PlatformRef",
       "PristineChangeEvent",
+      "ProfilerEvent",
       "QUERIES",
       "R3Injector",
       "R3ViewContainerRef",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -201,6 +201,7 @@
       "PendingTasksInternal",
       "PlatformRef",
       "PristineChangeEvent",
+      "ProfilerEvent",
       "QUERIES",
       "R3Injector",
       "R3ViewContainerRef",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -177,6 +177,7 @@
       "PRESERVE_HOST_CONTENT",
       "PRESERVE_HOST_CONTENT_DEFAULT",
       "PendingTasksInternal",
+      "ProfilerEvent",
       "QUERIES",
       "R3Injector",
       "REACTIVE_LVIEW_CONSUMER_NODE",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -218,6 +218,7 @@
       "PendingTasksInternal",
       "PlatformLocation",
       "Position",
+      "ProfilerEvent",
       "QUERIES",
       "QUERY_PARAM_RE",
       "QUERY_PARAM_VALUE_RE",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -148,6 +148,7 @@
       "PRESERVE_HOST_CONTENT",
       "PRESERVE_HOST_CONTENT_DEFAULT",
       "PendingTasksInternal",
+      "ProfilerEvent",
       "QUERIES",
       "R3Injector",
       "REACTIVE_LVIEW_CONSUMER_NODE",
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run all target tests using Bazel
# Combining all test targets into a single command for efficiency
# This includes:
# - Core acceptance tests (profiler_spec.ts via acceptance target)
# - All bundling tests (bundle verification and symbol extraction)
bazelisk test \
  //packages/core/test/acceptance:acceptance \
  //packages/core/test/bundling/animations-standalone:test \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/defer:test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/hydration:test \
  //packages/core/test/bundling/hydration:symbol_test \
  //packages/core/test/bundling/router:test \
  //packages/core/test/bundling/router:symbol_test \
  //packages/core/test/bundling/standalone_bootstrap:test \
  //packages/core/test/bundling/standalone_bootstrap:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 4c31f8ebf484a9d34b87685cd72edab7c31aece2 \
  "packages/core/test/acceptance/BUILD.bazel" \
  "packages/core/test/acceptance/profiler_spec.ts" \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json"