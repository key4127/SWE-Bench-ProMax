#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 5753aa70ebfb46df44d4b519a7261eb0d07d0a88 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/animations/bundle.golden_symbols.json" \
  "packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hello_world/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -443,7 +443,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "resolveTiming",
   "resolveTimingValue",
   "roundOffset",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -469,7 +469,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "resolveTiming",
   "resolveTimingValue",
   "roundOffset",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -380,7 +380,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "runEffectsInView",
   "runInInjectionContext",
   "saveNameToExportMap",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -847,7 +847,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "retrieveHydrationInfo",
   "runEffectsInView",
   "runInInjectionContext",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -570,7 +570,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "resolveProvider",
   "runEffectsInView",
   "runInInjectionContext",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -561,7 +561,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "resolveProvider",
   "resolvedPromise",
   "resolvedPromise2",
diff --git a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
@@ -307,7 +307,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "runEffectsInView",
   "runInInjectionContext",
   "saveNameToExportMap",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -409,7 +409,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "retrieveHydrationInfo",
   "retrieveHydrationInfoImpl",
   "runEffectsInView",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -651,7 +651,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "rootRoute",
   "routes",
   "runEffectsInView",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -340,7 +340,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "runEffectsInView",
   "runInInjectionContext",
   "saveNameToExportMap",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -454,7 +454,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectivesForDef",
   "runEffectsInView",
   "runInInjectionContext",
   "saveNameToExportMap",
EOF_114329324912

# Run all symbol extractor tests using the recommended approach
# This will build bundles, extract symbols, and compare against golden files
bazelisk test \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/animations:symbol_test \
  //packages/core/test/bundling/cyclic_import:symbol_test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/hello_world:symbol_test \
  //packages/core/test/bundling/hydration:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  //packages/core/test/bundling/standalone_bootstrap:symbol_test \
  //packages/core/test/bundling/todo:symbol_test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 5753aa70ebfb46df44d4b519a7261eb0d07d0a88 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/animations/bundle.golden_symbols.json" \
  "packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hello_world/bundle.golden_symbols.json" \
  "packages/core/test/bundling/hydration/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"