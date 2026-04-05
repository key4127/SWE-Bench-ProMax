#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 80795dfe5db3a6c089a2ffc31df5b8a324f8dd53 "pandas/tests/reshape/test_pivot.py" "pandas/tests/test_multilevel.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pandas/tests/reshape/test_pivot.py b/pandas/tests/reshape/test_pivot.py
--- a/pandas/tests/reshape/test_pivot.py
+++ b/pandas/tests/reshape/test_pivot.py
@@ -15,6 +15,7 @@
 
 import pandas as pd
 from pandas import (
+    ArrowDtype,
     Categorical,
     DataFrame,
     Grouper,
@@ -2851,3 +2852,31 @@ def test_pivot_margins_with_none_index(self):
             ),
         )
         tm.assert_frame_equal(result, expected)
+
+    @pytest.mark.filterwarnings("ignore:Passing a BlockManager:DeprecationWarning")
+    def test_pivot_with_pyarrow_categorical(self):
+        # GH#53051
+        pa = pytest.importorskip("pyarrow")
+
+        df = DataFrame(
+            {"string_column": ["A", "B", "C"], "number_column": [1, 2, 3]}
+        ).astype(
+            {
+                "string_column": ArrowDtype(pa.dictionary(pa.int32(), pa.string())),
+                "number_column": "float[pyarrow]",
+            }
+        )
+
+        df = df.pivot(columns=["string_column"], values=["number_column"])
+
+        multi_index = MultiIndex.from_arrays(
+            [["number_column", "number_column", "number_column"], ["A", "B", "C"]],
+            names=(None, "string_column"),
+        )
+        df_expected = DataFrame(
+            [[1.0, np.nan, np.nan], [np.nan, 2.0, np.nan], [np.nan, np.nan, 3.0]],
+            columns=multi_index,
+        )
+        tm.assert_frame_equal(
+            df, df_expected, check_dtype=False, check_column_type=False
+        )
diff --git a/pandas/tests/test_multilevel.py b/pandas/tests/test_multilevel.py
--- a/pandas/tests/test_multilevel.py
+++ b/pandas/tests/test_multilevel.py
@@ -5,6 +5,7 @@
 
 import pandas as pd
 from pandas import (
+    ArrowDtype,
     DataFrame,
     MultiIndex,
     Series,
@@ -318,6 +319,34 @@ def test_multiindex_dt_with_nan(self):
         expected = Series(["a", "b", "c", "d"], name=("sub", np.nan))
         tm.assert_series_equal(result, expected)
 
+    @pytest.mark.filterwarnings("ignore:Passing a BlockManager:DeprecationWarning")
+    def test_multiindex_with_pyarrow_categorical(self):
+        # GH#53051
+        pa = pytest.importorskip("pyarrow")
+
+        df = DataFrame(
+            {"string_column": ["A", "B", "C"], "number_column": [1, 2, 3]}
+        ).astype(
+            {
+                "string_column": ArrowDtype(pa.dictionary(pa.int32(), pa.string())),
+                "number_column": "float[pyarrow]",
+            }
+        )
+
+        df = df.set_index(["string_column", "number_column"])
+
+        df_expected = DataFrame(
+            index=MultiIndex.from_arrays(
+                [["A", "B", "C"], [1, 2, 3]], names=["string_column", "number_column"]
+            )
+        )
+        tm.assert_frame_equal(
+            df,
+            df_expected,
+            check_index_type=False,
+            check_column_type=False,
+        )
+
 
 class TestSorted:
     """everything you wanted to test about sorting"""
EOF_114329324912

# Run the target tests with appropriate pytest flags
# Using single-process mode for stability in virtualized environment
# --strict-markers and --strict-config as per context retrieval agent recommendations
pytest --no-header -rA --tb=short -p no:cacheprovider \
    --strict-markers --strict-config \
    pandas/tests/reshape/test_pivot.py \
    pandas/tests/test_multilevel.py

rc=$?

# Required: echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test files
git checkout 80795dfe5db3a6c089a2ffc31df5b8a324f8dd53 "pandas/tests/reshape/test_pivot.py" "pandas/tests/test_multilevel.py"