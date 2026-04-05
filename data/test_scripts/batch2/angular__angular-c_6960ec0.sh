#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 4016aa32297ead62376d9d01c522136be0c4592a "packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts b/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
@@ -145,6 +145,14 @@ describe('type check blocks', () => {
     expect(tcb(TEMPLATE)).toContain('_t2(1)');
   });
 
+  it('should handle template literals', () => {
+    expect(tcb('{{ `hello world` }}')).toContain('"" + (`hello world`);');
+    expect(tcb('{{ `hello \\${name}!!!` }}')).toContain('"" + (`hello \\${name}!!!`);');
+    expect(tcb('{{ `${a} - ${b} - ${c}` }}')).toContain(
+      '"" + (`${((this).a)} - ${((this).b)} - ${((this).c)}`);',
+    );
+  });
+
   describe('type constructors', () => {
     it('should handle missing property bindings', () => {
       const TEMPLATE = `<div dir [inputA]="foo"></div>`;
EOF_114329324912

# Run the specific test target using Bazelisk
# This executes the type_check_block_spec.ts test
bazelisk test \
  //packages/compiler-cli/src/ngtsc/typecheck/test:test \
  --test_output=errors \
  --flaky_test_attempts=1 \
  --jobs=4

# Capture the exit code from the test execution
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 4016aa32297ead62376d9d01c522136be0c4592a "packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts"