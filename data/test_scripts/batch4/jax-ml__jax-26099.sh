#!/bin/bash
set -uxo pipefail

# Set environment variables for CPU-only execution
export JAX_PLATFORMS=cpu

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout a3a285dddc84b2ab98c9ec27b541b79fe347376e "tests/debug_info_test.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/debug_info_test.py b/tests/debug_info_test.py
--- a/tests/debug_info_test.py
+++ b/tests/debug_info_test.py
@@ -1203,11 +1203,7 @@ def my_index_map(i, j):
             # TODO(necula): missing Jaxpr debug info
             "None"],
         expected_tracer_debug_infos=[
-            # TODO(necula): arg_names seem to be wrong
-            # One tracer from every index map
-            "traced_for=pallas_call index_map, fun=my_index_map, arg_names=('i[0]', 'i[1]')",
-            "traced_for=pallas_call index_map, fun=my_index_map, arg_names=('i[0]', 'i[1]')",
-            "traced_for=pallas_call index_map, fun=my_index_map, arg_names=('i[0]', 'i[1]')",
+            "traced_for=pallas_call index_map, fun=my_index_map, arg_names=('i', 'j')",
             "traced_for=pallas_call, fun=my_kernel, arg_names=('x_ref', 'y_ref', 'o_ref')",
         ],
         check_lowering=False,  # We need interpret mode on CPU. TODO(necula)
EOF_114329324912

# Execute the target test file using pytest
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
# --no-header to reduce output clutter
pytest -v --tb=short --no-header -rA tests/debug_info_test.py

# Capture exit code immediately
rc=$?

# Echo exit code for judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout a3a285dddc84b2ab98c9ec27b541b79fe347376e "tests/debug_info_test.py"