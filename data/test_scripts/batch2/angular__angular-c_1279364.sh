#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout ee2fb08167c089abd28881adc8ac853930850fd7 "packages/core/test/signals/linked_signal_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/signals/linked_signal_spec.ts b/packages/core/test/signals/linked_signal_spec.ts
--- a/packages/core/test/signals/linked_signal_spec.ts
+++ b/packages/core/test/signals/linked_signal_spec.ts
@@ -46,6 +46,18 @@ describe('linkedSignal', () => {
     expect(firstLetterReadonly()).toBe('c');
   });
 
+  it('should support debugName in options object', () => {
+    const options = signal(['apple', 'banana', 'fig']);
+    const choice = linkedSignal({
+      source: options,
+      computation: (options) => options[0],
+      debugName: 'TestChoice',
+    });
+
+    expect(choice()).toBe('apple');
+    expect(choice.toString()).toBe('[LinkedSignal: apple]');
+  });
+
   it('should update when the source changes', () => {
     const options = signal(['apple', 'banana', 'fig']);
     const choice = linkedSignal({
EOF_114329324912

# Execute the specific test target using pnpm and Bazel
# The //packages/core/test/signals:signals target runs Node.js Jasmine tests
# This includes linked_signal_spec.ts along with other signals tests
# Using --test_output=streamed for verbose output to verify our test executes
pnpm bazel test //packages/core/test/signals:signals --test_output=streamed
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout ee2fb08167c089abd28881adc8ac853930850fd7 "packages/core/test/signals/linked_signal_spec.ts"