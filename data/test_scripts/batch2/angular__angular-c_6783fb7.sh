#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 049fe82de68efaf6e07d5ba7e7f87323c40582b9 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -273,7 +273,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "documentElement",
-  "elementEndFirstCreatePass",
+  "elementLikeEndFirstCreatePass",
   "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -275,7 +275,7 @@
   "detectChangesInViewIfAttached",
   "detectChangesInternal",
   "diPublicInInjector",
-  "elementEndFirstCreatePass",
+  "elementLikeEndFirstCreatePass",
   "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -326,7 +326,7 @@
   "detectChangesInViewIfAttached",
   "detectChangesInternal",
   "diPublicInInjector",
-  "elementEndFirstCreatePass",
+  "elementLikeEndFirstCreatePass",
   "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -317,7 +317,7 @@
   "detectChangesInViewIfAttached",
   "detectChangesInternal",
   "diPublicInInjector",
-  "elementEndFirstCreatePass",
+  "elementLikeEndFirstCreatePass",
   "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -384,7 +384,7 @@
   "detectChangesInViewIfAttached",
   "detectChangesInternal",
   "diPublicInInjector",
-  "elementEndFirstCreatePass",
+  "elementLikeEndFirstCreatePass",
   "elementLikeStartFirstCreatePass",
   "emptyPathMatch",
   "encodeUriQuery",
EOF_114329324912

# Run the symbol tests using Bazelisk (automatically uses Bazel 6.5.0 from .bazelversion)
# These tests compare symbols in bundle.debug.min.js against bundle.golden_symbols.json
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 049fe82de68efaf6e07d5ba7e7f87323c40582b9 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json"