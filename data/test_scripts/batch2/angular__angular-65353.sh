#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 7ddf4a6b071db5d30d34a197a62d26ac9cc14286 "packages/compiler/test/i18n/i18n_ast_spec.ts"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/packages/compiler/test/i18n/i18n_ast_spec.ts b/packages/compiler/test/i18n/i18n_ast_spec.ts
--- a/packages/compiler/test/i18n/i18n_ast_spec.ts
+++ b/packages/compiler/test/i18n/i18n_ast_spec.ts
@@ -8,12 +8,10 @@
 
 import {createI18nMessageFactory} from '../../src/i18n/i18n_parser';
 import {Node} from '../../src/ml_parser/ast';
-import {DEFAULT_CONTAINER_BLOCKS} from '../../src/ml_parser/defaults';
 import {HtmlParser} from '../../src/ml_parser/html_parser';
 
 describe('Message', () => {
   const messageFactory = createI18nMessageFactory(
-    DEFAULT_CONTAINER_BLOCKS,
     /* retainEmptyTokens */ false,
     /* preserveExpressionWhitespace */ true,
   );
EOF_114329324912

# Ensure environment variables are set for headless Chrome
export CHROME_BIN=/usr/bin/google-chrome-stable
unset DISPLAY

# Run the target test using Bazel
# The test file i18n_ast_spec.ts is part of //packages/compiler/test:test target
bazelisk test \
  //packages/compiler/test:test \
  --test_output=errors \
  --jobs=4

# Capture the exit code
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 7ddf4a6b071db5d30d34a197a62d26ac9cc14286 "packages/compiler/test/i18n/i18n_ast_spec.ts"