#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout c26d609974ef7c36715f23f0fbcdb3f9b5f8a663 tests/test_tokenizer.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_tokenizer.py b/tests/test_tokenizer.py
--- a/tests/test_tokenizer.py
+++ b/tests/test_tokenizer.py
@@ -98,6 +98,7 @@ def test_suppressed_tokens_minus_1():
         50358,
         50359,
         50360,
+        50361,
     )
 
 
@@ -106,7 +107,7 @@ def test_suppressed_tokens_minus_value():
 
     tokenizer = Tokenizer(model.hf_tokenizer, False)
     tokens = get_suppressed_tokens(tokenizer, [13])
-    assert tokens == (13, 50257, 50357, 50358, 50359, 50360)
+    assert tokens == (13, 50257, 50357, 50358, 50359, 50360, 50361)
 
 
 def test_split_on_unicode():
EOF_114329324912

# Run the target test file
# Note: Running in single-process mode for stability in virtualized environment
pytest tests/test_tokenizer.py -v --tb=short --no-header -rA
rc=$?

# Required: Echo exit code for judge evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Restore original test file
git checkout c26d609974ef7c36715f23f0fbcdb3f9b5f8a663 tests/test_tokenizer.py