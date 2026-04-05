#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout a9145f38562cc53a99d0cdb94037d8f4d1866377 "packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable/optional_chain_not_nullable_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable/optional_chain_not_nullable_spec.ts b/packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable/optional_chain_not_nullable_spec.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable/optional_chain_not_nullable_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable/optional_chain_not_nullable_spec.ts
@@ -226,6 +226,66 @@ runInEachFileSystem(() => {
       expect(diags.length).toBe(0);
     });
 
+    it('should not produce optional chain warning for an indexed access if noUncheckedIndexedAccess is false', () => {
+      const fileName = absoluteFrom('/main.ts');
+      const {program, templateTypeChecker} = setup(
+        [
+          {
+            fileName,
+            templates: {
+              'TestCmp': `{{ arr[0]?.bar }}`,
+            },
+            source: `
+               export class TestCmp {
+                  arr: Array<{ bar: string }> = [];
+               }
+             `,
+          },
+        ],
+        {options: {noUncheckedIndexedAccess: false}},
+      );
+      const sf = getSourceFileOrError(program, fileName);
+      const component = getClass(sf, 'TestCmp');
+      const extendedTemplateChecker = new ExtendedTemplateCheckerImpl(
+        templateTypeChecker,
+        program.getTypeChecker(),
+        [optionalChainNotNullableFactory],
+        {strictNullChecks: true} /* options */,
+      );
+      const diags = extendedTemplateChecker.getDiagnosticsForComponent(component);
+      expect(diags.length).toBe(0);
+    });
+
+    it('should produce optional chain warning for an indexed access if noUncheckedIndexedAccess is true', () => {
+      const fileName = absoluteFrom('/main.ts');
+      const {program, templateTypeChecker} = setup(
+        [
+          {
+            fileName,
+            templates: {
+              'TestCmp': `{{ arr[0]?.bar }}`,
+            },
+            source: `
+               export class TestCmp {
+                  arr: Array<{ bar: string }> = [];
+               }
+             `,
+          },
+        ],
+        {options: {noUncheckedIndexedAccess: true}},
+      );
+      const sf = getSourceFileOrError(program, fileName);
+      const component = getClass(sf, 'TestCmp');
+      const extendedTemplateChecker = new ExtendedTemplateCheckerImpl(
+        templateTypeChecker,
+        program.getTypeChecker(),
+        [optionalChainNotNullableFactory],
+        {strictNullChecks: true} /* options */,
+      );
+      const diags = extendedTemplateChecker.getDiagnosticsForComponent(component);
+      expect(diags.length).toBe(0);
+    });
+
     it('should not produce optional chain warning for a type that includes undefined', () => {
       const fileName = absoluteFrom('/main.ts');
       const {program, templateTypeChecker} = setup([
EOF_114329324912

# Execute the specific test target using Bazel
# Using --test_output=all for detailed output to verify test execution
# Using --cache_test_results=no to ensure fresh test run
bazelisk test //packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable:test --test_output=all --cache_test_results=no

# Capture exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout a9145f38562cc53a99d0cdb94037d8f4d1866377 "packages/compiler-cli/src/ngtsc/typecheck/extended/test/checks/optional_chain_not_nullable/optional_chain_not_nullable_spec.ts"