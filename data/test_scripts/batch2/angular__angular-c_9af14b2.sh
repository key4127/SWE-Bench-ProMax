#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout fd7ee47bf702029e481ad40362684f0a01ef2ec0 \
  "packages/core/test/render3/node_selector_matcher_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/render3/node_selector_matcher_spec.ts b/packages/core/test/render3/node_selector_matcher_spec.ts
--- a/packages/core/test/render3/node_selector_matcher_spec.ts
+++ b/packages/core/test/render3/node_selector_matcher_spec.ts
@@ -741,8 +741,13 @@ describe('extractAttrsAndClassesFromSelector', () => {
   cases.forEach(([selector, attrs, classes]) => {
     it(`should process ${JSON.stringify(selector)} selector`, () => {
       const extracted = extractAttrsAndClassesFromSelector(selector);
-      expect(extracted.attrs).toEqual(attrs as string[]);
-      expect(extracted.classes).toEqual(classes as string[]);
+      const cssClassMarker = extracted.indexOf(AttributeMarker.Classes);
+
+      const extractedAttrs = cssClassMarker > -1 ? extracted.slice(0, cssClassMarker) : extracted;
+      const extractedClasses = cssClassMarker > -1 ? extracted.slice(cssClassMarker + 1) : [];
+
+      expect(extractedAttrs).toEqual(attrs as string[]);
+      expect(extractedClasses).toEqual(classes as string[]);
     });
   });
 });
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run the specific test target using Bazel
# The test file packages/core/test/render3/node_selector_matcher_spec.ts is part of the //packages/core/test/render3:render3 target
bazelisk test \
  //packages/core/test/render3:render3 \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout fd7ee47bf702029e481ad40362684f0a01ef2ec0 \
  "packages/core/test/render3/node_selector_matcher_spec.ts"