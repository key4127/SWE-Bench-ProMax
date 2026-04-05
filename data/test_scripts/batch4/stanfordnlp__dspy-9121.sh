#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 7455afa896315fef359547c24c70f240bc80f5dd "tests/utils/test_usage_tracker.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/utils/test_usage_tracker.py b/tests/utils/test_usage_tracker.py
--- a/tests/utils/test_usage_tracker.py
+++ b/tests/utils/test_usage_tracker.py
@@ -190,6 +190,16 @@ def test_merge_usage_entries_with_none_values():
                 "prompt_tokens": 800,
                 "completion_tokens": 100,
                 "total_tokens": 900,
+                "prompt_tokens_details": None,
+                "completion_tokens_details": None,
+            },
+        },
+        {
+            "model": "gpt-4o-mini",
+            "usage": {
+                "prompt_tokens": 100,
+                "completion_tokens": 100,
+                "total_tokens": 200,
                 "prompt_tokens_details": {"cached_tokens": 50, "audio_tokens": 50},
                 "completion_tokens_details": None,
             },
@@ -216,9 +226,9 @@ def test_merge_usage_entries_with_none_values():
 
     total_usage = tracker.get_total_tokens()
 
-    assert total_usage["gpt-4o-mini"]["prompt_tokens"] == 2717
-    assert total_usage["gpt-4o-mini"]["completion_tokens"] == 246
-    assert total_usage["gpt-4o-mini"]["total_tokens"] == 2963
+    assert total_usage["gpt-4o-mini"]["prompt_tokens"] == 2817
+    assert total_usage["gpt-4o-mini"]["completion_tokens"] == 346
+    assert total_usage["gpt-4o-mini"]["total_tokens"] == 3163
     assert total_usage["gpt-4o-mini"]["prompt_tokens_details"]["cached_tokens"] == 50
     assert total_usage["gpt-4o-mini"]["prompt_tokens_details"]["audio_tokens"] == 50
     assert total_usage["gpt-4o-mini"]["completion_tokens_details"]["reasoning_tokens"] == 1
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
pytest tests/utils/test_usage_tracker.py -v --tb=short

# Capture exit code
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 7455afa896315fef359547c24c70f240bc80f5dd "tests/utils/test_usage_tracker.py"

# Exit with the test result code
exit $rc