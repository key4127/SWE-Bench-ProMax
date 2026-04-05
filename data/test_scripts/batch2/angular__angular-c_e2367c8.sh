#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout f3207000fdf21ae3336ef29f51f5c886be777470 \
    "packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts" \
    "packages/compiler-cli/test/ngtsc/defer_spec.ts" \
    "packages/compiler-cli/test/ngtsc/template_typecheck_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts b/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
@@ -1856,6 +1856,20 @@ describe('type check blocks', () => {
 
       expect(tcb(TEMPLATE)).toContain('((this).shouldShow()) && (((this).isVisible));');
     });
+
+    it('should generate options for `viewport` trigger', () => {
+      const TEMPLATE = `
+        @defer (on viewport({rootMargin: '123px'})) {
+          {{main()}}
+        } @placeholder {
+          <div>{{placeholder()}}</div>
+        }
+      `;
+
+      expect(tcb(TEMPLATE)).toContain(
+        'new IntersectionObserver(null!, { "rootMargin": "123px" }); "" + ((this).main()); "" + ((this).placeholder());',
+      );
+    });
   });
 
   describe('conditional blocks', () => {
diff --git a/packages/compiler-cli/test/ngtsc/defer_spec.ts b/packages/compiler-cli/test/ngtsc/defer_spec.ts
--- a/packages/compiler-cli/test/ngtsc/defer_spec.ts
+++ b/packages/compiler-cli/test/ngtsc/defer_spec.ts
@@ -1521,7 +1521,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block',
         );
       });
 
@@ -1539,7 +1539,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block',
         );
       });
 
@@ -1557,7 +1557,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block with exactly one root element node',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block with exactly one root element node',
         );
       });
 
@@ -1575,7 +1575,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block with exactly one root element node',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block with exactly one root element node',
         );
       });
 
@@ -1593,7 +1593,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block',
         );
       });
 
@@ -1611,7 +1611,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block with exactly one root element node',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block with exactly one root element node',
         );
       });
 
@@ -1629,7 +1629,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block with exactly one root element node',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block with exactly one root element node',
         );
       });
 
@@ -1650,7 +1650,7 @@ runInEachFileSystem(() => {
         const diags = env.driveDiagnostics();
         expect(diags.length).toBe(1);
         expect(diags[0].messageText).toBe(
-          'Trigger with no parameters can only be placed on an @defer that has a @placeholder block with exactly one root element node',
+          'Trigger with no target can only be placed on an @defer that has a @placeholder block with exactly one root element node',
         );
       });
     });
diff --git a/packages/compiler-cli/test/ngtsc/template_typecheck_spec.ts b/packages/compiler-cli/test/ngtsc/template_typecheck_spec.ts
--- a/packages/compiler-cli/test/ngtsc/template_typecheck_spec.ts
+++ b/packages/compiler-cli/test/ngtsc/template_typecheck_spec.ts
@@ -4910,6 +4910,32 @@ suppress
           'Trigger cannot find reference "trigger".',
         );
       });
+
+      it('should check the options of the `viewport` trigger', () => {
+        env.write(
+          'test.ts',
+          `
+          import {Component} from '@angular/core';
+
+          @Component({
+            template: \`
+              @defer (on viewport({trigger: target, rootMargin: '10px', doesNotExist: true})) {
+                Content
+              }
+
+              <div #target></div>
+            \`,
+          })
+          export class Main {}
+        `,
+        );
+
+        const diags = env.driveDiagnostics();
+        expect(diags.length).toBe(1);
+        expect(diags[0].messageText).toBe(
+          `Object literal may only specify known properties, and '"doesNotExist"' does not exist in type 'IntersectionObserverInit'.`,
+        );
+      });
     });
 
     describe('conditional blocks', () => {
EOF_114329324912

# Execute the test targets using Bazelisk
# Target 1: type_check_block_spec.ts
bazelisk test //packages/compiler-cli/src/ngtsc/typecheck/test:test --test_output=errors
rc1=$?

# Target 2 & 3: defer_spec.ts and template_typecheck_spec.ts (same target, sharded)
bazelisk test //packages/compiler-cli/test/ngtsc:ngtsc --test_output=errors
rc2=$?

# Combine exit codes - fail if either test target failed
if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ]; then
    rc=1
else
    rc=0
fi

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout f3207000fdf21ae3336ef29f51f5c886be777470 \
    "packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts" \
    "packages/compiler-cli/test/ngtsc/defer_spec.ts" \
    "packages/compiler-cli/test/ngtsc/template_typecheck_spec.ts"