#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure environment variables are set
export DEEPEVAL_TELEMETRY_OPT_OUT=1
export DEEPEVAL_DEBUG_ASYNC=1
export PYTHONFAULTHANDLER=1
export PYTHONASYNCIODEBUG=1
export PYTHONUNBUFFERED=1

# Checkout the original source code file (not a test file)
git checkout f420f5830786fa57dd6944d324a397509a99d4a6 "deepeval/test_run/test_run.py"

# Apply the test patch to the source code file
git apply -v - <<'EOF_114329324912'
diff --git a/deepeval/test_run/test_run.py b/deepeval/test_run/test_run.py
--- a/deepeval/test_run/test_run.py
+++ b/deepeval/test_run/test_run.py
@@ -28,6 +28,7 @@
     open_browser,
     shorten,
     format_turn,
+    len_short,
 )
 from deepeval.test_run.cache import global_test_run_cache_manager
 from deepeval.constants import CONFIDENT_TEST_CASE_BATCH_SIZE, HIDDEN_DIR
@@ -682,7 +683,7 @@ def display_results_table(
                         str(t.order),
                         t.role,
                         details,
-                        shorten(tool_names, 60),
+                        shorten(tool_names, len_short()),
                     )
 
                 console.print(turns_table)
EOF_114329324912

# Run the actual test files that test this module
# Using poetry run as recommended, with single-process mode for stability
poetry run pytest -vv -rA --maxfail=1 --capture=tee-sys tests/test_core/test_run/

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original source code file
git checkout f420f5830786fa57dd6944d324a397509a99d4a6 "deepeval/test_run/test_run.py"