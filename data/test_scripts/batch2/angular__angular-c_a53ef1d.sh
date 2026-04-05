#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout ae55578b9229c77e6aad16277456395c2f81aa6c "packages/compiler/test/expression_parser/lexer_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/expression_parser/lexer_spec.ts b/packages/compiler/test/expression_parser/lexer_spec.ts
--- a/packages/compiler/test/expression_parser/lexer_spec.ts
+++ b/packages/compiler/test/expression_parser/lexer_spec.ts
@@ -72,18 +72,6 @@ function expectErrorToken(token: Token, index: any, end: number, message: string
   expect(token.toString()).toEqual(message);
 }
 
-function expectRegExpBodyToken(token: any, index: number, end: number, str: string) {
-  expectToken(token, index, end);
-  expect(token.isRegExpBody()).toBe(true);
-  expect(token.toString()).toEqual(str);
-}
-
-function expectRegExpFlagsToken(token: any, index: number, end: number, str: string) {
-  expectToken(token, index, end);
-  expect(token.isRegExpFlags()).toBe(true);
-  expect(token.toString()).toEqual(str);
-}
-
 describe('lexer', () => {
   describe('token', () => {
     it('should tokenize a simple identifier', () => {
@@ -422,7 +410,7 @@ describe('lexer', () => {
       expectOperatorToken(lex('+=')[0], 0, 2, '+=');
       expectOperatorToken(lex('-=')[0], 0, 2, '-=');
       expectOperatorToken(lex('*=')[0], 0, 2, '*=');
-      expectOperatorToken(lex('a /= b')[1], 2, 4, '/=');
+      expectOperatorToken(lex('/=')[0], 0, 2, '/=');
       expectOperatorToken(lex('%=')[0], 0, 2, '%=');
       expectOperatorToken(lex('**=')[0], 0, 3, '**=');
       expectOperatorToken(lex('&&=')[0], 0, 3, '&&=');
@@ -685,141 +673,5 @@ describe('lexer', () => {
         expectStringToken(tokens[6], 23, 24, '', StringTokenKind.TemplateLiteralEnd);
       });
     });
-
-    describe('regular expressions', () => {
-      it('should tokenize a simple regex', () => {
-        const tokens: Token[] = lex('/abc/');
-        expect(tokens.length).toBe(1);
-        expectRegExpBodyToken(tokens[0], 0, 5, 'abc');
-      });
-
-      it('should tokenize a regex with flags', () => {
-        const tokens: Token[] = lex('/abc/gim');
-        expect(tokens.length).toBe(2);
-        expectRegExpBodyToken(tokens[0], 0, 5, 'abc');
-        expectRegExpFlagsToken(tokens[1], 5, 8, 'gim');
-      });
-
-      it('should tokenize an identifier immediately after a regex', () => {
-        const tokens: Token[] = lex('/abc/ g');
-        expect(tokens.length).toBe(2);
-        expectRegExpBodyToken(tokens[0], 0, 5, 'abc');
-        expectIdentifierToken(tokens[1], 6, 7, 'g');
-      });
-
-      it('should tokenize a regex with an escaped slashes', () => {
-        const tokens: Token[] = lex('/^http:\\/\\/foo\\.bar/');
-        expect(tokens.length).toBe(1);
-        expectRegExpBodyToken(tokens[0], 0, 20, '^http:\\/\\/foo\\.bar');
-      });
-
-      it('should tokenize a regex with un-escaped slashes in a character class', () => {
-        const tokens: Token[] = lex('/[a/]$/');
-        expect(tokens.length).toBe(1);
-        expectRegExpBodyToken(tokens[0], 0, 7, '[a/]$');
-      });
-
-      it('should tokenize a regex with a backslash', () => {
-        const tokens: Token[] = lex('/a\\w+/');
-        expect(tokens.length).toBe(1);
-        expectRegExpBodyToken(tokens[0], 0, 6, 'a\\w+');
-      });
-
-      it('should tokenize a method call on a regex', () => {
-        const tokens: Token[] = lex('/abc/.test("foo")');
-        expect(tokens.length).toBe(6);
-        expectRegExpBodyToken(tokens[0], 0, 5, 'abc');
-        expectCharacterToken(tokens[1], 5, 6, '.');
-        expectIdentifierToken(tokens[2], 6, 10, 'test');
-        expectCharacterToken(tokens[3], 10, 11, '(');
-        expectStringToken(tokens[4], 11, 16, 'foo', StringTokenKind.Plain);
-        expectCharacterToken(tokens[5], 16, 17, ')');
-      });
-
-      it('should tokenize a method call with a regex parameter', () => {
-        const tokens: Token[] = lex('"foo".match(/abc/)');
-        expect(tokens.length).toBe(6);
-        expectStringToken(tokens[0], 0, 5, 'foo', StringTokenKind.Plain);
-        expectCharacterToken(tokens[1], 5, 6, '.');
-        expectIdentifierToken(tokens[2], 6, 11, 'match');
-        expectCharacterToken(tokens[3], 11, 12, '(');
-        expectRegExpBodyToken(tokens[4], 12, 17, 'abc');
-        expectCharacterToken(tokens[5], 17, 18, ')');
-      });
-
-      it('should not tokenize a regex preceded by a square bracket', () => {
-        const tokens: Token[] = lex('a[0] /= b');
-        expect(tokens.length).toBe(6);
-        expectIdentifierToken(tokens[0], 0, 1, 'a');
-        expectCharacterToken(tokens[1], 1, 2, '[');
-        expectNumberToken(tokens[2], 2, 3, 0);
-        expectCharacterToken(tokens[3], 3, 4, ']');
-        expectOperatorToken(tokens[4], 5, 7, '/=');
-        expectIdentifierToken(tokens[5], 8, 9, 'b');
-      });
-
-      it('should not tokenize a regex preceded by an identifier', () => {
-        const tokens: Token[] = lex('a / b');
-        expect(tokens.length).toBe(3);
-        expectIdentifierToken(tokens[0], 0, 1, 'a');
-        expectOperatorToken(tokens[1], 2, 3, '/');
-        expectIdentifierToken(tokens[2], 4, 5, 'b');
-      });
-
-      it('should not tokenize a regex preceded by a number', () => {
-        const tokens: Token[] = lex('1 / b');
-        expect(tokens.length).toBe(3);
-        expectNumberToken(tokens[0], 0, 1, 1);
-        expectOperatorToken(tokens[1], 2, 3, '/');
-        expectIdentifierToken(tokens[2], 4, 5, 'b');
-      });
-
-      it('should not tokenize a regex that is preceded by a string', () => {
-        const tokens: Token[] = lex('"a" / b');
-        expect(tokens.length).toBe(3);
-        expectStringToken(tokens[0], 0, 3, 'a', StringTokenKind.Plain);
-        expectOperatorToken(tokens[1], 4, 5, '/');
-        expectIdentifierToken(tokens[2], 6, 7, 'b');
-      });
-
-      it('should not tokenize a regex preceded by a closing parenthesis', () => {
-        const tokens: Token[] = lex('(a) / b');
-        expect(tokens.length).toBe(5);
-        expectCharacterToken(tokens[0], 0, 1, '(');
-        expectIdentifierToken(tokens[1], 1, 2, 'a');
-        expectCharacterToken(tokens[2], 2, 3, ')');
-        expectOperatorToken(tokens[3], 4, 5, '/');
-        expectIdentifierToken(tokens[4], 6, 7, 'b');
-      });
-
-      it('should not tokenize a regex that is preceded by a keyword', () => {
-        const tokens: Token[] = lex('this / b');
-        expect(tokens.length).toBe(3);
-        expectKeywordToken(tokens[0], 0, 4, 'this');
-        expectOperatorToken(tokens[1], 5, 6, '/');
-        expectIdentifierToken(tokens[2], 7, 8, 'b');
-      });
-
-      it('should produce an error for an unterminated regex', () => {
-        expectErrorToken(
-          lex('/a')[0],
-          2,
-          2,
-          'Lexer Error: Unterminated regular expression at column 2 in expression [/a]',
-        );
-      });
-
-      it('should produce an error for a incorrectly-escaped regex', () => {
-        const tokens = lex('/a\\\\//');
-        expect(tokens.length).toBe(2);
-        expectRegExpBodyToken(tokens[0], 0, 5, 'a\\\\');
-        expectErrorToken(
-          tokens[1],
-          6,
-          6,
-          'Lexer Error: Unterminated regular expression at column 6 in expression [/a\\\\//]',
-        );
-      });
-    });
   });
 });
EOF_114329324912

# Execute the specific test target using Bazel
# Using the primary test target identified by the context retrieval agent
# --test_output=all provides detailed output for verification
# --flaky_test_attempts=1 ensures tests run only once
bazelisk test //packages/compiler/test/expression_parser:expression_parser --test_output=all --flaky_test_attempts=1
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout ae55578b9229c77e6aad16277456395c2f81aa6c "packages/compiler/test/expression_parser/lexer_spec.ts"