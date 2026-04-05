#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 08512ee28558322de4eb427109b73e528e842212 \
  "packages/compiler/test/render3/r3_template_transform_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/render3/r3_template_transform_spec.ts b/packages/compiler/test/render3/r3_template_transform_spec.ts
--- a/packages/compiler/test/render3/r3_template_transform_spec.ts
+++ b/packages/compiler/test/render3/r3_template_transform_spec.ts
@@ -2646,6 +2646,18 @@ describe('R3 template transform', () => {
           /Binding is not supported in a directive context/,
         );
       });
+
+      it('should not allow named references', () => {
+        const pattern = /Cannot specify a value for a local reference in this context/;
+        expect(() => parseSelectorless('<MyComp #foo="bar"/>')).toThrowError(pattern);
+        expect(() => parseSelectorless('<div @Dir(#foo="bar")></div>')).toThrowError(pattern);
+      });
+
+      it('should not allow duplicate references', () => {
+        const pattern = /Duplicate reference names are not allowed/;
+        expect(() => parseSelectorless('<MyComp #foo #foo/>')).toThrowError(pattern);
+        expect(() => parseSelectorless('<div @Dir(#foo #foo)></div>')).toThrowError(pattern);
+      });
     });
   });
 });
EOF_114329324912

# Run the specific test for r3_template_transform using Bazel
# The test target is located in packages/compiler/test/render3
bazelisk test \
  //packages/compiler/test/render3:test \
  --test_output=errors \
  --test_filter="*r3_template_transform*" \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 08512ee28558322de4eb427109b73e528e842212 \
  "packages/compiler/test/render3/r3_template_transform_spec.ts"