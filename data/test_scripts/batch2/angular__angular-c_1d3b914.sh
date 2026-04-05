#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target golden symbol files to ensure clean state
git checkout ce3ffb1a9c76e15553ee32f3129e9c0922e78234 \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -725,6 +725,7 @@
   "init_type_checks",
   "init_types",
   "init_untracked",
+  "init_untracked2",
   "init_url_sanitizer",
   "init_util",
   "init_util2",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -624,7 +624,7 @@
   "trackMovedView",
   "uniqueIdCounter",
   "unregisterLView",
-  "untracked",
+  "untracked2",
   "unwrapRNode",
   "updateAncestorTraversalFlagsOnAttach",
   "updateControl",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -617,7 +617,7 @@
   "trackMovedView",
   "uniqueIdCounter",
   "unregisterLView",
-  "untracked",
+  "untracked2",
   "unwrapRNode",
   "updateAncestorTraversalFlagsOnAttach",
   "updateControl",
EOF_114329324912

# Run the three Bazel symbol tests sequentially
# Using --test_output=errors for cleaner output (only shows failures)
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the tests
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original golden symbol files
git checkout ce3ffb1a9c76e15553ee32f3129e9c0922e78234 \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json"

exit $rc