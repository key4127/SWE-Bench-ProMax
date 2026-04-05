#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 00dff8bfd6a3e74f0517ed8933769d0b7ee6a732 \
  "packages/core/test/render3/reactivity_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/core/test/render3/reactivity_spec.ts b/packages/core/test/render3/reactivity_spec.ts
--- a/packages/core/test/render3/reactivity_spec.ts
+++ b/packages/core/test/render3/reactivity_spec.ts
@@ -751,6 +751,41 @@ describe('reactivity', () => {
       expect(effectRef[SIGNAL].debugName).toBe('TEST_DEBUG_NAME');
     });
 
+    it('should disallow writing to signals within computed', () => {
+      @Component({
+        selector: 'with-input',
+        template: '{{comp()}}',
+      })
+      class WriteComputed {
+        sig = signal(0);
+        comp = computed(() => {
+          this.sig.set(this.sig() + 1);
+          return this.sig();
+        });
+      }
+
+      const fixture = TestBed.createComponent(WriteComputed);
+
+      expect(() => fixture.detectChanges()).toThrowError(/NG0600.*in a `computed`/);
+    });
+
+    it('should disallow writing to signals within a template', () => {
+      @Component({
+        selector: 'with-input',
+        template: '{{func()}}',
+      })
+      class WriteComputed {
+        sig = signal(0);
+        func() {
+          this.sig.set(this.sig() + 1);
+        }
+      }
+
+      const fixture = TestBed.createComponent(WriteComputed);
+
+      expect(() => fixture.detectChanges()).toThrowError(/NG0600.*template/);
+    });
+
     describe('effects created in components should first run after ngOnInit', () => {
       it('when created during bootstrapping', () => {
         let log: string[] = [];
EOF_114329324912

# Run the render3 tests using Bazel
# The target //packages/core/test/render3:render3 includes reactivity_spec.ts
# Since test filtering via --grep doesn't work properly with Bazel's Jasmine integration,
# we run the entire render3 test suite which includes our target test file
# The test patch only modifies reactivity_spec.ts, so those are the critical tests
# --test_output=errors shows only failed test output for cleaner logs
# --cache_test_results=no ensures tests run fresh
# --jobs=4 limits parallelism for system stability
bazelisk test \
  //packages/core/test/render3:render3 \
  --test_output=errors \
  --cache_test_results=no \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 00dff8bfd6a3e74f0517ed8933769d0b7ee6a732 \
  "packages/core/test/render3/reactivity_spec.ts"