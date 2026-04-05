#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original files to ensure clean state
git checkout 64336715cd1ba4974f6bf4150de6aed27ae9dec0 "packages/compiler/test/render3/r3_template_transform_spec.ts" "packages/compiler/test/render3/util/expression.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/render3/r3_template_transform_spec.ts b/packages/compiler/test/render3/r3_template_transform_spec.ts
--- a/packages/compiler/test/render3/r3_template_transform_spec.ts
+++ b/packages/compiler/test/render3/r3_template_transform_spec.ts
@@ -150,7 +150,13 @@ class R3AstHumanizer implements t.Visitor<void> {
     } else if (trigger instanceof t.InteractionDeferredTrigger) {
       this.result.push(['InteractionDeferredTrigger', trigger.reference]);
     } else if (trigger instanceof t.ViewportDeferredTrigger) {
-      this.result.push(['ViewportDeferredTrigger', trigger.reference]);
+      const result = ['ViewportDeferredTrigger', trigger.reference];
+
+      if (trigger.options !== null) {
+        result.push(unparse(trigger.options));
+      }
+
+      this.result.push(result);
     } else if (trigger instanceof t.NeverDeferredTrigger) {
       this.result.push(['NeverDeferredTrigger']);
     } else {
@@ -1325,6 +1331,29 @@ describe('R3 template transform', () => {
       ]);
     });
 
+    it('should parse a viewport trigger with an options parameter', () => {
+      expectFromHtml(
+        '@defer (on viewport({trigger: foo, rootMargin: "123px", threshold: [1, 2, 3]})){hello}',
+      ).toEqual([
+        ['DeferredBlock'],
+        ['ViewportDeferredTrigger', 'foo', '{rootMargin: "123px", threshold: [1, 2, 3]}'],
+        ['Text', 'hello'],
+      ]);
+    });
+
+    it('should parse a viewport trigger with an options parameter, but without a trigger', () => {
+      expectFromHtml('@defer (on viewport({rootMargin: "123px"})){hello}').toEqual([
+        ['DeferredBlock'],
+        ['ViewportDeferredTrigger', null, '{rootMargin: "123px"}'],
+        ['Text', 'hello'],
+      ]);
+      expectFromHtml('@defer (on viewport({rootMargin: "123px"})){hello}').toEqual([
+        ['DeferredBlock'],
+        ['ViewportDeferredTrigger', null, '{rootMargin: "123px"}'],
+        ['Text', 'hello'],
+      ]);
+    });
+
     describe('block validations', () => {
       it('should report syntax error in `when` trigger', () => {
         expect(() => parse('@defer (when isVisible#){hello}')).toThrowError(
@@ -1498,6 +1527,26 @@ describe('R3 template transform', () => {
         );
       });
 
+      it('should report if `viewport` trigger with an object literal parameter has a "trigger" that is not an identifier', () => {
+        expect(() => parse('@defer (on viewport({trigger: "str"})) {hello}')).toThrowError(
+          /"trigger" option of the "viewport" trigger must be an identifier/,
+        );
+      });
+
+      it('should report if `viewport` trigger has a variable options parameter', () => {
+        expect(() =>
+          parse('@defer (on viewport({threshold: [1, someVar, 3]})) {hello}'),
+        ).toThrowError(
+          /Options of the "viewport" trigger must be an object literal containing only literal values/,
+        );
+      });
+
+      it('should report if `viewport` trigger options parameter contains the `root` property', () => {
+        expect(() => parse('@defer (on viewport({root: foo})) {hello}')).toThrowError(
+          /The "root" option is not supported in the options parameter of the "viewport" trigger/,
+        );
+      });
+
       it('should report duplicate when triggers', () => {
         expect(() => parse('@defer (when isVisible(); when somethingElse()) {hello}')).toThrowError(
           /Duplicate "when" trigger is not allowed/,
diff --git a/packages/compiler/test/render3/util/expression.ts b/packages/compiler/test/render3/util/expression.ts
--- a/packages/compiler/test/render3/util/expression.ts
+++ b/packages/compiler/test/render3/util/expression.ts
@@ -179,6 +179,8 @@ class ExpressionSourceHumanizer extends e.RecursiveAstVisitor implements t.Visit
   visitDeferredTrigger(trigger: t.DeferredTrigger): void {
     if (trigger instanceof t.BoundDeferredTrigger) {
       this.recordAst(trigger.value);
+    } else if (trigger instanceof t.ViewportDeferredTrigger && trigger.options !== null) {
+      this.recordAst(trigger.options);
     }
   }
 
EOF_114329324912

# Execute the specific test target using Bazel
# The test files are located in packages/compiler/test/render3/
# We need to run the test target that includes r3_template_transform_spec.ts
# Using bazelisk (aliased as bazel) to run tests
pnpm bazel test //packages/compiler/test/render3:test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original files
git checkout 64336715cd1ba4974f6bf4150de6aed27ae9dec0 "packages/compiler/test/render3/r3_template_transform_spec.ts" "packages/compiler/test/render3/util/expression.ts"