#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 146ab9a76e6b4d8db7d08d34e2571ba5207f8756 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/animations/bundle.golden_symbols.json" \
  "packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -290,6 +290,7 @@
   "extractStyleParams",
   "filterNonAnimatableStyles",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "forEachSingleProvider",
   "forwardRef",
   "freeConsumers",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -311,6 +311,7 @@
   "extractStyleParams",
   "filterNonAnimatableStyles",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "forEachSingleProvider",
   "forwardRef",
   "freeConsumers",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -239,6 +239,7 @@
   "extractDefListOrFactory",
   "extractDirectiveDef",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "forEachSingleProvider",
   "forwardRef",
   "freeConsumers",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -289,6 +289,7 @@
   "extractDefListOrFactory",
   "extractDirectiveDef",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "forEachSingleProvider",
   "forwardRef",
   "freeConsumers",
@@ -427,6 +428,7 @@
   "init_config",
   "init_console",
   "init_constants",
+  "init_construction",
   "init_container",
   "init_context",
   "init_context_discovery",
@@ -463,6 +465,7 @@
   "init_di_setup",
   "init_directive",
   "init_directives",
+  "init_directives2",
   "init_discovery",
   "init_discovery_utils",
   "init_dispatcher",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -345,6 +345,7 @@
   "extractDirectiveDef",
   "fillProperties",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "findStylingValue",
   "forEachSingleProvider",
   "forkJoin",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -334,6 +334,7 @@
   "extractDirectiveDef",
   "fillProperties",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "findStylingValue",
   "forEachSingleProvider",
   "forkJoin",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -409,6 +409,7 @@
   "filter",
   "finalize",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "findNode",
   "findPath",
   "first",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -282,6 +282,7 @@
   "extractDefListOrFactory",
   "extractDirectiveDef",
   "findAttrIndexInNode",
+  "findDirectiveDefMatches",
   "findStylingValue",
   "forEachSingleProvider",
   "forwardRef",
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run the symbol tests using Bazel
# Execute all 8 symbol tests in a single command for efficiency
bazel test \
  --test_output=errors \
  //packages/core/test/bundling/animations-standalone:symbol_test \
  //packages/core/test/bundling/animations:symbol_test \
  //packages/core/test/bundling/cyclic_import:symbol_test \
  //packages/core/test/bundling/defer:symbol_test \
  //packages/core/test/bundling/forms_reactive:symbol_test \
  //packages/core/test/bundling/forms_template_driven:symbol_test \
  //packages/core/test/bundling/router:symbol_test \
  //packages/core/test/bundling/todo:symbol_test

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 146ab9a76e6b4d8db7d08d34e2571ba5207f8756 \
  "packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json" \
  "packages/core/test/bundling/animations/bundle.golden_symbols.json" \
  "packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json" \
  "packages/core/test/bundling/defer/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json" \
  "packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json" \
  "packages/core/test/bundling/router/bundle.golden_symbols.json" \
  "packages/core/test/bundling/todo/bundle.golden_symbols.json"