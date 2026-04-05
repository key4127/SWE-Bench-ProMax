#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 0cac227d9a8f2ae7f3c0fdfd81e123208b38e924 "tests/test_core.py" "tests/test_core_utils.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_core.py b/tests/test_core.py
--- a/tests/test_core.py
+++ b/tests/test_core.py
@@ -1608,3 +1608,83 @@ def test_transform_strict_with_valid_params():
     transform = A.Blur(strict=True, p=0.7, blur_limit=(3, 5))
     assert transform.p == 0.7
     assert transform.blur_limit == (3, 5)
+
+
+@pytest.mark.parametrize(
+    ["labels", "expected_type", "expected_dtype"],
+    [
+        # Numpy arrays should stay numpy arrays
+        (np.array([1, 2, 3], dtype=np.int32), np.ndarray, np.int32),
+        (np.array([1, 2, 3], dtype=np.int64), np.ndarray, np.int64),
+        (np.array([1.0, 2.0, 3.0], dtype=np.float32), np.ndarray, np.float32),
+        (np.array([1.0, 2.0, 3.0], dtype=np.float64), np.ndarray, np.float64),
+        # Lists should stay lists
+        ([1, 2, 3], list, None),
+        ([1.0, 2.0, 3.0], list, None),
+    ],
+)
+def test_label_type_preservation(labels, expected_type, expected_dtype):
+    """Test that both type (list/ndarray) and dtype are preserved."""
+    transform = Compose(
+        [NoOp(p=1.0)],
+        bbox_params=BboxParams(
+            format='pascal_voc',
+            label_fields=['labels']
+        )
+    )
+
+    transformed = transform(
+        image=np.zeros((100, 100, 3), dtype=np.uint8),
+        bboxes=[(0, 0, 10, 10), (10, 10, 20, 20), (20, 20, 30, 30)],
+        labels=labels
+    )
+
+    result_labels = transformed['labels']
+    assert isinstance(result_labels, expected_type)
+    if expected_dtype is not None:
+        assert result_labels.dtype == expected_dtype
+    if expected_type == list:
+        assert result_labels == labels
+    else:
+        np.testing.assert_array_equal(result_labels, labels)
+
+
+def test_string_labels():
+    # Create sample data
+    bboxes = [(0, 0, 10, 10), (10, 10, 20, 20), (20, 20, 30, 30)]
+    labels = ['cat', 'dog', 'bird']
+
+    transform = Compose(
+        [NoOp(p=1.0)],
+        bbox_params=BboxParams(
+            format='pascal_voc',
+            label_fields=['labels']
+        )
+    )
+
+    transformed = transform(
+        image=np.zeros((100, 100, 3), dtype=np.uint8),
+        bboxes=bboxes,
+        labels=labels
+    )
+
+    # Check that string labels are preserved exactly
+    assert transformed['labels'] == labels
+
+
+def test_empty_labels():
+    transform = Compose(
+        [NoOp(p=1.0)],
+        bbox_params=BboxParams(
+            format='pascal_voc',
+            label_fields=['labels']
+        )
+    )
+
+    transformed = transform(
+        image=np.zeros((100, 100, 3), dtype=np.uint8),
+        bboxes=[],
+        labels=[]
+    )
+
+    assert transformed['labels'] == []
diff --git a/tests/test_core_utils.py b/tests/test_core_utils.py
--- a/tests/test_core_utils.py
+++ b/tests/test_core_utils.py
@@ -1,7 +1,7 @@
 import numpy as np
 import pytest
 
-from albumentations.core.utils import LabelEncoder
+from albumentations.core.label_manager import LabelEncoder
 
 
 @pytest.mark.parametrize(
EOF_114329324912

# Run the target test files
# Using pytest with verbose output and single-process mode for stability
pytest tests/test_core.py tests/test_core_utils.py -v --tb=short --no-header -rA
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test files
git checkout 0cac227d9a8f2ae7f3c0fdfd81e123208b38e924 "tests/test_core.py" "tests/test_core_utils.py"