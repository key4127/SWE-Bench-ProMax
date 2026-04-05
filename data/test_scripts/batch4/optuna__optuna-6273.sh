#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 4b8add0683e10aeab215334e4e94a26ee8b7099f "tests/gp_tests/test_batched_lbfgsb.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/gp_tests/test_batched_lbfgsb.py b/tests/gp_tests/test_batched_lbfgsb.py
--- a/tests/gp_tests/test_batched_lbfgsb.py
+++ b/tests/gp_tests/test_batched_lbfgsb.py
@@ -9,11 +9,13 @@
 import pytest
 from scipy.optimize import fmin_l_bfgs_b
 
+from optuna._gp.batched_lbfgsb import batched_lbfgsb
+
 
 RADIUS = 5.12
 
 
-def rastrigin_and_grad(x: np.ndarray, batch_indices: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
+def rastrigin_and_grad(x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
     if x.ndim == 1:
         x = x[None]
     A = 10.0
@@ -25,9 +27,7 @@ def rastrigin_and_grad(x: np.ndarray, batch_indices: np.ndarray) -> tuple[np.nda
     return fval, grad
 
 
-def styblinski_tang_and_grad(
-    x: np.ndarray, batch_indices: np.ndarray
-) -> tuple[np.ndarray, np.ndarray]:
+def styblinski_tang_and_grad(x: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
     # Styblinski-Tang function, which has multiple local minima.
     if x.ndim == 1:
         x = x[None]
@@ -58,11 +58,8 @@ def _verify_results(
     xs_opt2 = []
     fvals_opt2 = []
     n_iters2 = []
-    batch_indices = np.array([])
     for x0 in X0:
-        x_opt, fval, info = fmin_l_bfgs_b(
-            func=func_and_grad, args=(batch_indices,), x0=x0, **kwargs_scipy
-        )
+        x_opt, fval, info = fmin_l_bfgs_b(func=func_and_grad, x0=x0, **kwargs_scipy)
         xs_opt2.append(x_opt)
         fvals_opt2.append(float(fval))
         n_iters2.append(info["nit"])
@@ -120,3 +117,37 @@ def test_batched_lbfgsb(
         kwargs_scipy,
         batched_lbfgsb_func=optimization_module.batched_lbfgsb,
     )
+
+
+def test_batched_lbfgsb_invalid_input() -> None:
+    batch_size = 3
+    dimension = 2
+    x0_batched = np.random.rand(batch_size, dimension)
+
+    # x0_batched validation
+    with pytest.raises(ValueError):
+        batched_lbfgsb(
+            func_and_grad=lambda x: (np.sum(x, axis=1), np.ones_like(x)),
+            x0_batched=x0_batched[0],  # not 2D
+        )
+
+    # batched_args validation
+    def dummy_func_and_grad(x: np.ndarray, _arg: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
+        return np.sum(x, axis=1), np.ones_like(x)
+
+    with pytest.raises(AssertionError):
+        batched_lbfgsb(
+            func_and_grad=dummy_func_and_grad,
+            x0_batched=x0_batched,
+            batched_args=([0] * (batch_size + 1),),  # wrong length
+        )
+
+    # bounds validation
+    invalid_bounds = [(0.0, 1.0)]  # length is not equal to dimension
+    with pytest.raises(AssertionError):
+        batched_lbfgsb(
+            func_and_grad=dummy_func_and_grad,
+            x0_batched=x0_batched,
+            batched_args=(list(range(batch_size)),),
+            bounds=invalid_bounds,
+        )
EOF_114329324912

# Run the target test file with appropriate pytest options
# Using single-process mode for stability in virtualized environment
# Adding warning filter as specified in collected information
pytest --no-header -rA --tb=short -p no:cacheprovider --color=yes -v \
    -W ignore::optuna.exceptions.ExperimentalWarning \
    tests/gp_tests/test_batched_lbfgsb.py
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 4b8add0683e10aeab215334e4e94a26ee8b7099f "tests/gp_tests/test_batched_lbfgsb.py"