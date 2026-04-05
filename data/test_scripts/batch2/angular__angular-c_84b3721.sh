#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 06697091209a0a5f6e31096531d8f15749086c0c \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
--- a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
@@ -160,6 +160,7 @@ function setup(
     /* strictStandalone */ false,
     /* enableHmr */ false,
     /* implicitStandaloneValue */ true,
+    /* typeCheckHostBindings */ true,
   );
   return {reflectionHost, handler, resourceLoader, metaRegistry};
 }
EOF_114329324912

# Run the component test suite using Bazel
# Target: //packages/compiler-cli/src/ngtsc/annotations/component/test:test
# Using --test_output=errors for cleaner output (only shows failures)
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/compiler-cli/src/ngtsc/annotations/component/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the tests
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 06697091209a0a5f6e31096531d8f15749086c0c \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts"

exit $rc