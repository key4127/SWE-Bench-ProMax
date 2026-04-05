#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 9d139736da0f2c25002a86593c3f5deb2612e962 "tests/gp_tests/test_batched_lbfgsb.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/gp_tests/test_batched_lbfgsb.py b/tests/gp_tests/test_batched_lbfgsb.py
--- a/tests/gp_tests/test_batched_lbfgsb.py
+++ b/tests/gp_tests/test_batched_lbfgsb.py
@@ -119,24 +119,25 @@ def test_batched_lbfgsb(
     )
 
 
-def test_batched_lbfgsb_invalid_args_tuple_shape() -> None:
-    batch_size = 10
+def test_batched_lbfgsb_invalid_input() -> None:
+    batch_size = 3
     dimension = 2
     x0_batched = np.random.rand(batch_size, dimension)
 
+    # x0_batched validation
+    with pytest.raises(AssertionError):
+        batched_lbfgsb(
+            func_and_grad=lambda x: (np.sum(x, axis=1), np.ones_like(x)),
+            x0_batched=x0_batched[0],  # not 2D
+        )
+
+    # args_tuple validation
     def dummy_func_and_grad(x: np.ndarray, _arg: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
         return np.sum(x, axis=1), np.ones_like(x)
 
     with pytest.raises(ValueError):
         batched_lbfgsb(
             func_and_grad=dummy_func_and_grad,
             x0_batched=x0_batched,
-            args_tuple=(np.random.rand(5),),
-        )
-
-    with pytest.raises(TypeError):
-        batched_lbfgsb(
-            func_and_grad=dummy_func_and_grad,
-            x0_batched=x0_batched,
-            args_tuple=(1.0,),
+            args_tuple=([0] * (batch_size + 1),),  # wrong length
         )
EOF_114329324912

# Set environment variable (already set in Dockerfile, but ensuring it's set)
export SQLALCHEMY_WARN_20=1

# Run the target test file
pytest tests/gp_tests/test_batched_lbfgsb.py -v --color=yes --tb=short
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9d139736da0f2c25002a86593c3f5deb2612e962 "tests/gp_tests/test_batched_lbfgsb.py"