#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e3dcf523ea0d36139c650950d407b0b8e96f9184 \
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
@@ -275,6 +275,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "documentElement",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "eraseStyles",
@@ -321,7 +322,6 @@
   "getNullInjector",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
-  "getOrCreateTNode",
   "getOrSetDefaultValue",
   "getOwnDefinition",
   "getParentElement",
@@ -344,7 +344,6 @@
   "importProvidersFrom",
   "includeViewProviders",
   "incrementInitPhaseFlags",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectDestroyRef",
@@ -444,7 +443,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "resolveTiming",
   "resolveTimingValue",
   "roundOffset",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -296,6 +296,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "documentElement",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "eraseStyles",
@@ -343,7 +344,6 @@
   "getNullInjector",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
-  "getOrCreateTNode",
   "getOrSetDefaultValue",
   "getOwnDefinition",
   "getParentElement",
@@ -367,7 +367,6 @@
   "importProvidersFrom",
   "includeViewProviders",
   "incrementInitPhaseFlags",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectDestroyRef",
@@ -470,7 +469,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "resolveTiming",
   "resolveTimingValue",
   "roundOffset",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -227,6 +227,7 @@
   "detectChangesInViewIfRequired",
   "detectChangesInternal",
   "diPublicInInjector",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "errorContext",
@@ -292,7 +293,6 @@
   "importProvidersFrom",
   "includeViewProviders",
   "incrementInitPhaseFlags",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectDestroyRef",
@@ -380,7 +380,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "runEffectsInView",
   "runInInjectionContext",
   "saveNameToExportMap",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -276,6 +276,7 @@
   "detectChangesInViewIfRequired",
   "detectChangesInternal",
   "diPublicInInjector",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "epoch",
@@ -479,6 +480,7 @@
   "init_element_container",
   "init_element_ref",
   "init_element_validation",
+  "init_elements",
   "init_empty",
   "init_environment",
   "init_environment2",
@@ -745,7 +747,6 @@
   "init_zone",
   "init_zoneless_scheduling",
   "init_zoneless_scheduling_impl",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectDestroyRef",
@@ -840,7 +841,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "retrieveHydrationInfo",
   "runEffectsInView",
   "runInInjectionContext",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -329,6 +329,7 @@
   "detectChangesInViewIfRequired",
   "detectChangesInternal",
   "diPublicInInjector",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "epoch",
@@ -429,7 +430,6 @@
   "inheritHostBindings",
   "inheritViewQuery",
   "initFeatures",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectDestroyRef",
@@ -570,7 +570,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "resolveProvider",
   "runEffectsInView",
   "runInInjectionContext",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -318,6 +318,7 @@
   "detectChangesInternal",
   "diPublicInInjector",
   "elementPropertyInternal",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "epoch",
@@ -415,7 +416,6 @@
   "inheritHostBindings",
   "inheritViewQuery",
   "initFeatures",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectChangeDetectorRef",
@@ -561,7 +561,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "resolveProvider",
   "resolvedPromise",
   "resolvedPromise2",
diff --git a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
@@ -147,6 +147,7 @@
   "cleanUpView",
   "collectNativeNodes",
   "collectNativeNodesInLContainer",
+  "computeStaticStyling",
   "concatStringsWithSpace",
   "config",
   "configureViewWithDirective",
@@ -193,6 +194,7 @@
   "getClosureSafeProperty",
   "getComponentDef",
   "getComponentLViewByIndex",
+  "getConstant",
   "getCurrentTNode",
   "getCurrentTNodePlaceholderOk",
   "getDeclarationTNode",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -200,6 +200,7 @@
   "clearElementContents",
   "collectNativeNodes",
   "collectNativeNodesInLContainer",
+  "computeStaticStyling",
   "concatStringsWithSpace",
   "config",
   "configureViewWithDirective",
@@ -254,6 +255,7 @@
   "getClosureSafeProperty",
   "getComponentDef",
   "getComponentLViewByIndex",
+  "getConstant",
   "getCurrentTNode",
   "getCurrentTNodePlaceholderOk",
   "getDOM",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -384,6 +384,7 @@
   "detectChangesInViewIfRequired",
   "detectChangesInternal",
   "diPublicInInjector",
+  "elementStartFirstCreatePass",
   "emptyPathMatch",
   "encodeUriQuery",
   "encodeUriSegment",
@@ -501,7 +502,6 @@
   "includeViewProviders",
   "incrementInitPhaseFlags",
   "initFeatures",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectChangeDetectorRef",
@@ -650,7 +650,6 @@
   "requiresRefreshOrTraversal",
   "resetPreOrderHookFlags",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "rootRoute",
   "routes",
   "runEffectsInView",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -173,6 +173,7 @@
   "cleanUpView",
   "collectNativeNodes",
   "collectNativeNodesInLContainer",
+  "computeStaticStyling",
   "concatStringsWithSpace",
   "config",
   "configureViewWithDirective",
@@ -221,6 +222,7 @@
   "getClosureSafeProperty",
   "getComponentDef",
   "getComponentLViewByIndex",
+  "getConstant",
   "getCurrentTNode",
   "getCurrentTNodePlaceholderOk",
   "getDOM",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -269,6 +269,7 @@
   "detectChangesInViewIfRequired",
   "detectChangesInternal",
   "diPublicInInjector",
+  "elementStartFirstCreatePass",
   "enterDI",
   "enterView",
   "errorContext",
@@ -351,7 +352,6 @@
   "includeViewProviders",
   "incrementInitPhaseFlags",
   "initFeatures",
-  "initializeDirectives",
   "inject",
   "injectArgs",
   "injectDestroyRef",
@@ -453,7 +453,6 @@
   "resetPreOrderHookFlags",
   "resolveDirectives",
   "resolveForwardRef",
-  "resolveHostDirectives",
   "runEffectsInView",
   "runInInjectionContext",
   "saveNameToExportMap",
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run all symbol tests in a single command (optimized for efficiency)
# This executes all the bundling symbol validation tests against their golden files
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
git checkout e3dcf523ea0d36139c650950d407b0b8e96f9184 \
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