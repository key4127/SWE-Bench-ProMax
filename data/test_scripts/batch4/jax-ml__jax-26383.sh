#!/bin/bash
set -uxo pipefail

# Set environment variables for CPU-only execution
export JAX_PLATFORMS=cpu
export PYTHONUNBUFFERED=1
export JAX_TRACEBACK_FILTERING=off

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout e56c7dc50257c52e71a05e0567c15d9fdb9765b1 "tests/debug_info_test.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/debug_info_test.py b/tests/debug_info_test.py
--- a/tests/debug_info_test.py
+++ b/tests/debug_info_test.py
@@ -1600,7 +1600,7 @@ def my_f(my_x):
         expected_jaxpr_debug_infos=[
             # TODO(necula): this should not be pointing into the JAX internals
             re.compile(r"traced_for=jit, fun=checked_fun at .*jax._src.checkify.py:.*, arg_names=args\[0\]"),
-            re.compile(r"traced_for=jit, fun=argsort at .*numpy.lax_numpy.py:.*, arg_names=a, result_paths="),
+            re.compile(r"traced_for=jit, fun=argsort at .*numpy.sorting.py:.*, arg_names=a, result_paths="),
             "traced_for=pmap, fun=my_f, arg_names=my_x, result_paths=[0]",
         ],
         expected_tracer_debug_infos=[
EOF_114329324912

# Execute the target test file using pytest
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
# --no-header to reduce output clutter
# -rA to show summary of all test outcomes
pytest -v --tb=short --no-header -rA tests/debug_info_test.py

# Capture exit code immediately
rc=$?

# Echo exit code for judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout e56c7dc50257c52e71a05e0567c15d9fdb9765b1 "tests/debug_info_test.py"