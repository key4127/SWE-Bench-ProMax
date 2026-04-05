#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 25edd9be211b71a2a905fabddb95d7d7945f919d "test/detection/test_vlm.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/test/detection/test_vlm.py b/test/detection/test_vlm.py
--- a/test/detection/test_vlm.py
+++ b/test/detection/test_vlm.py
@@ -1080,10 +1080,10 @@ def test_florence_2(
 def test_from_google_gemini_2_5(
     exception,
     result: str,
-    resolution_wh: Tuple[int, int],
-    classes: Optional[List[str]],
+    resolution_wh: tuple[int, int],
+    classes: Optional[list[str]],
     expected_results: Optional[
-        Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]
+        tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]
     ],
 ):
     with exception:
EOF_114329324912

# Run the target test file
pytest test/detection/test_vlm.py -v
rc=$?

# Capture and echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 25edd9be211b71a2a905fabddb95d7d7945f919d "test/detection/test_vlm.py"