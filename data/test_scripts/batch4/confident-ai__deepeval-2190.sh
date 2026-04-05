#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout 46210f64b409b1a1506916ca7816e78afe309c9d "tests/test_core/test_tracing/test_execute_integration.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_core/test_tracing/test_execute_integration.py b/tests/test_core/test_tracing/test_execute_integration.py
--- a/tests/test_core/test_tracing/test_execute_integration.py
+++ b/tests/test_core/test_tracing/test_execute_integration.py
@@ -40,7 +40,7 @@ def _reset_eval_state():
     trace_manager.traces_to_evaluate.clear()
     trace_manager.integration_traces_to_evaluate.clear()
     trace_manager.test_case_metrics.clear()
-    trace_manager.trace_to_golden.clear()
+    trace_manager.trace_uuid_to_golden.clear()
 
 
 def test_execute_propagates_expected_output(monkeypatch):
EOF_114329324912

# Run the target test file using Poetry
# Using the test execution command from context retrieval agent
# Running in single-process mode for stability in virtualized environment
poetry run pytest -vv -rA --maxfail=1 --capture=tee-sys tests/test_core/test_tracing/test_execute_integration.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 46210f64b409b1a1506916ca7816e78afe309c9d "tests/test_core/test_tracing/test_execute_integration.py"