#!/bin/bash
set -uxo pipefail
cd /testbed

# Set PYTHONPATH without referencing unset variable
export PYTHONPATH=/testbed

# Checkout the target test file to ensure clean state
git checkout a8df4a7b8d13c139cff757c3904d5c0fe2c4a522 "tests/evaluate/test_evaluate.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/evaluate/test_evaluate.py b/tests/evaluate/test_evaluate.py
--- a/tests/evaluate/test_evaluate.py
+++ b/tests/evaluate/test_evaluate.py
@@ -1,6 +1,7 @@
 import signal
 import threading
 from unittest.mock import patch
+import pandas as pd
 
 import pytest
 
@@ -54,6 +55,30 @@ def test_evaluate_call():
     assert score == 100.0
 
 
+def test_construct_result_df():
+    devset = [new_example("What is 1+1?", "2"), new_example("What is 2+2?", "4")]
+    ev = Evaluate(
+        devset=devset,
+        metric=answer_exact_match,
+    )
+    results = [
+        (devset[0], {"answer": "2"}, 100.0),
+        (devset[1], {"answer": "4"}, 100.0),
+    ]
+    result_df = ev._construct_result_table(results, answer_exact_match.__name__)
+    pd.testing.assert_frame_equal(
+        result_df,
+        pd.DataFrame(
+            {
+                "question": ["What is 1+1?", "What is 2+2?"],
+                "example_answer": ["2", "4"],
+                "pred_answer": ["2", "4"],
+                "answer_exact_match": [100.0, 100.0],
+            }
+        )
+    )
+
+
 def test_multithread_evaluate_call():
     dspy.settings.configure(lm=DummyLM({"What is 1+1?": {"answer": "2"}, "What is 2+2?": {"answer": "4"}}))
     devset = [new_example("What is 1+1?", "2"), new_example("What is 2+2?", "4")]
EOF_114329324912

# Run target tests with pytest
# Using -xvs flags for better output (stop on first failure, verbose, no capture)
# Running in single-process mode for safety in virtualized environment
pytest -xvs tests/evaluate/test_evaluate.py
rc=$?

# Required: echo test status for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout a8df4a7b8d13c139cff757c3904d5c0fe2c4a522 "tests/evaluate/test_evaluate.py"

exit $rc