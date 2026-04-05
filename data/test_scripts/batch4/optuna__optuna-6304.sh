#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 790899174e41f6e4929a6773faa66f469a8a817c "tests/gp_tests/test_gp.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/gp_tests/test_gp.py b/tests/gp_tests/test_gp.py
--- a/tests/gp_tests/test_gp.py
+++ b/tests/gp_tests/test_gp.py
@@ -104,3 +104,39 @@ def test_fit_kernel_params(
             + (gpr.kernel_scale != 1.0).sum()
             + (gpr.noise_var != 1.0).sum()
         )
+
+
+@pytest.mark.parametrize(
+    "x_shape", [(1, 3), (2, 3), (1, 2, 3), (2, 1, 3), (2, 2, 3), (2, 2, 2, 3)]
+)
+def test_posterior(x_shape: tuple[int, ...]) -> None:
+    rng = np.random.RandomState(0)
+    X = rng.random(size=(10, x_shape[-1]))
+    Y = rng.randn(10)
+    Y = (Y - Y.mean()) / Y.std()
+    log_prior = prior.default_log_prior
+    minimum_noise = prior.DEFAULT_MINIMUM_NOISE_VAR
+    gtol: float = 1e-2
+    gpr = GPRegressor(
+        X_train=torch.from_numpy(X),
+        y_train=torch.from_numpy(Y),
+        is_categorical=torch.from_numpy(np.zeros(X.shape[-1], dtype=bool)),
+        inverse_squared_lengthscales=torch.ones(X.shape[1], dtype=torch.float64),
+        kernel_scale=torch.tensor(1.0, dtype=torch.float64),
+        noise_var=torch.tensor(1.0, dtype=torch.float64),
+    )._fit_kernel_params(
+        log_prior=log_prior,
+        minimum_noise=minimum_noise,
+        deterministic_objective=False,
+        gtol=gtol,
+    )
+    x = rng.random(size=x_shape)
+    mean_joint, covar = gpr.posterior(torch.from_numpy(x), joint=True)
+    mean, var_ = gpr.posterior(torch.from_numpy(x), joint=False)
+    assert mean_joint.shape == mean.shape and torch.allclose(mean, mean_joint)
+    assert covar.shape == (*x_shape[:-1], x_shape[-2])
+    assert covar.diagonal(dim1=-2, dim2=-1).shape == var_.shape and torch.allclose(
+        covar.diagonal(dim1=-2, dim2=-1), var_
+    ), "Diagonal Check."
+    assert torch.allclose(covar, covar.transpose(-2, -1)), "Symmetric Check."
+    assert torch.all(torch.det(covar) >= 0.0), "Postive Semi-definite Check."
EOF_114329324912

# Run the target test file
pytest --no-header -rA --tb=short -p no:cacheprovider --color=yes -v tests/gp_tests/test_gp.py
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 790899174e41f6e4929a6773faa66f469a8a817c "tests/gp_tests/test_gp.py"