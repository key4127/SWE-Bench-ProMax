#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e2bd8e60f000b46bb632d9ed78939264c55629ef "pandas/tests/frame/methods/test_to_numpy.py" "pandas/tests/frame/test_reductions.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pandas/tests/frame/methods/test_to_numpy.py b/pandas/tests/frame/methods/test_to_numpy.py
--- a/pandas/tests/frame/methods/test_to_numpy.py
+++ b/pandas/tests/frame/methods/test_to_numpy.py
@@ -3,7 +3,9 @@
 
 from pandas import (
     DataFrame,
+    NaT,
     Timestamp,
+    date_range,
 )
 import pandas._testing as tm
 
@@ -41,3 +43,37 @@ def test_to_numpy_mixed_dtype_to_str(self):
         result = df.to_numpy(dtype=str)
         expected = np.array([["2020-01-01 00:00:00", "100.0"]], dtype=str)
         tm.assert_numpy_array_equal(result, expected)
+
+    def test_to_numpy_datetime_with_na(self):
+        # GH #53115
+        dti = date_range("2016-01-01", periods=3)
+        df = DataFrame(dti)
+        df.iloc[0, 0] = NaT
+        expected = np.array([[np.nan], [1.45169280e18], [1.45177920e18]])
+        result = df.to_numpy(float, na_value=np.nan)
+        tm.assert_numpy_array_equal(result, expected)
+
+        df = DataFrame(
+            {
+                "a": [Timestamp("1970-01-01"), Timestamp("1970-01-02"), NaT],
+                "b": [
+                    Timestamp("1970-01-01"),
+                    np.nan,
+                    Timestamp("1970-01-02"),
+                ],
+                "c": [
+                    1,
+                    np.nan,
+                    2,
+                ],
+            }
+        )
+        expected = np.array(
+            [
+                [0.00e00, 0.00e00, 1.00e00],
+                [8.64e04, np.nan, np.nan],
+                [np.nan, 8.64e04, 2.00e00],
+            ]
+        )
+        result = df.to_numpy(float, na_value=np.nan)
+        tm.assert_numpy_array_equal(result, expected)
diff --git a/pandas/tests/frame/test_reductions.py b/pandas/tests/frame/test_reductions.py
--- a/pandas/tests/frame/test_reductions.py
+++ b/pandas/tests/frame/test_reductions.py
@@ -1917,6 +1917,39 @@ def test_df_empty_nullable_min_count_1(self, opname, dtype, exp_dtype):
         expected = Series([pd.NA, pd.NA], dtype=exp_dtype, index=Index([0, 1]))
         tm.assert_series_equal(result, expected)
 
+    @pytest.mark.parametrize(
+        "data",
+        [
+            {"a": [0, 1, 2], "b": [pd.NaT, pd.NaT, pd.NaT]},
+            {"a": [0, 1, 2], "b": [Timestamp("1990-01-01"), pd.NaT, pd.NaT]},
+            {
+                "a": [0, 1, 2],
+                "b": [
+                    Timestamp("1990-01-01"),
+                    Timestamp("1991-01-01"),
+                    Timestamp("1992-01-01"),
+                ],
+            },
+            {
+                "a": [0, 1, 2],
+                "b": [pd.Timedelta("1 days"), pd.Timedelta("2 days"), pd.NaT],
+            },
+            {
+                "a": [0, 1, 2],
+                "b": [
+                    pd.Timedelta("1 days"),
+                    pd.Timedelta("2 days"),
+                    pd.Timedelta("3 days"),
+                ],
+            },
+        ],
+    )
+    def test_df_cov_pd_nat(self, data):
+        # GH #53115
+        df = DataFrame(data)
+        with pytest.raises(TypeError, match="not supported for cov"):
+            df.cov()
+
 
 def test_sum_timedelta64_skipna_false():
     # GH#17235
EOF_114329324912

# Run the target tests (no parallelism to ensure stability)
pytest --no-header -rA --tb=short -p no:cacheprovider pandas/tests/frame/methods/test_to_numpy.py pandas/tests/frame/test_reductions.py
rc=$?

# Required: echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout e2bd8e60f000b46bb632d9ed78939264c55629ef "pandas/tests/frame/methods/test_to_numpy.py" "pandas/tests/frame/test_reductions.py"