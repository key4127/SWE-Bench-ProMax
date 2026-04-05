#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9bd352d89ca27f5cfa5fdb6388221966f5108bf7 "pandas/tests/frame/methods/test_describe.py" "pandas/tests/groupby/methods/test_describe.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pandas/tests/frame/methods/test_describe.py b/pandas/tests/frame/methods/test_describe.py
--- a/pandas/tests/frame/methods/test_describe.py
+++ b/pandas/tests/frame/methods/test_describe.py
@@ -413,3 +413,44 @@ def test_describe_exclude_pa_dtype(self):
             dtype=pd.ArrowDtype(pa.float64()),
         )
         tm.assert_frame_equal(result, expected)
+
+    @pytest.mark.parametrize("percentiles", [None, [], [0.2]])
+    def test_refine_percentiles(self, percentiles):
+        """
+        Test that the percentiles are returned correctly depending on the `percentiles`
+        argument.
+        - The default behavior is to return the 25th, 50th, and 75 percentiles
+        - If `percentiles` is an empty list, no percentiles are returned
+        - If `percentiles` is a non-empty list, only those percentiles are returned
+        """
+        # GH#60550
+        df = DataFrame({"a": np.arange(0, 10, 1)})
+
+        result = df.describe(percentiles=percentiles)
+
+        if percentiles is None:
+            percentiles = [0.25, 0.5, 0.75]
+
+        expected = DataFrame(
+            [
+                len(df.a),
+                df.a.mean(),
+                df.a.std(),
+                df.a.min(),
+                *[df.a.quantile(p) for p in percentiles],
+                df.a.max(),
+            ],
+            index=pd.Index(
+                [
+                    "count",
+                    "mean",
+                    "std",
+                    "min",
+                    *[f"{p:.0%}" for p in percentiles],
+                    "max",
+                ]
+            ),
+            columns=["a"],
+        )
+
+        tm.assert_frame_equal(result, expected)
diff --git a/pandas/tests/groupby/methods/test_describe.py b/pandas/tests/groupby/methods/test_describe.py
--- a/pandas/tests/groupby/methods/test_describe.py
+++ b/pandas/tests/groupby/methods/test_describe.py
@@ -202,15 +202,15 @@ def test_describe_duplicate_columns():
     gb = df.groupby(df[1])
     result = gb.describe(percentiles=[])
 
-    columns = ["count", "mean", "std", "min", "50%", "max"]
+    columns = ["count", "mean", "std", "min", "max"]
     frames = [
-        DataFrame([[1.0, val, np.nan, val, val, val]], index=[1], columns=columns)
+        DataFrame([[1.0, val, np.nan, val, val]], index=[1], columns=columns)
         for val in (0.0, 2.0, 3.0)
     ]
     expected = pd.concat(frames, axis=1)
     expected.columns = MultiIndex(
         levels=[[0, 2], columns],
-        codes=[6 * [0] + 6 * [1] + 6 * [0], 3 * list(range(6))],
+        codes=[5 * [0] + 5 * [1] + 5 * [0], 3 * list(range(5))],
     )
     expected.index.names = [1]
     tm.assert_frame_equal(result, expected)
EOF_114329324912

# Run the target tests with appropriate pytest flags
# Using single-process mode for stability in virtualized environment
# --strict-markers and --strict-config as per context retrieval agent recommendations
pytest --no-header -rA --tb=short -p no:cacheprovider \
    --strict-markers --strict-config \
    pandas/tests/frame/methods/test_describe.py \
    pandas/tests/groupby/methods/test_describe.py

rc=$?

# Required: echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 9bd352d89ca27f5cfa5fdb6388221966f5108bf7 "pandas/tests/frame/methods/test_describe.py" "pandas/tests/groupby/methods/test_describe.py"