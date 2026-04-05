#!/bin/bash
set -uxo pipefail
cd /testbed

# Start Xvfb for headless Chrome testing
/usr/local/bin/start-xvfb.sh

# Checkout the target test files to ensure clean state
git checkout 42039b72536d36e5e8a840bf2a526310218f88a1 \
  "packages/compiler/test/render3/util/expression.ts" \
  "packages/compiler/test/render3/view/util.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/render3/util/expression.ts b/packages/compiler/test/render3/util/expression.ts
--- a/packages/compiler/test/render3/util/expression.ts
+++ b/packages/compiler/test/render3/util/expression.ts
@@ -137,10 +137,12 @@ class ExpressionSourceHumanizer extends e.RecursiveAstVisitor implements t.Visit
   }
 
   visitTemplate(ast: t.Template) {
+    t.visitAll(this, ast.directives);
     t.visitAll(this, ast.children);
     t.visitAll(this, ast.templateAttrs);
   }
   visitElement(ast: t.Element) {
+    t.visitAll(this, ast.directives);
     t.visitAll(this, ast.children);
     t.visitAll(this, ast.inputs);
     t.visitAll(this, ast.outputs);
@@ -231,6 +233,18 @@ class ExpressionSourceHumanizer extends e.RecursiveAstVisitor implements t.Visit
   visitLetDeclaration(decl: t.LetDeclaration) {
     decl.value.visit(this);
   }
+
+  visitComponent(ast: t.Component) {
+    t.visitAll(this, ast.children);
+    t.visitAll(this, ast.directives);
+    t.visitAll(this, ast.inputs);
+    t.visitAll(this, ast.outputs);
+  }
+
+  visitDirective(ast: t.Directive) {
+    t.visitAll(this, ast.inputs);
+    t.visitAll(this, ast.outputs);
+  }
 }
 
 /**
diff --git a/packages/compiler/test/render3/view/util.ts b/packages/compiler/test/render3/view/util.ts
--- a/packages/compiler/test/render3/view/util.ts
+++ b/packages/compiler/test/render3/view/util.ts
@@ -105,11 +105,13 @@ export function findExpression(tmpl: a.Node[], expr: string): e.AST | null {
 }
 
 function findExpressionInNode(node: a.Node, expr: string): e.AST | null {
-  if (node instanceof a.Element || node instanceof a.Template) {
+  if (node instanceof a.Element || node instanceof a.Template || node instanceof a.Component) {
     return findExpression([...node.inputs, ...node.outputs, ...node.children], expr);
+  } else if (node instanceof a.Directive) {
+    return findExpression([...node.inputs, ...node.outputs], expr);
   } else if (node instanceof a.BoundAttribute || node instanceof a.BoundText) {
     const ts = toStringExpression(node.value);
-    return toStringExpression(node.value) === expr ? node.value : null;
+    return ts === expr ? node.value : null;
   } else if (node instanceof a.BoundEvent) {
     return toStringExpression(node.handler) === expr ? node.handler : null;
   } else {
@@ -148,12 +150,14 @@ export function parseR3(
     preserveWhitespaces?: boolean;
     leadingTriviaChars?: string[];
     ignoreError?: boolean;
+    selectorlessEnabled?: boolean;
   } = {},
 ): Render3ParseResult {
   const htmlParser = new HtmlParser();
   const parseResult = htmlParser.parse(input, 'path:://to/template', {
     tokenizeExpansionForms: true,
     leadingTriviaChars: options.leadingTriviaChars ?? LEADING_TRIVIA_CHARS,
+    selectorlessEnabled: options.selectorlessEnabled,
   });
 
   if (parseResult.errors.length > 0 && !options.ignoreError) {
EOF_114329324912

# Run the tests for the render3 utilities
# These utility files are used by test specs in the render3 directory
# Using bazelisk to ensure correct Bazel version (5.0.0 from .bazelversion)
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/compiler/test/render3/... \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 42039b72536d36e5e8a840bf2a526310218f88a1 \
  "packages/compiler/test/render3/util/expression.ts" \
  "packages/compiler/test/render3/view/util.ts"