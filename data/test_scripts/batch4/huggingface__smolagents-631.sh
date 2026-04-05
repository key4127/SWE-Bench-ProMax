#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 3316dd7b114fe1c31db701173eae7fe1c68d3043 "tests/test_local_python_executor.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_local_python_executor.py b/tests/test_local_python_executor.py
--- a/tests/test_local_python_executor.py
+++ b/tests/test_local_python_executor.py
@@ -1149,15 +1149,14 @@ def test_evaluate_python_code_with_evaluate_delete(code, expected_error_message)
     ],
 )
 def test_evaluate_delete(code, state, expectation):
-    state["_operations_count"] = 0
     delete_node = ast.parse(code).body[0]
     if isinstance(expectation, Exception):
         with pytest.raises(type(expectation)) as exception_info:
             evaluate_delete(delete_node, state, {}, {}, [])
         assert str(expectation) in str(exception_info.value)
     else:
         evaluate_delete(delete_node, state, {}, {}, [])
-        del state["_operations_count"]
+        _ = state.pop("_operations_count", None)
         assert state == expectation
 
 
EOF_114329324912

# Run the target test file with pytest
# Using -sv for verbose output and --durations=0 to show test durations as recommended
# Running in single-process mode for stability in virtualized environment
pytest -sv --durations=0 tests/test_local_python_executor.py
rc=$?

# Required: echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 3316dd7b114fe1c31db701173eae7fe1c68d3043 "tests/test_local_python_executor.py"