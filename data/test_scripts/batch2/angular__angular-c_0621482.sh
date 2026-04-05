#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout a55575d4d6c4c0ea7ab5fe1a76dc05fff5919481 \
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
@@ -90,7 +90,6 @@
   "Injector",
   "InputFlags",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LEAVE_TOKEN_REGEX",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -97,7 +97,6 @@
   "Injector",
   "InputFlags",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LEAVE_TOKEN_REGEX",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -66,7 +66,6 @@
   "Injector",
   "InputFlags",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "MODIFIER_KEYS",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -85,7 +85,6 @@
   "Injector",
   "InputFlags",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOADING_AFTER_SLOT",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -99,7 +99,6 @@
   "IterableChangeRecord_",
   "IterableDiffers",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "MODIFIER_KEYS",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -92,7 +92,6 @@
   "IterableChangeRecord_",
   "IterableDiffers",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "MODIFIER_KEYS",
diff --git a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
@@ -45,7 +45,6 @@
   "InjectionToken",
   "Injector",
   "InputFlags",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "NEW_LINE",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -73,7 +73,6 @@
   "Injector",
   "InputFlags",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "MODIFIER_KEYS",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -99,7 +99,6 @@
   "InputFlags",
   "ItemComponent",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LQueries_",
   "LQuery_",
@@ -135,7 +134,6 @@
   "NavigationCancellationCode",
   "NavigationEnd",
   "NavigationError",
-  "NavigationResult",
   "NavigationSkipped",
   "NavigationSkippedCode",
   "NavigationStart",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -61,7 +61,6 @@
   "Injector",
   "InputFlags",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "MODIFIER_KEYS",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -69,7 +69,6 @@
   "IterableChangeRecord_",
   "IterableDiffers",
   "KeyEventsPlugin",
-  "LContainerFlags",
   "LOCALE_ID2",
   "LifecycleHooksFeature",
   "MODIFIER_KEYS",
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Run all target symbol tests using Bazel
# Each test validates that bundle symbols match their respective golden files
# Running all targets in a single command for efficiency
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
git checkout a55575d4d6c4c0ea7ab5fe1a76dc05fff5919481 \
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