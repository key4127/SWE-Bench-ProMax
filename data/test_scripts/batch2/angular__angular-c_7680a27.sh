#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout bf6dbaab254ad6f6c46706a9a6919543de944671 \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -170,7 +170,6 @@
   "TYPE",
   "TracingAction",
   "TracingService",
-  "USE_EXHAUSTIVE_CHECK_NO_CHANGES_DEFAULT",
   "USE_VALUE",
   "UnsubscriptionError",
   "VIEW_REFS",
EOF_114329324912

# Run the symbol test for defer bundling using Bazel
# This test validates bundle symbols against the golden file (bundle.golden_symbols.json)
# Using bazelisk which will automatically use Bazel 5.0.0 from .bazelversion
# The correct test target is :symbol_test which runs js_expected_symbol_test
bazelisk test \
  //packages/core/test/bundling/defer:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout bf6dbaab254ad6f6c46706a9a6919543de944671 \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json"