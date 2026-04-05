#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 46d5670688e76f76510f3e3fd5388af6449fc0cb "packages/forms/signals/test/node/field_node.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/node/field_node.spec.ts b/packages/forms/signals/test/node/field_node.spec.ts
--- a/packages/forms/signals/test/node/field_node.spec.ts
+++ b/packages/forms/signals/test/node/field_node.spec.ts
@@ -614,6 +614,30 @@ describe('FieldNode', () => {
         expect(f[0] === kirill).toBeTrue();
         expect(f[1] === alex).toBeTrue();
       });
+
+      it('uses index as identity for primitive values', () => {
+        const value = signal([1, 'two']);
+        const f = form(value, {injector: TestBed.inject(Injector)});
+        const first = f[0];
+        const second = f[1];
+
+        value.update((old) => [old[1], old[0]]);
+
+        expect(f[0] === first).toBeTrue();
+        expect(f[1] === second).toBeTrue();
+      });
+
+      it('uses index as identity for array values', () => {
+        const value = signal([[1], ['two']]);
+        const f = form(value, {injector: TestBed.inject(Injector)});
+        const first = f[0];
+        const second = f[1];
+
+        value.update((old) => [old[1], old[0]]);
+
+        expect(f[0] === first).toBeTrue();
+        expect(f[1] === second).toBeTrue();
+      });
     });
   });
 
EOF_114329324912

# Execute the specific test target using pnpm and Bazel
# Using the Bazel target as identified in the context retrieval
pnpm test //packages/forms/signals/test/node:test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 46d5670688e76f76510f3e3fd5388af6449fc0cb "packages/forms/signals/test/node/field_node.spec.ts"