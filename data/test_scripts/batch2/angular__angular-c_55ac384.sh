#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 277aa76876b367b77b3bad514755a508a25df074 \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -387,10 +387,8 @@
   "getNodeInjectable",
   "getNullInjector",
   "getOrCreateInjectable",
-  "getOrCreateLViewCleanup",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
-  "getOrCreateTViewCleanup",
   "getOrCreateViewRefs",
   "getOwnDefinition",
   "getParentInjectorIndex",
@@ -614,6 +612,7 @@
   "signalAsReadonlyFn",
   "signalSetFn",
   "storeLViewOnDestroy",
+  "storeListenerCleanup",
   "stringify",
   "stringifyCSSSelector",
   "throwCyclicDependencyError",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -374,10 +374,8 @@
   "getNodeInjectable",
   "getNullInjector",
   "getOrCreateInjectable",
-  "getOrCreateLViewCleanup",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
-  "getOrCreateTViewCleanup",
   "getOrCreateViewRefs",
   "getOwnDefinition",
   "getParentInjectorIndex",
@@ -607,6 +605,7 @@
   "signalAsReadonlyFn",
   "signalSetFn",
   "storeLViewOnDestroy",
+  "storeListenerCleanup",
   "stringify",
   "stringifyCSSSelector",
   "throwCyclicDependencyError",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -693,6 +693,7 @@
   "squashSegmentGroup",
   "standardizeConfig",
   "storeLViewOnDestroy",
+  "storeListenerCleanup",
   "stringify",
   "stringify13",
   "stringifyCSSSelector",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -318,10 +318,8 @@
   "getNodeInjectable",
   "getNullInjector",
   "getOrCreateInjectable",
-  "getOrCreateLViewCleanup",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
-  "getOrCreateTViewCleanup",
   "getOrCreateViewRefs",
   "getOwnDefinition",
   "getParentInjectorIndex",
@@ -491,6 +489,7 @@
   "shouldAddViewToDom",
   "shouldSearchParent",
   "storeLViewOnDestroy",
+  "storeListenerCleanup",
   "stringify",
   "stringifyCSSSelector",
   "throwCyclicDependencyError",
EOF_114329324912

# Run the specified bundling symbol tests using Bazelisk
# These tests validate that the bundled output contains the expected symbols
# Running all four tests in a single command to optimize execution
# Limiting parallelism with --jobs=4 for stability in virtualized environment
bazelisk test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  //packages/core/test/bundling/todo:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 277aa76876b367b77b3bad514755a508a25df074 \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"