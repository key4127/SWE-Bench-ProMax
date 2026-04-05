#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 1f389b8b97600ee382ff842e066abc2ca31c442f "packages/compiler-cli/test/ngtsc/ngtsc_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts b/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts
--- a/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts
+++ b/packages/compiler-cli/test/ngtsc/ngtsc_spec.ts
@@ -299,30 +299,48 @@ runInEachFileSystem((os: string) => {
         expect(updateInstances?.length).toBe(1);
       });
 
-      it('should compile animate.enter with a host binding string', () => {
+      it('should throw an error when legacy animations are used with animate.enter', () => {
         env.write(
           'test.ts',
           `
-          import {Component, signal, ViewChild, ElementRef} from '@angular/core';
+          import {Component} from '@angular/core';
 
           @Component({
             selector: 'test-cmp',
-            host: {'animate.enter': 'fade'},
-            template:
-              '<div><p>I should slide in</p></div>',
+            template: '<div animate.enter="some-class"></div>',
+            animations: [],
           })
-          class TestComponent {
-            show = signal(false);
-          }
+          class TestComponent {}
         `,
         );
 
-        env.driveMain();
+        const diags = env.driveDiagnostics();
+        expect(diags.length).toBe(1);
+        expect(diags[0].messageText).toContain(
+          `A component cannot have both the '@Component.animations' property (legacy animations) and use 'animate.enter' or 'animate.leave' in the template.`,
+        );
+      });
 
-        const jsContents = env.getContents('test.js');
-        expect(jsContents).toContain('i0.ɵɵanimateEnter("fade");');
-        const updateInstances = jsContents.match(/ɵɵanimateEnter\(/g);
-        expect(updateInstances?.length).toBe(1);
+      it('should throw an error when legacy animations are used with animate.leave', () => {
+        env.write(
+          'test.ts',
+          `
+          import {Component} from '@angular/core';
+
+          @Component({
+            selector: 'test-cmp',
+            template: '<div animate.leave="some-class"></div>',
+            animations: [],
+          })
+          class TestComponent {}
+        `,
+        );
+
+        const diags = env.driveDiagnostics();
+        expect(diags.length).toBe(1);
+        expect(diags[0].messageText).toContain(
+          `A component cannot have both the '@Component.animations' property (legacy animations) and use 'animate.enter' or 'animate.leave' in the template.`,
+        );
       });
     });
 
EOF_114329324912

# Execute the specific test target using Bazel
# Using bazelisk (which respects .bazelversion) to run the ngtsc test
# --test_output=all provides detailed output for verification
# The test is sharded across 4 workers as configured in the BUILD file
bazelisk test //packages/compiler-cli/test/ngtsc:ngtsc --test_output=all

# Capture the exit code immediately
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 1f389b8b97600ee382ff842e066abc2ca31c442f "packages/compiler-cli/test/ngtsc/ngtsc_spec.ts"