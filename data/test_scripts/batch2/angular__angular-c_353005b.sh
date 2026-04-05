#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 98998bbd4285d877e33d6bb889826b5bf2877288 \
  "packages/compiler/test/expression_parser/lexer_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/expression_parser/lexer_spec.ts b/packages/compiler/test/expression_parser/lexer_spec.ts
--- a/packages/compiler/test/expression_parser/lexer_spec.ts
+++ b/packages/compiler/test/expression_parser/lexer_spec.ts
@@ -6,7 +6,7 @@
  * found in the LICENSE file at https://angular.dev/license
  */
 
-import {Lexer, Token} from '@angular/compiler/src/expression_parser/lexer';
+import {Lexer, StringTokenKind, Token} from '@angular/compiler/src/expression_parser/lexer';
 
 function lex(text: string): any[] {
   return new Lexer().tokenize(text);
@@ -35,9 +35,16 @@ function expectNumberToken(token: any, index: number, end: number, n: number) {
   expect(token.toNumber()).toEqual(n);
 }
 
-function expectStringToken(token: any, index: number, end: number, str: string) {
+function expectStringToken(
+  token: any,
+  index: number,
+  end: number,
+  str: string,
+  kind: StringTokenKind,
+) {
   expectToken(token, index, end);
   expect(token.isString()).toBe(true);
+  expect(token.kind).toBe(kind);
   expect(token.toString()).toEqual(str);
 }
 
@@ -152,11 +159,11 @@ describe('lexer', () => {
     });
 
     it('should tokenize simple quoted strings', () => {
-      expectStringToken(lex('"a"')[0], 0, 3, 'a');
+      expectStringToken(lex('"a"')[0], 0, 3, 'a', StringTokenKind.Plain);
     });
 
     it('should tokenize quoted strings with escaped quotes', () => {
-      expectStringToken(lex('"a\\""')[0], 0, 5, 'a"');
+      expectStringToken(lex('"a\\""')[0], 0, 5, 'a"', StringTokenKind.Plain);
     });
 
     it('should tokenize a string', () => {
@@ -174,9 +181,9 @@ describe('lexer', () => {
       expectOperatorToken(tokens[10], 14, 15, '|');
       expectIdentifierToken(tokens[11], 15, 16, 'f');
       expectCharacterToken(tokens[12], 16, 17, ':');
-      expectStringToken(tokens[13], 17, 23, "a'c");
+      expectStringToken(tokens[13], 17, 23, "a'c", StringTokenKind.Plain);
       expectCharacterToken(tokens[14], 23, 24, ':');
-      expectStringToken(tokens[15], 24, 30, 'd"e');
+      expectStringToken(tokens[15], 24, 30, 'd"e', StringTokenKind.Plain);
     });
 
     it('should tokenize undefined', () => {
@@ -200,8 +207,8 @@ describe('lexer', () => {
     it('should tokenize quoted string', () => {
       const str = '[\'\\\'\', "\\""]';
       const tokens: Token[] = lex(str);
-      expectStringToken(tokens[1], 1, 5, "'");
-      expectStringToken(tokens[3], 7, 11, '"');
+      expectStringToken(tokens[1], 1, 5, "'", StringTokenKind.Plain);
+      expectStringToken(tokens[3], 7, 11, '"', StringTokenKind.Plain);
     });
 
     it('should tokenize escaped quoted string', () => {
@@ -376,5 +383,228 @@ describe('lexer', () => {
         'Lexer Error: Invalid numeric separator at column 6 in expression [1_2_3._456]',
       );
     });
+
+    describe('template literals', () => {
+      it('should tokenize template literal with no interpolations', () => {
+        const tokens: Token[] = lex('`hello world`');
+        expect(tokens.length).toBe(1);
+        expectStringToken(tokens[0], 0, 13, 'hello world', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize template literal containing strings', () => {
+        expectStringToken(lex('`a "b" c`')[0], 0, 9, `a "b" c`, StringTokenKind.TemplateLiteralEnd);
+        expectStringToken(lex("`a 'b' c`")[0], 0, 9, `a 'b' c`, StringTokenKind.TemplateLiteralEnd);
+        expectStringToken(
+          lex('`a \\`b\\` c`')[0],
+          0,
+          11,
+          'a `b` c',
+          StringTokenKind.TemplateLiteralEnd,
+        );
+        expectStringToken(
+          lex('`a "\'\\`b\\`\'" c`')[0],
+          0,
+          15,
+          `a "'\`b\`'" c`,
+          StringTokenKind.TemplateLiteralEnd,
+        );
+      });
+
+      it('should tokenize unicode inside a template string', () => {
+        const tokens: Token[] = lex('`\\u00A0`');
+        expect(tokens.length).toBe(1);
+        expect(tokens[0].toString()).toBe('\u00a0');
+      });
+
+      it('should tokenize template literal with an interpolation in the end', () => {
+        const tokens: Token[] = lex('`hello ${name}`');
+        expect(tokens.length).toBe(5);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectIdentifierToken(tokens[2], 9, 13, 'name');
+        expectOperatorToken(tokens[3], 13, 14, '}');
+        expectStringToken(tokens[4], 14, 15, '', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize template literal with an interpolation in the beginning', () => {
+        const tokens: Token[] = lex('`${name} Johnson`');
+        expect(tokens.length).toBe(5);
+        expectStringToken(tokens[0], 0, 1, '', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 1, 3, '${');
+        expectIdentifierToken(tokens[2], 3, 7, 'name');
+        expectOperatorToken(tokens[3], 7, 8, '}');
+        expectStringToken(tokens[4], 8, 17, ' Johnson', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize template literal with an interpolation in the middle', () => {
+        const tokens: Token[] = lex('`foo${bar}baz`');
+        expect(tokens.length).toBe(5);
+        expectStringToken(tokens[0], 0, 4, 'foo', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 4, 6, '${');
+        expectIdentifierToken(tokens[2], 6, 9, 'bar');
+        expectOperatorToken(tokens[3], 9, 10, '}');
+        expectStringToken(tokens[4], 10, 14, 'baz', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should be able to use interpolation characters inside template string', () => {
+        expectStringToken(lex('`foo $`')[0], 0, 7, 'foo $', StringTokenKind.TemplateLiteralEnd);
+        expectStringToken(lex('`foo }`')[0], 0, 7, 'foo }', StringTokenKind.TemplateLiteralEnd);
+        expectStringToken(
+          lex('`foo $ {}`')[0],
+          0,
+          10,
+          'foo $ {}',
+          StringTokenKind.TemplateLiteralEnd,
+        );
+        expectStringToken(
+          lex('`foo \\${bar}`')[0],
+          0,
+          13,
+          'foo ${bar}',
+          StringTokenKind.TemplateLiteralEnd,
+        );
+      });
+
+      it('should tokenize template literal with several interpolations', () => {
+        const tokens: Token[] = lex('`${a} - ${b} - ${c}`');
+        expect(tokens.length).toBe(13);
+        expectStringToken(tokens[0], 0, 1, '', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 1, 3, '${');
+        expectIdentifierToken(tokens[2], 3, 4, 'a');
+        expectOperatorToken(tokens[3], 4, 5, '}');
+        expectStringToken(tokens[4], 5, 8, ' - ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[5], 8, 10, '${');
+        expectIdentifierToken(tokens[6], 10, 11, 'b');
+        expectOperatorToken(tokens[7], 11, 12, '}');
+        expectStringToken(tokens[8], 12, 15, ' - ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[9], 15, 17, '${');
+        expectIdentifierToken(tokens[10], 17, 18, 'c');
+        expectOperatorToken(tokens[11], 18, 19, '}');
+      });
+
+      it('should tokenize template literal with an object literal inside the interpolation', () => {
+        const tokens: Token[] = lex('`foo ${{$: true}} baz`');
+        expect(tokens.length).toBe(9);
+        expectStringToken(tokens[0], 0, 5, 'foo ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 5, 7, '${');
+        expectCharacterToken(tokens[2], 7, 8, '{');
+        expectIdentifierToken(tokens[3], 8, 9, '$');
+        expectCharacterToken(tokens[4], 9, 10, ':');
+        expectKeywordToken(tokens[5], 11, 15, 'true');
+        expectCharacterToken(tokens[6], 15, 16, '}');
+        expectOperatorToken(tokens[7], 16, 17, '}');
+        expectStringToken(tokens[8], 17, 22, ' baz', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize template literal with template literals inside the interpolation', () => {
+        const tokens: Token[] = lex('`foo ${`hello ${`${a} - b`}`} baz`');
+        expect(tokens.length).toBe(13);
+        expectStringToken(tokens[0], 0, 5, 'foo ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 5, 7, '${');
+        expectStringToken(tokens[2], 7, 14, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[3], 14, 16, '${');
+        expectStringToken(tokens[4], 16, 17, '', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[5], 17, 19, '${');
+        expectIdentifierToken(tokens[6], 19, 20, 'a');
+        expectOperatorToken(tokens[7], 20, 21, '}');
+        expectStringToken(tokens[8], 21, 26, ' - b', StringTokenKind.TemplateLiteralEnd);
+        expectOperatorToken(tokens[9], 26, 27, '}');
+        expectStringToken(tokens[10], 27, 28, '', StringTokenKind.TemplateLiteralEnd);
+        expectOperatorToken(tokens[11], 28, 29, '}');
+        expectStringToken(tokens[12], 29, 34, ' baz', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize two template literal right after each other', () => {
+        const tokens: Token[] = lex('`hello ${name}``see ${name} later`');
+        expect(tokens.length).toBe(10);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectIdentifierToken(tokens[2], 9, 13, 'name');
+        expectOperatorToken(tokens[3], 13, 14, '}');
+        expectStringToken(tokens[4], 14, 15, '', StringTokenKind.TemplateLiteralEnd);
+        expectStringToken(tokens[5], 15, 20, 'see ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[6], 20, 22, '${');
+        expectIdentifierToken(tokens[7], 22, 26, 'name');
+        expectOperatorToken(tokens[8], 26, 27, '}');
+        expectStringToken(tokens[9], 27, 34, ' later', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize a concatenated template literal', () => {
+        const tokens: Token[] = lex('`hello ${name}` + 123');
+        expect(tokens.length).toBe(7);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectIdentifierToken(tokens[2], 9, 13, 'name');
+        expectOperatorToken(tokens[3], 13, 14, '}');
+        expectStringToken(tokens[4], 14, 15, '', StringTokenKind.TemplateLiteralEnd);
+        expectOperatorToken(tokens[5], 16, 17, '+');
+        expectNumberToken(tokens[6], 18, 21, 123);
+      });
+
+      it('should tokenize a template literal with a pipe inside an interpolation', () => {
+        const tokens: Token[] = lex('`hello ${name | capitalize}!!!`');
+        expect(tokens.length).toBe(7);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectIdentifierToken(tokens[2], 9, 13, 'name');
+        expectOperatorToken(tokens[3], 14, 15, '|');
+        expectIdentifierToken(tokens[4], 16, 26, 'capitalize');
+        expectOperatorToken(tokens[5], 26, 27, '}');
+        expectStringToken(tokens[6], 27, 31, '!!!', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should tokenize a template literal with a pipe inside a parenthesized interpolation', () => {
+        const tokens: Token[] = lex('`hello ${(name | capitalize)}!!!`');
+        expect(tokens.length).toBe(9);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectCharacterToken(tokens[2], 9, 10, '(');
+        expectIdentifierToken(tokens[3], 10, 14, 'name');
+        expectOperatorToken(tokens[4], 15, 16, '|');
+        expectIdentifierToken(tokens[5], 17, 27, 'capitalize');
+        expectCharacterToken(tokens[6], 27, 28, ')');
+        expectOperatorToken(tokens[7], 28, 29, '}');
+        expectStringToken(tokens[8], 29, 33, '!!!', StringTokenKind.TemplateLiteralEnd);
+      });
+
+      it('should produce an error if a template literal is not terminated', () => {
+        expectErrorToken(
+          lex('`hello')[0],
+          6,
+          6,
+          'Lexer Error: Unterminated template literal at column 6 in expression [`hello]',
+        );
+      });
+
+      it('should produce an error for an unterminated template literal with an interpolation', () => {
+        const tokens: Token[] = lex('`hello ${name}!');
+        expect(tokens.length).toBe(5);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectIdentifierToken(tokens[2], 9, 13, 'name');
+        expectOperatorToken(tokens[3], 13, 14, '}');
+        expectErrorToken(
+          tokens[4],
+          15,
+          15,
+          'Lexer Error: Unterminated template literal at column 15 in expression [`hello ${name}!]',
+        );
+      });
+
+      it('should produce an error for an unterminate template literal interpolation', () => {
+        const tokens: Token[] = lex('`hello ${name!`');
+        expect(tokens.length).toBe(5);
+        expectStringToken(tokens[0], 0, 7, 'hello ', StringTokenKind.TemplateLiteralPart);
+        expectOperatorToken(tokens[1], 7, 9, '${');
+        expectIdentifierToken(tokens[2], 9, 13, 'name');
+        expectOperatorToken(tokens[3], 13, 14, '!');
+        expectErrorToken(
+          tokens[4],
+          15,
+          15,
+          'Lexer Error: Unterminated template literal at column 15 in expression [`hello ${name!`]',
+        );
+      });
+    });
   });
 });
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# Run the target test using Bazel with the correct target name
# The correct target is 'expression_parser' as identified in BUILD.bazel
bazelisk test \
  //packages/compiler/test/expression_parser:expression_parser \
  --test_output=errors \
  --flaky_test_attempts=1 \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 98998bbd4285d877e33d6bb889826b5bf2877288 \
  "packages/compiler/test/expression_parser/lexer_spec.ts"