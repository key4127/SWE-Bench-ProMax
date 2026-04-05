#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout d868a5bc6de35adbbab37b71128f02d5c12834fb "packages/core/test/sanitization/html_sanitizer_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/sanitization/html_sanitizer_spec.ts b/packages/core/test/sanitization/html_sanitizer_spec.ts
--- a/packages/core/test/sanitization/html_sanitizer_spec.ts
+++ b/packages/core/test/sanitization/html_sanitizer_spec.ts
@@ -254,12 +254,9 @@ describe('HTML sanitizer', () => {
     // depending on a platform.
     if (isBrowser) {
       // Running in a real browser
-      expect(nextSibling).toThrowError(
-        /Failed to sanitize html because the element is clobbered: <input name="nextSibling" form="a">/,
-      );
-      expect(firstChild).toThrowError(
-        /Failed to sanitize html because the element is clobbered: <object form="a" id="firstChild"><\/object>/,
-      );
+      const errorMsg = 'Failed to sanitize html because the element is clobbered: ';
+      expect(nextSibling).toThrowError(`${errorMsg}<input name="nextSibling" form="a">`);
+      expect(firstChild).toThrowError(`${errorMsg}<object form="a" id="firstChild"></object>`);
     } else {
       // Running in Node, using Domino DOM emulation
       expect(nextSibling()).toBe('A');
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
export NG_FORCE_TTY=false
unset DISPLAY

# Run the target test using Bazel
# Testing the specific test file: html_sanitizer_spec.ts
# Bazel target: //packages/core/test:test_web
bazelisk test \
  //packages/core/test:test_web \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout d868a5bc6de35adbbab37b71128f02d5c12834fb "packages/core/test/sanitization/html_sanitizer_spec.ts"