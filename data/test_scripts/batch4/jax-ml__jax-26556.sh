#!/bin/bash
set -uxo pipefail

# Set environment variables for CPU-only execution (redundant but explicit)
export JAX_PLATFORMS=cpu
export PYTHONUNBUFFERED=1
export JAX_TRACEBACK_FILTERING=off

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout a46a82b4dd9e7f54956b60f8097f4246aeada388 "tests/scipy_stats_test.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/scipy_stats_test.py b/tests/scipy_stats_test.py
--- a/tests/scipy_stats_test.py
+++ b/tests/scipy_stats_test.py
@@ -1104,6 +1104,103 @@ def args_maker():
                               tol=1e-3)
       self._CompileAndCheck(lax_fun, args_maker)
 
+  @genNamedParametersNArgs(4)
+  def testParetoPdf(self, shapes, dtypes):
+    rng = jtu.rand_positive(self.rng())
+    scipy_fun = osp_stats.pareto.pdf
+    lax_fun = lsp_stats.pareto.pdf
+
+    def args_maker():
+      x, b, loc, scale = map(rng, shapes, dtypes)
+      return [x, b, loc, scale]
+
+    with jtu.strict_promotion_if_dtypes_match(dtypes):
+      self._CheckAgainstNumpy(
+        scipy_fun, lax_fun, args_maker, check_dtypes=False, tol=1e-3
+      )
+      self._CompileAndCheck(lax_fun, args_maker)
+
+  @genNamedParametersNArgs(4)
+  def testParetoLogCdf(self, shapes, dtypes):
+    rng = jtu.rand_positive(self.rng())
+    scipy_fun = osp_stats.pareto.logcdf
+    lax_fun = lsp_stats.pareto.logcdf
+
+    def args_maker():
+      x, b, loc, scale = map(rng, shapes, dtypes)
+      return [x, b, loc, scale]
+
+    with jtu.strict_promotion_if_dtypes_match(dtypes):
+      self._CheckAgainstNumpy(
+        scipy_fun, lax_fun, args_maker, check_dtypes=False, tol=1e-3
+      )
+      self._CompileAndCheck(lax_fun, args_maker)
+
+  @genNamedParametersNArgs(4)
+  def testParetoCdf(self, shapes, dtypes):
+    rng = jtu.rand_positive(self.rng())
+    scipy_fun = osp_stats.pareto.cdf
+    lax_fun = lsp_stats.pareto.cdf
+
+    def args_maker():
+      x, b, loc, scale = map(rng, shapes, dtypes)
+      return [x, b, loc, scale]
+
+    with jtu.strict_promotion_if_dtypes_match(dtypes):
+      self._CheckAgainstNumpy(
+        scipy_fun, lax_fun, args_maker, check_dtypes=False, tol=1e-3
+      )
+      self._CompileAndCheck(lax_fun, args_maker)
+
+  @genNamedParametersNArgs(4)
+  def testParetoPpf(self, shapes, dtypes):
+    rng_positive = jtu.rand_positive(self.rng())
+    rng_uniform = jtu.rand_uniform(self.rng())
+    scipy_fun = osp_stats.pareto.ppf
+    lax_fun = lsp_stats.pareto.ppf
+
+    def args_maker():
+      q = rng_uniform(shapes[0], dtypes[0])
+      b, loc, scale = map(rng_positive, shapes[1:], dtypes[1:])
+      return [q, b, loc, scale]
+
+    with jtu.strict_promotion_if_dtypes_match(dtypes):
+      self._CheckAgainstNumpy(
+        scipy_fun, lax_fun, args_maker, check_dtypes=False, tol=1e-3
+      )
+      self._CompileAndCheck(lax_fun, args_maker)
+
+  @genNamedParametersNArgs(4)
+  def testParetoSf(self, shapes, dtypes):
+    rng = jtu.rand_positive(self.rng())
+    scipy_fun = osp_stats.pareto.sf
+    lax_fun = lsp_stats.pareto.sf
+
+    def args_maker():
+      x, b, loc, scale = map(rng, shapes, dtypes)
+      return [x, b, loc, scale]
+
+    with jtu.strict_promotion_if_dtypes_match(dtypes):
+      self._CheckAgainstNumpy(
+        scipy_fun, lax_fun, args_maker, check_dtypes=False, tol=1e-3
+      )
+      self._CompileAndCheck(lax_fun, args_maker)
+
+  @genNamedParametersNArgs(4)
+  def testParetoLogSf(self, shapes, dtypes):
+    rng = jtu.rand_positive(self.rng())
+    scipy_fun = osp_stats.pareto.logsf
+    lax_fun = lsp_stats.pareto.logsf
+
+    def args_maker():
+      x, b, loc, scale = map(rng, shapes, dtypes)
+      return [x, b, loc, scale]
+
+    with jtu.strict_promotion_if_dtypes_match(dtypes):
+      self._CheckAgainstNumpy(
+        scipy_fun, lax_fun, args_maker, check_dtypes=False, tol=1e-3
+      )
+      self._CompileAndCheck(lax_fun, args_maker)
 
   @genNamedParametersNArgs(4)
   def testTLogPdf(self, shapes, dtypes):
EOF_114329324912

# Execute the target test file using pytest
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
# --no-header to reduce output clutter
# -rA to show summary of all test outcomes
pytest -v --tb=short --no-header -rA tests/scipy_stats_test.py

# Capture exit code immediately
rc=$?

# Echo exit code for judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout a46a82b4dd9e7f54956b60f8097f4246aeada388 "tests/scipy_stats_test.py"