#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout d216ffedbdba47357ccf844fa238dac364c004c1 \
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
@@ -274,7 +274,7 @@
   "diPublicInInjector",
   "documentElement",
   "elementEndFirstCreatePass",
-  "elementStartFirstCreatePass",
+  "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
   "eraseStyles",
@@ -366,6 +366,7 @@
   "isCurrentTNodeParent",
   "isDestroyed",
   "isDetachedByI18n",
+  "isDirectiveHost",
   "isElementNode",
   "isEnvironmentProviders",
   "isFunction",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -276,7 +276,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "elementEndFirstCreatePass",
-  "elementStartFirstCreatePass",
+  "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
   "epoch",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -327,7 +327,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "elementEndFirstCreatePass",
-  "elementStartFirstCreatePass",
+  "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
   "epoch",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -318,7 +318,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "elementEndFirstCreatePass",
-  "elementStartFirstCreatePass",
+  "elementLikeStartFirstCreatePass",
   "enterDI",
   "enterView",
   "epoch",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -385,7 +385,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "elementEndFirstCreatePass",
-  "elementStartFirstCreatePass",
+  "elementLikeStartFirstCreatePass",
   "emptyPathMatch",
   "encodeUriQuery",
   "encodeUriSegment",
EOF_114329324912

# Run the specified symbol extractor tests using Bazel
# These tests build optimized bundles, extract symbols, and compare against golden files
bazelisk test \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout d216ffedbdba47357ccf844fa238dac364c004c1 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json"