#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout a99e724c604412baa7739a2132679d3eaedb391a "packages/forms/signals/test/node/api/validators/max.spec.ts" "packages/forms/signals/test/node/api/validators/min.spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/forms/signals/test/node/api/validators/max.spec.ts b/packages/forms/signals/test/node/api/validators/max.spec.ts
--- a/packages/forms/signals/test/node/api/validators/max.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/max.spec.ts
@@ -59,7 +59,7 @@ describe('max validator', () => {
         (p) => {
           max(p.age, 5, {
             error: ({value}) => {
-              return customError({kind: 'special-max', message: value().toString()});
+              return customError({kind: 'special-max', message: value()?.toString()});
             },
           });
         },
@@ -104,7 +104,7 @@ describe('max validator', () => {
             error: ({value, valueOf}) => {
               return valueOf(p.name) === 'disabled'
                 ? []
-                : customError({kind: 'special-max', message: value().toString()});
+                : customError({kind: 'special-max', message: value()?.toString()});
             },
           });
         },
@@ -155,7 +155,7 @@ describe('max validator', () => {
         (p) => {
           max(p.age, 5, {
             error: ({value}) => {
-              return customError({kind: 'special-max', message: value().toString()});
+              return customError({kind: 'special-max', message: value()?.toString()});
             },
           });
         },
@@ -299,4 +299,30 @@ describe('max validator', () => {
       expect(f.age().errors()).toEqual([]);
     });
   });
+
+  it('should validate properly formatted strings', () => {
+    const f = form(
+      signal<number | string | null>('4'),
+      (p) => {
+        max(p, -10);
+      },
+      {injector: TestBed.inject(Injector)},
+    );
+    expect(f().errors()).toEqual([jasmine.objectContaining({kind: 'max'})]);
+  });
+
+  it('should not validate improperly formatted strings or null', () => {
+    const f = form(
+      signal<number | string | null>('4f'),
+      (p) => {
+        max(p, -10);
+      },
+      {injector: TestBed.inject(Injector)},
+    );
+    expect(f().errors()).toEqual([]);
+    f().value.set(null);
+    expect(f().errors()).toEqual([]);
+    f().value.set(4);
+    expect(f().errors()).toEqual([jasmine.objectContaining({kind: 'max'})]);
+  });
 });
diff --git a/packages/forms/signals/test/node/api/validators/min.spec.ts b/packages/forms/signals/test/node/api/validators/min.spec.ts
--- a/packages/forms/signals/test/node/api/validators/min.spec.ts
+++ b/packages/forms/signals/test/node/api/validators/min.spec.ts
@@ -59,7 +59,7 @@ describe('min validator', () => {
         (p) => {
           min(p.age, 5, {
             error: ({value}) => {
-              return customError({kind: 'special-min', message: value().toString()});
+              return customError({kind: 'special-min', message: value()?.toString()});
             },
           });
         },
@@ -84,7 +84,7 @@ describe('min validator', () => {
             error: ({value}) => {
               return {
                 kind: 'special-min',
-                message: value().toString(),
+                message: value()?.toString(),
               };
             },
           });
@@ -130,7 +130,7 @@ describe('min validator', () => {
             error: ({value, valueOf}) => {
               return valueOf(p.name) === 'disabled'
                 ? []
-                : customError({kind: 'special-min', message: value().toString()});
+                : customError({kind: 'special-min', message: value()?.toString()});
             },
           });
         },
@@ -308,4 +308,30 @@ describe('min validator', () => {
       expect(f.age().errors()).toEqual([]);
     });
   });
+
+  it('should validate properly formatted strings', () => {
+    const f = form(
+      signal<number | string | null>('4'),
+      (p) => {
+        min(p, 10);
+      },
+      {injector: TestBed.inject(Injector)},
+    );
+    expect(f().errors()).toEqual([jasmine.objectContaining({kind: 'min'})]);
+  });
+
+  it('should not validate improperly formatted strings or null', () => {
+    const f = form(
+      signal<number | string | null>('4f'),
+      (p) => {
+        min(p, 10);
+      },
+      {injector: TestBed.inject(Injector)},
+    );
+    expect(f().errors()).toEqual([]);
+    f().value.set(null);
+    expect(f().errors()).toEqual([]);
+    f().value.set(4);
+    expect(f().errors()).toEqual([jasmine.objectContaining({kind: 'min'})]);
+  });
 });
EOF_114329324912

# Execute the specific test target using Bazel
# The //packages/forms/signals/test/node:test target runs Node.js-based tests with Jasmine
# This includes max.spec.ts and min.spec.ts along with other node tests in the signals package
# Using --test_output=streamed for verbose output to verify our tests execute
pnpm bazel test //packages/forms/signals/test/node:test --test_output=streamed
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout a99e724c604412baa7739a2132679d3eaedb391a "packages/forms/signals/test/node/api/validators/max.spec.ts" "packages/forms/signals/test/node/api/validators/min.spec.ts"