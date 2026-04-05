#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout e8dbc363b1505eaa9d40618c1ac2ff653ee98441 "packages/compiler/test/ml_parser/lexer_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/ml_parser/lexer_spec.ts b/packages/compiler/test/ml_parser/lexer_spec.ts
--- a/packages/compiler/test/ml_parser/lexer_spec.ts
+++ b/packages/compiler/test/ml_parser/lexer_spec.ts
@@ -380,6 +380,205 @@ describe('HtmlLexer', () => {
       });
     });
 
+    describe('selectorless directives', () => {
+      const options: TokenizeOptions = {selectorlessEnabled: true};
+
+      it('should parse a basic directive', () => {
+        expect(tokenizeAndHumanizeParts('<div @MyDir></div>', options)).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.DIRECTIVE_NAME, 'MyDir'],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should parse a directive with parentheses, but no attributes', () => {
+        expect(tokenizeAndHumanizeParts('<div @MyDir()></div>', options)).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.DIRECTIVE_NAME, 'MyDir'],
+          [TokenType.DIRECTIVE_OPEN],
+          [TokenType.DIRECTIVE_CLOSE],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should parse a directive with a single attribute without a value', () => {
+        expect(tokenizeAndHumanizeParts('<div @MyDir(foo)></div>', options)).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.DIRECTIVE_NAME, 'MyDir'],
+          [TokenType.DIRECTIVE_OPEN],
+          [TokenType.ATTR_NAME, '', 'foo'],
+          [TokenType.DIRECTIVE_CLOSE],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should parse a directive with attributes', () => {
+        const tokens = tokenizeAndHumanizeParts(
+          '<div @MyDir(static="one" [bound]="expr" [(twoWay)]="expr" #ref="name" (click)="handler()")></div>',
+          options,
+        );
+
+        expect(tokens).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.DIRECTIVE_NAME, 'MyDir'],
+          [TokenType.DIRECTIVE_OPEN],
+          [TokenType.ATTR_NAME, '', 'static'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'one'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, '', '[bound]'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'expr'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, '', '[(twoWay)]'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'expr'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, '', '#ref'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'name'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, '', '(click)'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'handler()'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.DIRECTIVE_CLOSE],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should parse a directive mixed in with other attributes', () => {
+        const tokens = tokenizeAndHumanizeParts(
+          '<div before="value" @OneDir([one]="1" two="2") middle @TwoDir @ThreeDir((three)="handleThree()") after="value"></div>',
+          options,
+        );
+
+        expect(tokens).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.ATTR_NAME, '', 'before'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'value'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.DIRECTIVE_NAME, 'OneDir'],
+          [TokenType.DIRECTIVE_OPEN],
+          [TokenType.ATTR_NAME, '', '[one]'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, '1'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, '', 'two'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, '2'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.DIRECTIVE_CLOSE],
+          [TokenType.ATTR_NAME, '', 'middle'],
+          [TokenType.DIRECTIVE_NAME, 'TwoDir'],
+          [TokenType.DIRECTIVE_NAME, 'ThreeDir'],
+          [TokenType.DIRECTIVE_OPEN],
+          [TokenType.ATTR_NAME, '', '(three)'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'handleThree()'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.DIRECTIVE_CLOSE],
+          [TokenType.ATTR_NAME, '', 'after'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'value'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should not pick up selectorless-like text inside a tag', () => {
+        expect(tokenizeAndHumanizeParts('<div>@MyDir()</div>', options)).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.INCOMPLETE_BLOCK_OPEN, 'MyDir'],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should not pick up selectorless-like text inside an attribute', () => {
+        expect(tokenizeAndHumanizeParts('<div hello="@MyDir"></div>', options)).toEqual([
+          [TokenType.TAG_OPEN_START, '', 'div'],
+          [TokenType.ATTR_NAME, '', 'hello'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, '@MyDir'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.TAG_OPEN_END],
+          [TokenType.TAG_CLOSE, '', 'div'],
+          [TokenType.EOF],
+        ]);
+      });
+
+      it('should produce spans for directives', () => {
+        const tokens = tokenizeAndHumanizeSourceSpans(
+          '<div @Empty @NoAttrs() @WithAttr([one]="1" two="2") @WithSimpleAttr(simple)></div>',
+          options,
+        );
+
+        expect(tokens).toEqual([
+          [TokenType.TAG_OPEN_START, '<div'],
+          [TokenType.DIRECTIVE_NAME, '@Empty'],
+          [TokenType.DIRECTIVE_NAME, '@NoAttrs'],
+          [TokenType.DIRECTIVE_OPEN, '('],
+          [TokenType.DIRECTIVE_CLOSE, ')'],
+          [TokenType.DIRECTIVE_NAME, '@WithAttr'],
+          [TokenType.DIRECTIVE_OPEN, '('],
+          [TokenType.ATTR_NAME, '[one]'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, '1'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, 'two'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, '2'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.DIRECTIVE_CLOSE, ')'],
+          [TokenType.DIRECTIVE_NAME, '@WithSimpleAttr'],
+          [TokenType.DIRECTIVE_OPEN, '('],
+          [TokenType.ATTR_NAME, 'simple'],
+          [TokenType.DIRECTIVE_CLOSE, ')'],
+          [TokenType.TAG_OPEN_END, '>'],
+          [TokenType.TAG_CLOSE, '</div>'],
+          [TokenType.EOF, ''],
+        ]);
+      });
+
+      it('should not capture whitespace in directive spans', () => {
+        const tokens = tokenizeAndHumanizeSourceSpans(
+          '<div    @Dir   (  one="1"    (two)="handleTwo()"     )     ></div>',
+          options,
+        );
+
+        expect(tokens).toEqual([
+          [TokenType.TAG_OPEN_START, '<div'],
+          [TokenType.DIRECTIVE_NAME, '@Dir'],
+          [TokenType.DIRECTIVE_OPEN, '('],
+          [TokenType.ATTR_NAME, 'one'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, '1'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_NAME, '(two)'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.ATTR_VALUE_TEXT, 'handleTwo()'],
+          [TokenType.ATTR_QUOTE, '"'],
+          [TokenType.DIRECTIVE_CLOSE, ')'],
+          [TokenType.TAG_OPEN_END, '>'],
+          [TokenType.TAG_CLOSE, '</div>'],
+          [TokenType.EOF, ''],
+        ]);
+      });
+    });
+
     describe('escapable raw text', () => {
       it('should parse text', () => {
         expect(tokenizeAndHumanizeParts(`<title>t\ne\rs\r\nt</title>`)).toEqual([
EOF_114329324912

# Run the compiler ml_parser lexer test using Bazel
# Using bazelisk (installed globally) to automatically use the correct Bazel version (5.0.0)
# Target name is 'ml_parser' (jasmine_node_test) as defined in BUILD.bazel
# --test_output=errors shows only failed test output for cleaner logs
# --jobs=4 limits parallelism for system stability in virtualized environment
bazelisk test \
  //packages/compiler/test/ml_parser:ml_parser \
  --test_output=errors \
  --jobs=4

# Capture the exit code from the test
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout e8dbc363b1505eaa9d40618c1ac2ff653ee98441 "packages/compiler/test/ml_parser/lexer_spec.ts"