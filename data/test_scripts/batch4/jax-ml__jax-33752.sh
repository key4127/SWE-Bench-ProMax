#!/bin/bash
set -uxo pipefail

# Set environment variables for CPU-only execution
export JAX_PLATFORMS=cpu
export PYTHONUNBUFFERED=1
export JAX_TRACEBACK_FILTERING=off

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout c593739e7aaae70dfbb2d931c73dafb0c07d594f "tests/lax_numpy_indexing_test.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/lax_numpy_indexing_test.py b/tests/lax_numpy_indexing_test.py
--- a/tests/lax_numpy_indexing_test.py
+++ b/tests/lax_numpy_indexing_test.py
@@ -473,7 +473,7 @@ def test_simple_indexing(self, name, shape, dtype, indexer, strategy):
       ((2, 3), ([1, 2], 0), TypeError, "static_slice: indices must be static scalars or slices."),
       ((2, 3), (np.arange(2), 0), TypeError, "static_slice: indices must be static scalars or slices."),
       ((2, 3), (None, 0), TypeError, "static_slice: got None at position 0"),
-      ((2, 3), (1, 2, 3), IndexError, "Too many indices: 2-dimensional array indexed with 3 regular indices"),
+      ((2, 3), (1, 2, 3), IndexError, "Too many indices: array is 2-dimensional, but 3 were indexed"),
   )
   def test_slice_oob_indexing_fails(self, shape, idx, err, msg):
     arr = jnp.zeros(shape)
@@ -1335,11 +1335,11 @@ def _check_raises(x_type, y_type, msg):
   def testWrongNumberOfIndices(self):
     with self.assertRaisesRegex(
         IndexError,
-        "Too many indices: 0-dimensional array indexed with 1 regular index."):
+        "Too many indices: array is 0-dimensional, but 1 were indexed"):
       jnp.array(1)[0]
     with self.assertRaisesRegex(
         IndexError,
-        "Too many indices: 1-dimensional array indexed with 2 regular indices."):
+        "Too many indices: array is 1-dimensional, but 2 were indexed"):
       jnp.zeros(3)[:, 5]
 
   @jtu.sample_product(shape=[(), (1,)])
@@ -1350,6 +1350,13 @@ def testIndexDtypePromotion(self, shape):
     expected = np.array(999).reshape(shape)
     self.assertArraysEqual(numbers[999, idx], expected)
 
+  def testIndexingTypedNdArray(self):
+    x = jnp.arange(4)
+    i = dtypes.canonicalize_value(np.array([2, 0, 1]))
+    result = x[i]
+    expected = x[jnp.asarray(i)]
+    self.assertArraysEqual(result, expected)
+
 
 def _broadcastable_shapes(shape):
   """Returns all shapes that broadcast to `shape`."""
@@ -1863,8 +1870,9 @@ class ValidateIndicesTest(jtu.JaxTestCase):
       ((2, 3), np.index_exp[..., -4], IndexError, "index -4 out of bounds for axis 1 with size 3"),
       ((2, 3, 5), np.index_exp[3, :, 0], IndexError, "index 3 out of bounds for axis 0 with size 2"),
       ((2, 3, 5), np.index_exp[:5, :, 6], IndexError, "index 6 out of bounds for axis 2 with size 5"),
+      ((2, 3, 5), np.index_exp[:, [1, 2], 6], IndexError, "index 6 out of bounds for axis 2 with size 5"),
       ((2, 3, 5), np.index_exp[np.arange(3), 6, None], IndexError, "index 6 out of bounds for axis 1 with size 3"),
-      ((2, 3), (1, 2, 3), IndexError, "Too many indices: 2-dimensional array indexed with 3 regular indices"),
+      ((2, 3), (1, 2, 3), IndexError, "Too many indices: array is 2-dimensional, but 3 were indexed"),
   )
   def test_out_of_bound_indices(self, shape, idx, err, msg):
     """Test that out-of-bound indexing """
EOF_114329324912

# Execute the target test file using pytest
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
# --no-header to reduce output clutter
# -rA to show summary of all test outcomes
pytest -v --tb=short --no-header -rA tests/lax_numpy_indexing_test.py

# Capture exit code immediately
rc=$?

# Echo exit code for judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout c593739e7aaae70dfbb2d931c73dafb0c07d594f "tests/lax_numpy_indexing_test.py"