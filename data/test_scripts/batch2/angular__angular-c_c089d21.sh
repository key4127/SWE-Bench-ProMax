#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 4f46b02f29903c468a118848eec2b2db1a704061 \
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
@@ -92,7 +92,6 @@
   "KeyEventsPlugin",
   "LEAVE_TOKEN_REGEX",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -201,7 +200,6 @@
   "activeConsumer",
   "addClass",
   "addPropertyBinding",
-  "addToEndOfViewTree",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -249,6 +247,7 @@
   "context",
   "convertToBitFlags",
   "copyAnimationEvent",
+  "createDirectivesInstances",
   "createElementNode",
   "createElementRef",
   "createErrorClass",
@@ -307,7 +306,6 @@
   "getDirectiveDef",
   "getFactoryDef",
   "getFirstLContainer",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -319,7 +317,6 @@
   "getNextLContainer",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
@@ -359,7 +356,6 @@
   "internalProvideZoneChangeDetection",
   "interpolateParams",
   "invalidTimingValue",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "invokeQuery",
   "isAngularZoneProperty",
diff --git a/packages/core/test/bundling/animations/bundle.golden_symbols.json b/packages/core/test/bundling/animations/bundle.golden_symbols.json
--- a/packages/core/test/bundling/animations/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/animations/bundle.golden_symbols.json
@@ -98,7 +98,6 @@
   "KeyEventsPlugin",
   "LEAVE_TOKEN_REGEX",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -220,7 +219,6 @@
   "activeConsumer",
   "addClass",
   "addPropertyBinding",
-  "addToEndOfViewTree",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -268,6 +266,7 @@
   "context",
   "convertToBitFlags",
   "copyAnimationEvent",
+  "createDirectivesInstances",
   "createElementNode",
   "createElementRef",
   "createErrorClass",
@@ -328,7 +327,6 @@
   "getDirectiveDef",
   "getFactoryDef",
   "getFirstLContainer",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -341,7 +339,6 @@
   "getNgZoneOptions",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
@@ -382,7 +379,6 @@
   "internalProvideZoneChangeDetection",
   "interpolateParams",
   "invalidTimingValue",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "invokeQuery",
   "isAngularZoneProperty",
diff --git a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
--- a/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/cyclic_import/bundle.golden_symbols.json
@@ -66,7 +66,6 @@
   "InputFlags",
   "KeyEventsPlugin",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "Module",
@@ -166,7 +165,6 @@
   "_wasLastNodeCreated",
   "activeConsumer",
   "addPropertyBinding",
-  "addToEndOfViewTree",
   "allocExpando",
   "allocLFrame",
   "angularZoneInstanceIdProperty",
@@ -203,6 +201,7 @@
   "consumerPollProducersForChange",
   "context",
   "convertToBitFlags",
+  "createDirectivesInstances",
   "createElementNode",
   "createElementRef",
   "createErrorClass",
@@ -256,7 +255,6 @@
   "getDirectiveDef",
   "getFactoryDef",
   "getFirstLContainer",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -269,7 +267,6 @@
   "getNgZoneOptions",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
@@ -305,7 +302,6 @@
   "instructionState",
   "internalImportProvidersFrom",
   "internalProvideZoneChangeDetection",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "isAngularZoneProperty",
   "isApplicationBootstrapConfig",
diff --git a/packages/core/test/bundling/defer/bundle.golden_symbols.json b/packages/core/test/bundling/defer/bundle.golden_symbols.json
--- a/packages/core/test/bundling/defer/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/defer/bundle.golden_symbols.json
@@ -87,7 +87,6 @@
   "KeyEventsPlugin",
   "LOADING_AFTER_SLOT",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MATH_ML_NAMESPACE",
   "MAXIMUM_REFRESH_RERUNS",
   "MINIMUM_SLOT",
@@ -247,6 +246,7 @@
   "convertToBitFlags",
   "createContainerAnchorImpl",
   "createDirectivesInstances",
+  "createDirectivesInstancesInInstruction",
   "createElementNode",
   "createElementRef",
   "createEnvironmentInjector",
@@ -309,7 +309,6 @@
   "getFactoryDef",
   "getFirstLContainer",
   "getFirstNativeNode",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -324,7 +323,6 @@
   "getNextLContainer",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateEnvironmentInjector",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
@@ -756,7 +754,6 @@
   "internalImportProvidersFrom",
   "internalProvideZoneChangeDetection",
   "invokeAllTriggerCleanupFns",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "invokeTriggerCleanupFns",
   "isAngularZoneProperty",
diff --git a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_reactive/bundle.golden_symbols.json
@@ -99,7 +99,6 @@
   "IterableDiffers",
   "KeyEventsPlugin",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -295,6 +294,7 @@
   "controlPath",
   "convertToBitFlags",
   "createDirectivesInstances",
+  "createDirectivesInstancesInInstruction",
   "createElementNode",
   "createElementRef",
   "createErrorClass",
@@ -372,7 +372,6 @@
   "getFactoryOf",
   "getFirstLContainer",
   "getFirstNativeNode",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -386,7 +385,6 @@
   "getNgZoneOptions",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
@@ -444,7 +442,6 @@
   "instructionState",
   "internalImportProvidersFrom",
   "internalProvideZoneChangeDetection",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "isAbstractControlOptions",
   "isAngularZoneProperty",
diff --git a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
--- a/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/forms_template_driven/bundle.golden_symbols.json
@@ -92,7 +92,6 @@
   "IterableDiffers",
   "KeyEventsPlugin",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -283,6 +282,7 @@
   "controlPath",
   "convertToBitFlags",
   "createDirectivesInstances",
+  "createDirectivesInstancesInInstruction",
   "createElementNode",
   "createElementRef",
   "createErrorClass",
@@ -358,7 +358,6 @@
   "getFactoryOf",
   "getFirstLContainer",
   "getFirstNativeNode",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -372,7 +371,6 @@
   "getNgZoneOptions",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
@@ -431,7 +429,6 @@
   "instructionState",
   "internalImportProvidersFrom",
   "internalProvideZoneChangeDetection",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "isAngularZoneProperty",
   "isApplicationBootstrapConfig",
diff --git a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hello_world/bundle.golden_symbols.json
@@ -46,7 +46,6 @@
   "Injector",
   "InputFlags",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "NEW_LINE",
   "NG_COMP_DEF",
   "NG_ELEMENT_ID",
@@ -246,6 +245,7 @@
   "isAngularZoneProperty",
   "isApplicationBootstrapConfig",
   "isComponentDef",
+  "isComponentHost",
   "isDestroyed",
   "isEnvironmentProviders",
   "isFunction",
@@ -312,6 +312,7 @@
   "setCurrentQueryIndex",
   "setIncludeViewProviders",
   "setInjectImplementation",
+  "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
   "shouldSearchParent",
diff --git a/packages/core/test/bundling/hydration/bundle.golden_symbols.json b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
--- a/packages/core/test/bundling/hydration/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/hydration/bundle.golden_symbols.json
@@ -74,7 +74,6 @@
   "InputFlags",
   "KeyEventsPlugin",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -420,6 +419,7 @@
   "setCurrentTNode",
   "setIncludeViewProviders",
   "setInjectImplementation",
+  "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSegmentHead",
   "setSelectedIndex",
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -102,7 +102,6 @@
   "LOCALE_ID2",
   "LQueries_",
   "LQuery_",
-  "LifecycleHooksFeature",
   "ListComponent",
   "Location",
   "LocationStrategy",
@@ -336,6 +335,7 @@
   "createChildrenForEmptyPaths",
   "createContainerRef",
   "createContentQuery",
+  "createDirectivesInstances",
   "createElementNode",
   "createElementRef",
   "createEmptyState",
@@ -443,7 +443,6 @@
   "getFirstNativeNode",
   "getIdxOfMatchingSelector",
   "getInherited",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -457,7 +456,6 @@
   "getNgModuleDef",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateLViewCleanup",
   "getOrCreateNodeInjectorForNode",
@@ -520,7 +518,6 @@
   "instructionState",
   "internalImportProvidersFrom",
   "internalProvideZoneChangeDetection",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "isAngularZoneProperty",
   "isApplicationBootstrapConfig",
diff --git a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
--- a/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/standalone_bootstrap/bundle.golden_symbols.json
@@ -62,7 +62,6 @@
   "InputFlags",
   "KeyEventsPlugin",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -275,6 +274,7 @@
   "isAngularZoneProperty",
   "isApplicationBootstrapConfig",
   "isComponentDef",
+  "isComponentHost",
   "isDestroyed",
   "isEnvironmentProviders",
   "isFunction",
@@ -347,6 +347,7 @@
   "setCurrentTNode",
   "setIncludeViewProviders",
   "setInjectImplementation",
+  "setInputsFromAttrs",
   "setIsRefreshingViews",
   "setSelectedIndex",
   "shimStylesContent",
diff --git a/packages/core/test/bundling/todo/bundle.golden_symbols.json b/packages/core/test/bundling/todo/bundle.golden_symbols.json
--- a/packages/core/test/bundling/todo/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/todo/bundle.golden_symbols.json
@@ -69,7 +69,6 @@
   "IterableDiffers",
   "KeyEventsPlugin",
   "LOCALE_ID2",
-  "LifecycleHooksFeature",
   "MODIFIER_KEYS",
   "MODIFIER_KEY_GETTERS",
   "NAMESPACE_URIS",
@@ -240,6 +239,7 @@
   "context",
   "convertToBitFlags",
   "createDirectivesInstances",
+  "createDirectivesInstancesInInstruction",
   "createElementNode",
   "createElementRef",
   "createErrorClass",
@@ -301,7 +301,6 @@
   "getFactoryDef",
   "getFirstLContainer",
   "getFirstNativeNode",
-  "getInitialLViewFlagsFromDef",
   "getInjectImplementation",
   "getInjectableDef",
   "getInjectorDef",
@@ -316,7 +315,6 @@
   "getNgZoneOptions",
   "getNodeInjectable",
   "getNullInjector",
-  "getOrCreateComponentTView",
   "getOrCreateInjectable",
   "getOrCreateNodeInjectorForNode",
   "getOrCreateTNode",
@@ -365,7 +363,6 @@
   "instructionState",
   "internalImportProvidersFrom",
   "internalProvideZoneChangeDetection",
-  "invokeDirectivesHostBindings",
   "invokeHostBindingsInCreationMode",
   "isAngularZoneProperty",
   "isApplicationBootstrapConfig",
EOF_114329324912

# Ensure environment variables are set for headless Chrome and Java
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Run all target symbol tests using Bazel in a single command for efficiency
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
git checkout 4f46b02f29903c468a118848eec2b2db1a704061 \
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