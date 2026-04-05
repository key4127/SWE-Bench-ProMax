#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 310e5ffe24349963c1e7a6b1d5171e6caf5d8399 \
  "packages/compiler-cli/src/ngtsc/scope/test/local_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/scope/test/local_spec.ts b/packages/compiler-cli/src/ngtsc/scope/test/local_spec.ts
--- a/packages/compiler-cli/src/ngtsc/scope/test/local_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/scope/test/local_spec.ts
@@ -370,6 +370,8 @@ function fakeDirective(ref: Reference<ClassDeclaration>): DirectiveMeta {
     isExplicitlyDeferred: false,
     deferredImports: null,
     inputFieldNamesFromMetadataArray: null,
+    selectorlessEnabled: false,
+    localReferencedSymbols: null,
   };
 }
 
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts b/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts
@@ -941,6 +941,8 @@ function makeScope(program: ts.Program, sf: ts.SourceFile, decls: TestDeclaratio
         preserveWhitespaces: decl.preserveWhitespaces ?? false,
         isExplicitlyDeferred: false,
         inputFieldNamesFromMetadataArray: null,
+        selectorlessEnabled: false,
+        localReferencedSymbols: null,
         hostDirectives:
           decl.hostDirectives === undefined
             ? null
EOF_114329324912

# Run the scope test using Bazel
# The correct Bazel target for local_spec.ts is :test (not :local_spec)
# Note: index.ts is a testing utility library, not a test file, so we only run the scope test
# Using --test_output=errors to show only failed test output for cleaner logs
# Using --cache_test_results=no to ensure tests run fresh
# Using --jobs=4 to limit parallelism for system stability
bazelisk test \
  //packages/compiler-cli/src/ngtsc/scope/test:test \
  --test_output=errors \
  --cache_test_results=no \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 310e5ffe24349963c1e7a6b1d5171e6caf5d8399 \
  "packages/compiler-cli/src/ngtsc/scope/test/local_spec.ts" \
  "packages/compiler-cli/src/ngtsc/typecheck/testing/index.ts"