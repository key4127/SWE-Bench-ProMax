#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 214e474e36af74f84bb0c833c7c4e7a4d68b89e4 "pandas/tests/plotting/frame/test_frame.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pandas/tests/plotting/frame/test_frame.py b/pandas/tests/plotting/frame/test_frame.py
--- a/pandas/tests/plotting/frame/test_frame.py
+++ b/pandas/tests/plotting/frame/test_frame.py
@@ -840,14 +840,26 @@ def test_plot_scatter_shape(self):
         axes = df.plot(x="x", y="y", kind="scatter", subplots=True)
         _check_axes_shape(axes, axes_num=1, layout=(1, 1))
 
-    def test_raise_error_on_datetime_time_data(self):
-        # GH 8113, datetime.time type is not supported by matplotlib in scatter
+    def test_scatter_on_datetime_time_data(self):
+        # datetime.time type is now supported in scatter, since a converter
+        # is implemented in ScatterPlot
         df = DataFrame(np.random.default_rng(2).standard_normal(10), columns=["a"])
         df["dtime"] = date_range(start="2014-01-01", freq="h", periods=10).time
-        msg = "must be a string or a (real )?number, not 'datetime.time'"
+        df.plot(kind="scatter", x="dtime", y="a")
 
-        with pytest.raises(TypeError, match=msg):
-            df.plot(kind="scatter", x="dtime", y="a")
+    def test_scatter_line_xticks(self):
+        # GH#61005
+        df = DataFrame(
+            [(datetime(year=2025, month=1, day=1, hour=n), n) for n in range(3)],
+            columns=["datetime", "y"],
+        )
+        fig, ax = plt.subplots(2, sharex=True)
+        df.plot.scatter(x="datetime", y="y", ax=ax[0])
+        scatter_xticks = ax[0].get_xticks()
+        df.plot(x="datetime", y="y", ax=ax[1])
+        line_xticks = ax[1].get_xticks()
+        assert scatter_xticks[0] == line_xticks[0]
+        assert scatter_xticks[-1] == line_xticks[-1]
 
     @pytest.mark.parametrize("x, y", [("dates", "vals"), (0, 1)])
     def test_scatterplot_datetime_data(self, x, y):
EOF_114329324912

# Verify critical dependencies are available
python -c "import pandas; print(f'pandas version: {pandas.__version__}')"
python -c "import matplotlib; print(f'matplotlib version: {matplotlib.__version__}')"
python -c "import scipy; print(f'scipy version: {scipy.__version__}')"
python -c "import matplotlib; print(f'matplotlib backend: {matplotlib.get_backend()}')"

# Run the target test (single-process mode for stability in virtualized environment)
pytest --no-header -rA --tb=short -p no:cacheprovider pandas/tests/plotting/frame/test_frame.py
rc=$?

# Required: echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout 214e474e36af74f84bb0c833c7c4e7a4d68b89e4 "pandas/tests/plotting/frame/test_frame.py"