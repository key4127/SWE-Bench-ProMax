#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 2d8fa73c1d6cce078889548c69b8ddb8e84ac106 \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -572,6 +572,7 @@
   "init_let_declaration",
   "init_lift",
   "init_linked_signal",
+  "init_linked_signal2",
   "init_linker",
   "init_list_reconciliation",
   "init_listener",
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Run the target test using Bazel
# This test validates that the defer bundle symbols match the golden file
# The symbol_test target builds the app, extracts symbols, and compares against bundle.golden_symbols.json
bazelisk test \
  //packages/core/test/bundling/defer:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 2d8fa73c1d6cce078889548c69b8ddb8e84ac106 \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json"