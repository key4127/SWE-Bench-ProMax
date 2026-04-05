#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 3089ab4ac148d13b03d9d9e085a34968d15bef00 \
  "packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts" \
  "packages/compiler/test/expression_parser/parser_spec.ts" \
  "packages/compiler/test/expression_parser/utils/unparser.ts" \
  "packages/compiler/test/expression_parser/utils/validator.ts" \
  "packages/compiler/test/render3/r3_template_transform_spec.ts" \
  "packages/compiler/test/render3/util/expression.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts b/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
--- a/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
+++ b/packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts
@@ -57,22 +57,22 @@ describe('type check blocks', () => {
     expect(tcb('{{ a ?? b }}')).toContain('((((this).a)) ?? (((this).b)))');
     expect(tcb('{{ a ?? b ?? c }}')).toContain('(((((this).a)) ?? (((this).b))) ?? (((this).c)))');
     expect(tcb('{{ (a ?? b) + (c ?? e) }}')).toContain(
-      '(((((this).a)) ?? (((this).b))) + ((((this).c)) ?? (((this).e))))',
+      '((((((this).a)) ?? (((this).b)))) + (((((this).c)) ?? (((this).e)))))',
     );
   });
 
   it('should handle typeof expressions', () => {
     expect(tcb('{{typeof a}}')).toContain('typeof (((this).a))');
-    expect(tcb('{{!(typeof a)}}')).toContain('!(typeof (((this).a)))');
+    expect(tcb('{{!(typeof a)}}')).toContain('!((typeof (((this).a))))');
     expect(tcb('{{!(typeof a === "object")}}')).toContain(
-      '!((typeof (((this).a))) === ("object"))',
+      '!(((typeof (((this).a))) === ("object")))',
     );
   });
 
   it('should handle void expressions', () => {
     expect(tcb('{{void a}}')).toContain('void (((this).a))');
-    expect(tcb('{{!(void a)}}')).toContain('!(void (((this).a)))');
-    expect(tcb('{{!(void a === "object")}}')).toContain('!((void (((this).a))) === ("object"))');
+    expect(tcb('{{!(void a)}}')).toContain('!((void (((this).a))))');
+    expect(tcb('{{!(void a === "object")}}')).toContain('!(((void (((this).a))) === ("object")))');
   });
 
   it('should handle exponentiation expressions', () => {
diff --git a/packages/compiler/test/expression_parser/parser_spec.ts b/packages/compiler/test/expression_parser/parser_spec.ts
--- a/packages/compiler/test/expression_parser/parser_spec.ts
+++ b/packages/compiler/test/expression_parser/parser_spec.ts
@@ -104,16 +104,16 @@ describe('parser', () => {
 
     it('should parse typeof expression', () => {
       checkAction(`typeof {} === "object"`);
-      checkAction('(!(typeof {} === "number"))', '!typeof {} === "number"');
+      checkAction('(!(typeof {} === "number"))');
     });
 
     it('should parse void expression', () => {
       checkAction(`void 0`);
-      checkAction('(!(void 0))', '!void 0');
+      checkAction('(!(void 0))');
     });
 
     it('should parse grouped expressions', () => {
-      checkAction('(1 + 2) * 3', '1 + 2 * 3');
+      checkAction('(1 + 2) * 3');
     });
 
     it('should ignore comments in expressions', () => {
@@ -364,7 +364,7 @@ describe('parser', () => {
 
         it('should recover on parenthesized empty rvalues', () => {
           const ast = parseAction('(a[1] = b) = c = d');
-          expect(unparse(ast)).toEqual('a[1] = b');
+          expect(unparse(ast)).toEqual('(a[1] = b)');
           validate(ast);
 
           expect(ast.errors.length).toBe(1);
@@ -444,7 +444,7 @@ describe('parser', () => {
 
       it('should parse template literals with pipes inside interpolations', () => {
         checkBinding('`hello ${name | capitalize}!!!`', '`hello ${(name | capitalize)}!!!`');
-        checkBinding('`hello ${(name | capitalize)}!!!`');
+        checkBinding('`hello ${(name | capitalize)}!!!`', '`hello ${((name | capitalize))}!!!`');
       });
 
       it('should report error if interpolation is empty', () => {
@@ -459,7 +459,7 @@ describe('parser', () => {
         checkBinding('tags.first`hello!`');
         checkBinding('tags[0]`hello!`');
         checkBinding('tag()`hello!`');
-        checkBinding('(tag ?? otherTag)`hello!`', 'tag ?? otherTag`hello!`');
+        checkBinding('(tag ?? otherTag)`hello!`');
         checkBinding('tag!`hello!`');
       });
 
@@ -468,7 +468,7 @@ describe('parser', () => {
         checkBinding('tags.first`hello ${name}!`');
         checkBinding('tags[0]`hello ${name}!`');
         checkBinding('tag()`hello ${name}!`');
-        checkBinding('(tag ?? otherTag)`hello ${name}!`', 'tag ?? otherTag`hello ${name}!`');
+        checkBinding('(tag ?? otherTag)`hello ${name}!`');
         checkBinding('tag!`hello ${name}!`');
       });
 
@@ -642,7 +642,7 @@ describe('parser', () => {
         checkBinding('a?.b | c', '(a?.b | c)');
         checkBinding('true | a', '(true | a)');
         checkBinding('a | b:c | d', '((a | b:c) | d)');
-        checkBinding('a | b:(c | d)', '(a | b:(c | d))');
+        checkBinding('a | b:(c | d)', '(a | b:((c | d)))');
       });
 
       describe('should parse incomplete pipes', () => {
@@ -680,7 +680,7 @@ describe('parser', () => {
           [
             'should parse incomplete pipe args',
             'a | b: (a | ) + | c',
-            '((a | b:(a | ) + ) | c)',
+            '((a | b:((a | )) + ) | c)',
             'Unexpected token |',
           ],
         ];
@@ -1319,9 +1319,9 @@ describe('parser', () => {
       const expr = validate(parseAction(text));
       expect(unparse(expr)).toEqual(expected || text);
     }
-    it('should be able to recover from an extra paren', () => recover('((a)))', 'a'));
+    it('should be able to recover from an extra paren', () => recover('((a)))', '((a))'));
     it('should be able to recover from an extra bracket', () => recover('[[a]]]', '[[a]]'));
-    it('should be able to recover from a missing )', () => recover('(a;b', 'a; b;'));
+    it('should be able to recover from a missing )', () => recover('(a;b', '(a); b;'));
     it('should be able to recover from a missing ]', () => recover('[a,b', '[a, b]'));
     it('should be able to recover from a missing selector', () => recover('a.'));
     it('should be able to recover from a missing selector in a array literal', () =>
diff --git a/packages/compiler/test/expression_parser/utils/unparser.ts b/packages/compiler/test/expression_parser/utils/unparser.ts
--- a/packages/compiler/test/expression_parser/utils/unparser.ts
+++ b/packages/compiler/test/expression_parser/utils/unparser.ts
@@ -23,6 +23,7 @@ import {
   LiteralMap,
   LiteralPrimitive,
   NonNullAssert,
+  Parenthesized,
   PrefixNot,
   PropertyRead,
   PropertyWrite,
@@ -247,6 +248,12 @@ class Unparser implements AstVisitor {
     this._visit(ast.template);
   }
 
+  visitParenthesized(ast: Parenthesized, context: any) {
+    this._expression += '(';
+    this._visit(ast.expression);
+    this._expression += ')';
+  }
+
   private _visit(ast: AST) {
     ast.visit(this);
   }
diff --git a/packages/compiler/test/expression_parser/utils/validator.ts b/packages/compiler/test/expression_parser/utils/validator.ts
--- a/packages/compiler/test/expression_parser/utils/validator.ts
+++ b/packages/compiler/test/expression_parser/utils/validator.ts
@@ -20,6 +20,7 @@ import {
   LiteralArray,
   LiteralMap,
   LiteralPrimitive,
+  Parenthesized,
   ParseSpan,
   PrefixNot,
   PropertyRead,
@@ -160,6 +161,10 @@ class ASTValidator extends RecursiveAstVisitor {
   override visitTaggedTemplateLiteral(ast: TaggedTemplateLiteral, context: any): void {
     this.validate(ast, () => super.visitTaggedTemplateLiteral(ast, context));
   }
+
+  override visitParenthesized(ast: Parenthesized, context: any): void {
+    this.validate(ast, () => super.visitParenthesized(ast, context));
+  }
 }
 
 function inSpan(span: ParseSpan, parentSpan: ParseSpan | undefined): parentSpan is ParseSpan {
diff --git a/packages/compiler/test/render3/r3_template_transform_spec.ts b/packages/compiler/test/render3/r3_template_transform_spec.ts
--- a/packages/compiler/test/render3/r3_template_transform_spec.ts
+++ b/packages/compiler/test/render3/r3_template_transform_spec.ts
@@ -1544,13 +1544,13 @@ describe('R3 template transform', () => {
             @default { No case matched }
           }
         `).toEqual([
-        ['SwitchBlock', 'cond.kind'],
-        ['SwitchBlockCase', 'x()'],
+        ['SwitchBlock', '(cond.kind)'],
+        ['SwitchBlockCase', '(x())'],
         ['Text', ' X case '],
-        ['SwitchBlockCase', '"hello"'],
+        ['SwitchBlockCase', '("hello")'],
         ['Element', 'button'],
         ['Text', 'Y case'],
-        ['SwitchBlockCase', '42'],
+        ['SwitchBlockCase', '(42)'],
         ['Text', ' Z case '],
         ['SwitchBlockCase', null],
         ['Text', ' No case matched '],
@@ -1932,13 +1932,24 @@ describe('R3 template transform', () => {
         ['Variable', '$count', '$count'],
         ['BoundText', '{{ item }}'],
       ];
+      const expectedExtraParensResult = [
+        ['ForLoopBlock', 'items.foo.bar', '(item.id + foo)'],
+        ['Variable', 'item', '$implicit'],
+        ['Variable', '$index', '$index'],
+        ['Variable', '$first', '$first'],
+        ['Variable', '$last', '$last'],
+        ['Variable', '$even', '$even'],
+        ['Variable', '$odd', '$odd'],
+        ['Variable', '$count', '$count'],
+        ['BoundText', '{{ item }}'],
+      ];
 
       expectFromHtml(`
         @for (item\nof\nitems.foo.bar; track item.id +\nfoo) {{{ item }}}
       `).toEqual(expectedResult);
       expectFromHtml(`
         @for ((item\nof\nitems.foo.bar); track (item.id +\nfoo)) {{{ item }}}
-      `).toEqual(expectedResult);
+      `).toEqual(expectedExtraParensResult);
     });
 
     it('should parse for loop block expression containing new lines', () => {
@@ -2140,9 +2151,9 @@ describe('R3 template transform', () => {
         }
         `).toEqual([
         ['IfBlock'],
-        ['IfBlockBranch', 'cond.expr'],
+        ['IfBlockBranch', '(cond.expr)'],
         ['Text', ' Main case was true! '],
-        ['IfBlockBranch', 'other.expr'],
+        ['IfBlockBranch', '(other.expr)'],
         ['Text', ' Extra case was true! '],
         ['IfBlockBranch', null],
         ['Text', ' False case! '],
diff --git a/packages/compiler/test/render3/util/expression.ts b/packages/compiler/test/render3/util/expression.ts
--- a/packages/compiler/test/render3/util/expression.ts
+++ b/packages/compiler/test/render3/util/expression.ts
@@ -131,6 +131,10 @@ class ExpressionSourceHumanizer extends e.RecursiveAstVisitor implements t.Visit
     this.recordAst(ast);
     super.visitTaggedTemplateLiteral(ast, null);
   }
+  override visitParenthesized(ast: e.Parenthesized, context: any): void {
+    this.recordAst(ast);
+    super.visitParenthesized(ast, null);
+  }
 
   visitTemplate(ast: t.Template) {
     t.visitAll(this, ast.children);
EOF_114329324912

# Run all three test targets in a single command to optimize execution
# Limiting parallelism with --jobs=4 for stability in virtualized environment
bazelisk test \
  //packages/compiler/test/expression_parser:expression_parser \
  //packages/compiler-cli/src/ngtsc/typecheck/test:test \
  //packages/compiler/test/render3:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 3089ab4ac148d13b03d9d9e085a34968d15bef00 \
  "packages/compiler-cli/src/ngtsc/typecheck/test/type_check_block_spec.ts" \
  "packages/compiler/test/expression_parser/parser_spec.ts" \
  "packages/compiler/test/expression_parser/utils/unparser.ts" \
  "packages/compiler/test/expression_parser/utils/validator.ts" \
  "packages/compiler/test/render3/r3_template_transform_spec.ts" \
  "packages/compiler/test/render3/util/expression.ts"