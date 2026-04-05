#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout b8abe060100ee2b6a526e7b14c53129475446c55 "pandas/tests/generic/test_finalize.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/pandas/tests/generic/test_finalize.py b/pandas/tests/generic/test_finalize.py
--- a/pandas/tests/generic/test_finalize.py
+++ b/pandas/tests/generic/test_finalize.py
@@ -427,53 +427,6 @@ def test_binops(request, args, annotate, all_binary_operators):
     if annotate == "right" and isinstance(right, int):
         pytest.skip("right is an int and doesn't support .attrs")
 
-    if not (isinstance(left, int) or isinstance(right, int)) and annotate != "both":
-        if not all_binary_operators.__name__.startswith("r"):
-            if annotate == "right" and isinstance(left, type(right)):
-                request.applymarker(
-                    pytest.mark.xfail(
-                        reason=f"{all_binary_operators} doesn't work when right has "
-                        f"attrs and both are {type(left)}"
-                    )
-                )
-            if not isinstance(left, type(right)):
-                if annotate == "left" and isinstance(left, pd.Series):
-                    request.applymarker(
-                        pytest.mark.xfail(
-                            reason=f"{all_binary_operators} doesn't work when the "
-                            "objects are different Series has attrs"
-                        )
-                    )
-                elif annotate == "right" and isinstance(right, pd.Series):
-                    request.applymarker(
-                        pytest.mark.xfail(
-                            reason=f"{all_binary_operators} doesn't work when the "
-                            "objects are different Series has attrs"
-                        )
-                    )
-        else:
-            if annotate == "left" and isinstance(left, type(right)):
-                request.applymarker(
-                    pytest.mark.xfail(
-                        reason=f"{all_binary_operators} doesn't work when left has "
-                        f"attrs and both are {type(left)}"
-                    )
-                )
-            if not isinstance(left, type(right)):
-                if annotate == "right" and isinstance(right, pd.Series):
-                    request.applymarker(
-                        pytest.mark.xfail(
-                            reason=f"{all_binary_operators} doesn't work when the "
-                            "objects are different Series has attrs"
-                        )
-                    )
-                elif annotate == "left" and isinstance(left, pd.Series):
-                    request.applymarker(
-                        pytest.mark.xfail(
-                            reason=f"{all_binary_operators} doesn't work when the "
-                            "objects are different Series has attrs"
-                        )
-                    )
     if annotate in {"left", "both"} and not isinstance(left, int):
         left.attrs = {"a": 1}
     if annotate in {"right", "both"} and not isinstance(right, int):
@@ -497,6 +450,18 @@ def test_binops(request, args, annotate, all_binary_operators):
     assert result.attrs == {"a": 1}
 
 
+@pytest.mark.parametrize("left", [pd.Series, pd.DataFrame])
+@pytest.mark.parametrize("right", [pd.Series, pd.DataFrame])
+def test_attrs_binary_operations(all_binary_operators, left, right):
+    # GH 51607
+    attrs = {"a": 1}
+    left = left([1])
+    left.attrs = attrs
+    right = right([2])
+    assert all_binary_operators(left, right).attrs == attrs
+    assert all_binary_operators(right, left).attrs == attrs
+
+
 # ----------------------------------------------------------------------------
 # Accessors
 
EOF_114329324912

# Run the target test (no parallelism to ensure stability)
pytest --no-header -rA --tb=short -p no:cacheprovider pandas/tests/generic/test_finalize.py
rc=$?

# Required: echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file
git checkout b8abe060100ee2b6a526e7b14c53129475446c55 "pandas/tests/generic/test_finalize.py"