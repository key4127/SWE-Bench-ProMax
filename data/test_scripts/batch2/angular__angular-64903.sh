#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 194b41199b3c98ce2282603aaa889de63555525c "packages/forms/signals/test/node/field_proxy.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/node/field_proxy.spec.ts b/packages/forms/signals/test/node/field_proxy.spec.ts
--- a/packages/forms/signals/test/node/field_proxy.spec.ts
+++ b/packages/forms/signals/test/node/field_proxy.spec.ts
@@ -31,4 +31,64 @@ describe('FieldTree proxy', () => {
     // @ts-expect-error
     f.arr[0] = f.arr[0];
   });
+
+  it('should get keys and values for object field', () => {
+    const f = form(signal({x: 1, y: 2}), {injector: TestBed.inject(Injector)});
+    expect(Object.keys(f)).toEqual(['x', 'y']);
+    expect(Object.getOwnPropertyNames(f)).toEqual(['x', 'y']);
+    expect(Object.entries(f).map(([key, child]) => [key, child().value()])).toEqual([
+      ['x', 1],
+      ['y', 2],
+    ]);
+    expect(Object.values(f).map((child) => child().value())).toEqual([1, 2]);
+  });
+
+  it('should get keys and values for array field', () => {
+    const f = form(signal([1, 2]), {injector: TestBed.inject(Injector)});
+    expect(Object.keys(f)).toEqual(['0', '1']);
+    expect(Object.getOwnPropertyNames(f)).toEqual(['0', '1', 'length']);
+    expect(Object.entries(f).map(([key, child]) => [key, child().value()])).toEqual([
+      ['0', 1],
+      ['1', 2],
+    ]);
+    expect(Object.values(f).map((child) => child().value())).toEqual([1, 2]);
+  });
+
+  it('should get keys and values for primitive field', () => {
+    const f = form(signal(1), {injector: TestBed.inject(Injector)});
+    expect(Object.keys(f)).toEqual([]);
+    expect(Object.getOwnPropertyNames(f)).toEqual([]);
+    expect(Object.entries(f)).toEqual([]);
+    expect(Object.values(f)).toEqual([]);
+  });
+
+  it('should iterate over object field', () => {
+    const f = form(signal({x: 1, y: 2}), {injector: TestBed.inject(Injector)});
+    const result: [string, number][] = [];
+    for (const [key, child] of f) {
+      result.push([key, child().value()]);
+    }
+    expect(result).toEqual([
+      ['x', 1],
+      ['y', 2],
+    ]);
+  });
+
+  it('should iterate over array field', () => {
+    const f = form(signal([1, 2]), {injector: TestBed.inject(Injector)});
+    const result: number[] = [];
+    for (const child of f) {
+      result.push(child().value());
+    }
+    expect(result).toEqual([1, 2]);
+  });
+
+  it('should not iterate over primitive field', () => {
+    const f = form(signal(1), {injector: TestBed.inject(Injector)});
+    expect(() => {
+      // @ts-expect-error - not iterable
+      for (const child of f) {
+      }
+    }).toThrow();
+  });
 });
EOF_114329324912

# Execute the specific test target using pnpm and Bazel
# Using the Bazel target pattern consistent with Angular's test structure
# This will run all tests in the forms/signals/test/node target, including field_proxy.spec.ts
pnpm test //packages/forms/signals/test/node:test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 194b41199b3c98ce2282603aaa889de63555525c "packages/forms/signals/test/node/field_proxy.spec.ts"