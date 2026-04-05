#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original golden files to ensure clean state
git checkout 32f86d35f7cd177b6e4525a7ae97909888d9fee4 "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -542,6 +542,7 @@
       "fromPromise",
       "fromReadableStreamLike",
       "getActiveConsumer",
+      "getAndClearAdditionalProviders",
       "getBaseElementHref",
       "getBeforeNodeForView",
       "getBindingsEnabled",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -543,6 +543,7 @@
       "fromPromise",
       "fromReadableStreamLike",
       "getActiveConsumer",
+      "getAndClearAdditionalProviders",
       "getBaseElementHref",
       "getBeforeNodeForView",
       "getBindingsEnabled",
EOF_114329324912

# Execute the symbol tests using pnpm and Bazel
# Running both test targets in a single command for efficiency
# These tests validate that the extracted symbols from optimized bundles match the golden files
pnpm exec bazel test \
    //packages/core/test/bundling/forms_reactive:symbol_test \
    //packages/core/test/bundling/forms_template_driven:symbol_test \
    --test_output=errors
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original golden files
git checkout 32f86d35f7cd177b6e4525a7ae97909888d9fee4 "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json"