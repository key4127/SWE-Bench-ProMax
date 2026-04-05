#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 460c1c7e71bd02b4481cdabf445bd23d190f2a37 "packages/core/test/bundling/router/bundle.golden_symbols.json"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/bundling/router/bundle.golden_symbols.json b/packages/core/test/bundling/router/bundle.golden_symbols.json
--- a/packages/core/test/bundling/router/bundle.golden_symbols.json
+++ b/packages/core/test/bundling/router/bundle.golden_symbols.json
@@ -140,6 +140,7 @@
       "InputFlags",
       "ItemComponent",
       "KeyEventsPlugin",
+      "LINKED_SIGNAL_NODE",
       "LOCALE_ID",
       "LOCALE_ID",
       "LQueries_",
@@ -246,6 +247,7 @@
       "ROUTES",
       "ROUTES2",
       "ROUTE_INJECTOR_CLEANUP",
+      "ReactiveRouterState",
       "Recognizer",
       "RedirectCommand",
       "RedirectRequest",
@@ -505,6 +507,7 @@
       "createLQuery",
       "createLView",
       "createLinkElement",
+      "createLinkedSignal",
       "createLocation",
       "createNewSegmentChildren",
       "createNewSegmentGroup",
@@ -748,6 +751,7 @@
       "hasTagAndTypeMatch",
       "icuContainerIterate",
       "identity",
+      "identityFn",
       "importProvidersFrom",
       "inNotificationPhase",
       "includeViewProviders",
@@ -871,6 +875,9 @@
       "leaveView",
       "leaveViewLight",
       "linkTNodeInTView",
+      "linkedSignal",
+      "linkedSignalSetFn",
+      "linkedSignalUpdateFn",
       "listenToDomEvent",
       "listenToOutput",
       "listenerInternal",
@@ -1143,6 +1150,7 @@
       "updateSegmentGroup",
       "updateSegmentGroupChildren",
       "updateTextNode",
+      "upgradeLinkedSignalGetter",
       "validateCommands",
       "viewAttachedToChangeDetector",
       "viewAttachedToContainer",
EOF_114329324912

# Execute the symbol test target using Bazelisk
# This will build the optimized Angular router bundle, extract symbols, and compare against the golden file
pnpm bazel test //packages/core/test/bundling/router:symbol_test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 460c1c7e71bd02b4481cdabf445bd23d190f2a37 "packages/core/test/bundling/router/bundle.golden_symbols.json"