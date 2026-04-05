#!/bin/bash
set -uxo pipefail

# Set environment variables for CPU-only execution
export JAX_PLATFORMS=cpu

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout e63d2a499f2f0e8cc21daa7d09a254ea3174508a "tests/pallas/tpu_pallas_interpret_test.py" "tests/pallas/tpu_pallas_interpret_thread_map_test.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/pallas/tpu_pallas_interpret_test.py b/tests/pallas/tpu_pallas_interpret_test.py
--- a/tests/pallas/tpu_pallas_interpret_test.py
+++ b/tests/pallas/tpu_pallas_interpret_test.py
@@ -862,7 +862,7 @@ def f(x):
               dimension_semantics=('parallel',),
           ),
           interpret=pltpu.InterpretParams(
-              num_cores_per_device=2,
+              num_cores_or_threads_per_device=2,
               detect_races=False,
           ),
       )(x)
@@ -872,7 +872,7 @@ def f(x):
     np.testing.assert_allclose(y, 2.0 * x)
 
     with pltpu.force_tpu_interpret_mode(pltpu.InterpretParams(
-        num_cores_per_device=1,
+        num_cores_or_threads_per_device=1,
         detect_races=True,
     )):
       y = f(x).block_until_ready()
@@ -881,7 +881,7 @@ def f(x):
     self.assertEqual(trace_count[0], 2)
 
     with pltpu.force_tpu_interpret_mode(pltpu.InterpretParams(
-        num_cores_per_device=2,
+        num_cores_or_threads_per_device=2,
         detect_races=True,
     )):
       y = f(x).block_until_ready()
@@ -913,7 +913,7 @@ def kernel(x_ref, o_ref, vmem_ref):
             pltpu.VMEM((8, 128), x.dtype),
         ],
         interpret=pltpu.InterpretParams(
-            num_cores_per_device=2,
+            num_cores_or_threads_per_device=2,
             detect_races=True,
         ),
         compiler_params=pltpu.CompilerParams(
@@ -948,7 +948,7 @@ def kernel_call(s, num_cores_per_device, grid_point_recorder):
           out_specs=pl.BlockSpec((8, 128), lambda i, j: (i, j)),
           interpret=pltpu.InterpretParams(
               random_seed=12345,
-              num_cores_per_device=num_cores_per_device,
+              num_cores_or_threads_per_device=num_cores_per_device,
               grid_point_recorder=grid_point_recorder,
               detect_races=True,
           ),
diff --git a/tests/pallas/tpu_pallas_interpret_thread_map_test.py b/tests/pallas/tpu_pallas_interpret_thread_map_test.py
--- a/tests/pallas/tpu_pallas_interpret_thread_map_test.py
+++ b/tests/pallas/tpu_pallas_interpret_thread_map_test.py
@@ -19,7 +19,7 @@
 from absl.testing import absltest
 import jax
 from jax._src import test_util as jtu
-from jax._src.pallas.mosaic.interpret import interpret_pallas_call as mosaic_interpret
+from jax._src.pallas.mosaic.interpret.thread_map import thread_map
 
 
 jax.config.parse_flags_with_absl()
@@ -61,8 +61,11 @@ def f(core_index):
       del core_index
       jax.experimental.io_callback(_barrier, (), ordered=True)
 
-    mosaic_interpret._thread_map(f, 8)
+    thread_map(f, 8)
     self.assertEqual(max_concurrent_calls[0], 8)
+    # `thread_map` returns only after all threads have completed, so the final
+    # value of `concurrent_calls` should be zero.
+    self.assertEqual(concurrent_calls[0], 0)
 
 
 if __name__ == '__main__':
EOF_114329324912

# Execute the target test files using pytest
# Using single-process mode for stability (tests are thread-unsafe)
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
# --no-header to reduce output clutter
# -rA to show all test outcomes summary
pytest -v --tb=short --no-header -rA tests/pallas/tpu_pallas_interpret_test.py tests/pallas/tpu_pallas_interpret_thread_map_test.py

# Capture exit code immediately
rc=$?

# Echo exit code for judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout e63d2a499f2f0e8cc21daa7d09a254ea3174508a "tests/pallas/tpu_pallas_interpret_test.py" "tests/pallas/tpu_pallas_interpret_thread_map_test.py"