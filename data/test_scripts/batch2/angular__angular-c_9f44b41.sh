#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 0cac2a22c0b44c36b76d93d513651c162b82bcee \
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
  "packages/core/test/bundling/todo/bundle.golden_symbols.json" \
  "packages/core/test/render3/is_shape_of.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations-standalone/bundle.golden_symbols.json
@@ -200,7 +200,6 @@
   "activeConsumer",
   "addAfterRenderSequencesForView",
   "addClass",
-  "addPropertyBinding",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -464,9 +463,11 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
+  "setShadowStylingInputFlags",
   "setStyles",
-  "setupBindings",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldSearchParent",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -219,7 +219,6 @@
   "activeConsumer",
   "addAfterRenderSequencesForView",
   "addClass",
-  "addPropertyBinding",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -490,9 +489,11 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
+  "setShadowStylingInputFlags",
   "setStyles",
-  "setupBindings",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldSearchParent",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -165,7 +165,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -398,8 +397,10 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
-  "setupBindings",
+  "setShadowStylingInputFlags",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldSearchParent",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -205,7 +205,6 @@
   "activeConsumer",
   "addAfterRenderSequencesForView",
   "addDepsToRegistry",
-  "addPropertyBinding",
   "addToEndOfViewTree",
   "allocExpando",
   "allocLFrame",
@@ -864,8 +863,10 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
-  "setupBindings",
+  "setShadowStylingInputFlags",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldAttachRegularTrigger",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -235,7 +235,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "addToArray",
   "addToEndOfViewTree",
   "addValidators",
@@ -494,6 +493,7 @@
   "leaveView",
   "leaveViewLight",
   "lengthOrSize",
+  "listenToOutput",
   "lookupTokenUsingModuleInjector",
   "lookupTokenUsingNodeInjector",
   "makeParamDecorator",
@@ -593,13 +593,15 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
+  "setShadowStylingInputFlags",
   "setTStylingRangeNext",
   "setTStylingRangeNextDuplicate",
   "setTStylingRangePrevDuplicate",
   "setUpControl",
   "setUpValidators",
-  "setupBindings",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldAddViewToDom",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -229,7 +229,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "addToArray",
   "addToEndOfViewTree",
   "addValidators",
@@ -480,6 +479,7 @@
   "leaveDI",
   "leaveView",
   "leaveViewLight",
+  "listenToOutput",
   "listenerInternal",
   "lookupTokenUsingModuleInjector",
   "lookupTokenUsingNodeInjector",
@@ -586,13 +586,15 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
+  "setShadowStylingInputFlags",
   "setTStylingRangeNext",
   "setTStylingRangeNextDuplicate",
   "setTStylingRangePrevDuplicate",
   "setUpControl",
   "setUpValidators",
-  "setupBindings",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldAddViewToDom",
diff --git a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
@@ -123,7 +123,6 @@
   "_platformInjector",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -320,8 +319,10 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
-  "setupBindings",
+  "setShadowStylingInputFlags",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "shouldSearchParent",
   "storeLViewOnDestroy",
   "stringify",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -169,7 +169,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -428,8 +427,10 @@
   "setIsRefreshingViews",
   "setSegmentHead",
   "setSelectedIndex",
-  "setupBindings",
+  "setShadowStylingInputFlags",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "shimStylesContent",
   "shouldSearchParent",
   "siblingAfter",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -278,7 +278,6 @@
   "activeConsumer",
   "addAfterRenderSequencesForView",
   "addEmptyPathsToChildrenIfNeeded",
-  "addPropertyBinding",
   "addToArray",
   "addToEndOfViewTree",
   "advanceActivatedRoute",
@@ -569,6 +568,7 @@
   "leaveDI",
   "leaveView",
   "leaveViewLight",
+  "listenToOutput",
   "locateDirectiveOrProvider",
   "lookupTokenUsingModuleInjector",
   "lookupTokenUsingNodeInjector",
@@ -676,8 +676,10 @@
   "setIsRefreshingViews",
   "setRouterState",
   "setSelectedIndex",
-  "setupBindings",
+  "setShadowStylingInputFlags",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shallowEqual",
   "shimStylesContent",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -148,7 +148,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -356,8 +355,10 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
-  "setupBindings",
+  "setShadowStylingInputFlags",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "shimStylesContent",
   "shouldSearchParent",
   "storeLViewOnDestroy",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -194,7 +194,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addAfterRenderSequencesForView",
-  "addPropertyBinding",
   "addToArray",
   "addToEndOfViewTree",
   "allocExpando",
@@ -401,6 +400,7 @@
   "leaveDI",
   "leaveView",
   "leaveViewLight",
+  "listenToOutput",
   "lookupTokenUsingModuleInjector",
   "lookupTokenUsingNodeInjector",
   "makeParamDecorator",
@@ -474,11 +474,13 @@
   "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
+  "setShadowStylingInputFlags",
   "setTStylingRangeNext",
   "setTStylingRangeNextDuplicate",
   "setTStylingRangePrevDuplicate",
-  "setupBindings",
+  "setupHostDirectiveInputsOrOutputs",
   "setupInitialInputs",
+  "setupSelectorMatchedInputsOrOutputs",
   "setupStaticAttributes",
   "shimStylesContent",
   "shouldAddViewToDom",
diff --git a/packages/core/test/render3/is_shape_of.ts b/packages/core/test/render3/is_shape_of.ts
--- a/packages/core/test/render3/is_shape_of.ts
+++ b/packages/core/test/render3/is_shape_of.ts
@@ -163,7 +163,9 @@ const ShapeOfTNode: ShapeOf<TNode> = {
   localNames: true,
   initialInputs: true,
   inputs: true,
+  hostDirectiveInputs: true,
   outputs: true,
+  hostDirectiveOutputs: true,
   tView: true,
   next: true,
   prev: true,
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
git checkout 0cac2a22c0b44c36b76d93d513651c162b82bcee \
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
  "packages/core/test/bundling/todo/bundle.golden_symbols.json" \
  "packages/core/test/render3/is_shape_of.ts"