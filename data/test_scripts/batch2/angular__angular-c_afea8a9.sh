#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless Chrome testing (required for browser-based tests)
/usr/local/bin/start-xvfb.sh

# Checkout the target test files to ensure clean state
git checkout 44a8de20d5b54e38ad40474f838483e6a62057e6 \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts" \
  "packages/compiler-cli/src/ngtsc/core/test/compiler_test.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
--- a/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts
@@ -230,8 +230,8 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.template.path).toBeNull();
-      expect(analysis?.resources.template.expression.getText()).toEqual(`'${template}'`);
+      expect(analysis?.resources.template?.path).toBeNull();
+      expect(analysis?.resources.template?.expression.getText()).toEqual(`'${template}'`);
     });
 
     it('should keep track of external template', () => {
@@ -263,8 +263,8 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.template.path).toContain(templateUrl);
-      expect(analysis?.resources.template.expression.getText()).toContain(`'${templateUrl}'`);
+      expect(analysis?.resources.template?.path).toContain(templateUrl);
+      expect(analysis?.resources.template?.expression.getText()).toContain(`'${templateUrl}'`);
     });
 
     it('should keep track of internal and external styles', () => {
@@ -300,7 +300,7 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(3);
+      expect(analysis?.resources.styles?.size).toBe(3);
     });
 
     it('should use an empty source map URL for an indirect template', () => {
@@ -402,7 +402,7 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(2);
+      expect(analysis?.resources.styles?.size).toBe(2);
       expect(analysis?.meta.externalStyles).toEqual(['/myStyle.css']);
     });
 
@@ -438,7 +438,7 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(2);
+      expect(analysis?.resources.styles?.size).toBe(2);
       expect(analysis?.meta.externalStyles).toEqual(['/myStyle.css', '/myOtherStyle.css']);
     });
 
@@ -507,7 +507,7 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(2);
+      expect(analysis?.resources.styles?.size).toBe(2);
       expect(analysis?.meta.externalStyles).toEqual(['myTemplateStyle.css']);
     });
 
@@ -544,7 +544,7 @@ runInEachFileSystem(() => {
         return fail('Failed to recognize @Component');
       }
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(2);
+      expect(analysis?.resources.styles?.size).toBe(2);
       expect(analysis?.meta.externalStyles).toEqual([
         'abc//myStyle.css',
         'abc/myTemplateStyle.css',
@@ -592,7 +592,7 @@ runInEachFileSystem(() => {
       await handler.preanalyze(TestCmp, detected.metadata);
 
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(1);
+      expect(analysis?.resources.styles?.size).toBe(1);
       expect(analysis?.meta.externalStyles).toEqual(['abc/myInlineStyle.css']);
       expect(analysis?.meta.styles).toEqual([]);
     });
@@ -628,7 +628,7 @@ runInEachFileSystem(() => {
       await handler.preanalyze(TestCmp, detected.metadata);
 
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(1);
+      expect(analysis?.resources.styles?.size).toBe(1);
       expect(analysis?.meta.externalStyles).toEqual([]);
       expect(analysis?.meta.styles).toEqual(['.abc {}']);
     });
@@ -662,7 +662,7 @@ runInEachFileSystem(() => {
       }
 
       const {analysis} = handler.analyze(TestCmp, detected.metadata);
-      expect(analysis?.resources.styles.size).toBe(1);
+      expect(analysis?.resources.styles?.size).toBe(1);
       expect(analysis?.meta.externalStyles).toEqual([]);
       expect(analysis?.meta.styles).toEqual(['.abc {}']);
     });
diff --git a/packages/compiler-cli/src/ngtsc/core/test/compiler_test.ts b/packages/compiler-cli/src/ngtsc/core/test/compiler_test.ts
--- a/packages/compiler-cli/src/ngtsc/core/test/compiler_test.ts
+++ b/packages/compiler-cli/src/ngtsc/core/test/compiler_test.ts
@@ -240,7 +240,7 @@ runInEachFileSystem(() => {
       });
     });
 
-    describe('getComponentResources', () => {
+    describe('getDirectiveResources', () => {
       it('should return the component resources', () => {
         const styleFile = _('/style.css');
         fs.writeFile(styleFile, `/* This is the template, used by components CmpA */`);
@@ -277,12 +277,12 @@ runInEachFileSystem(() => {
           /** enableTemplateTypeChecker */ false,
           /* usePoisonedData */ false,
         );
-        const resources = compiler.getComponentResources(CmpA);
+        const resources = compiler.getDirectiveResources(CmpA);
         expect(resources).not.toBeNull();
         const {template, styles} = resources!;
         expect(template!.path).toEqual(templateFile);
-        expect(styles.size).toEqual(2);
-        const actualPaths = new Set(Array.from(styles).map((r) => r.path));
+        expect(styles?.size).toEqual(2);
+        const actualPaths = new Set(Array.from(styles || []).map((r) => r.path));
         expect(actualPaths).toEqual(new Set([styleFile, styleFile2]));
       });
 
@@ -321,10 +321,10 @@ runInEachFileSystem(() => {
           /** enableTemplateTypeChecker */ false,
           /* usePoisonedData */ false,
         );
-        const resources = compiler.getComponentResources(CmpA);
+        const resources = compiler.getDirectiveResources(CmpA);
         expect(resources).not.toBeNull();
         const {styles} = resources!;
-        expect(styles.size).toEqual(0);
+        expect(styles?.size).toEqual(0);
       });
     });
 
EOF_114329324912

# Run the target tests using Bazel
# Combining both test targets in a single command for efficiency
# --test_output=all shows full test output for debugging
# --nocache_test_results ensures fresh test execution
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/compiler-cli/src/ngtsc/annotations/component/test:test \
  //packages/compiler-cli/src/ngtsc/core/test:test \
  --test_output=all \
  --nocache_test_results \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 44a8de20d5b54e38ad40474f838483e6a62057e6 \
  "packages/compiler-cli/src/ngtsc/annotations/component/test/component_spec.ts" \
  "packages/compiler-cli/src/ngtsc/core/test/compiler_test.ts"