#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless Chrome testing
/usr/local/bin/start-xvfb.sh

# Checkout the target test file to ensure clean state
git checkout b9cf414790f5217cd5c73f7520a11031bde6c864 \
  "packages/core/test/application_ref_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/application_ref_spec.ts b/packages/core/test/application_ref_spec.ts
--- a/packages/core/test/application_ref_spec.ts
+++ b/packages/core/test/application_ref_spec.ts
@@ -257,6 +257,34 @@ describe('bootstrap', () => {
         ),
       );
     });
+
+    describe('bootstrapImpl', () => {
+      it('should use a provided injector', inject([ApplicationRef], (ref: ApplicationRef) => {
+        class MyService {}
+        const myService = new MyService();
+
+        @Component({
+          selector: 'injecting-component',
+          template: `<div>Hello, World!</div>`,
+        })
+        class InjectingComponent {
+          constructor(readonly myService: MyService) {}
+        }
+
+        const injector = Injector.create({
+          providers: [{provide: MyService, useValue: myService}],
+        });
+
+        createRootEl('injecting-component');
+        const appRef = ref as unknown as {bootstrapImpl: ApplicationRef['bootstrapImpl']};
+        const compRef = appRef.bootstrapImpl(
+          InjectingComponent,
+          /* rootSelectorOrNode */ undefined,
+          injector,
+        );
+        expect(compRef.instance.myService).toBe(myService);
+      }));
+    });
   });
 
   describe('destroy', () => {
EOF_114329324912

# Run the unit test for application_ref_spec.ts
# Using bazelisk to ensure correct Bazel version (5.0.0 from .bazelversion)
# Target for application_ref_spec.ts is //packages/core/test:test (jasmine_node_test)
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/core/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout b9cf414790f5217cd5c73f7520a11031bde6c864 \
  "packages/core/test/application_ref_spec.ts"