#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless Chrome testing (required for browser-based tests)
/usr/local/bin/start-xvfb.sh

# Checkout the target test file to ensure clean state
git checkout 8144769ad82be25166a61cad9271e551d45c5abb \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -318,7 +318,6 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "elementEndFirstCreatePass",
-  "elementPropertyInternal",
   "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
@@ -590,6 +589,7 @@
   "setInjectImplementation",
   "setInputsFromAttrs",
   "setIsRefreshingViews",
+  "setPropertyAndInputs",
   "setSelectedIndex",
   "setShadowStylingInputFlags",
   "setTStylingRangeNext",
EOF_114329324912

# Run the golden file symbol test for forms_template_driven bundle
# Using bazelisk to ensure correct Bazel version (5.0.0 from .bazelversion)
# The test validates that bundle symbols match the expected golden file
# --test_output=errors shows only failed test output for cleaner logs
# --nocache_test_results ensures fresh test execution
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  --test_output=errors \
  --nocache_test_results \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 8144769ad82be25166a61cad9271e551d45c5abb \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json"