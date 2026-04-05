#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file
git checkout cd2acf0476c7f0a9e7c7f00882a42993952ca8d3 "tests/conftest.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/conftest.py b/tests/conftest.py
--- a/tests/conftest.py
+++ b/tests/conftest.py
@@ -9,6 +9,7 @@
 from surya.ocr_error import OCRErrorPredictor
 from surya.layout import LayoutPredictor
 from surya.recognition import RecognitionPredictor
+from surya.foundation import FoundationPredictor
 from surya.table_rec import TableRecPredictor
 
 
@@ -35,7 +36,8 @@ def detection_predictor() -> DetectionPredictor:
 
 @pytest.fixture(scope="session")
 def recognition_predictor() -> RecognitionPredictor:
-    recognition_predictor = RecognitionPredictor()
+    foundation_predictor = FoundationPredictor()
+    recognition_predictor = RecognitionPredictor(foundation_predictor)
     yield recognition_predictor
     del recognition_predictor
 
EOF_114329324912

# Run the dependent test files that use fixtures from conftest.py
# According to collected info, these 6 test files depend on conftest.py fixtures:
# tests/test_detection.py, tests/test_recognition.py, tests/test_layout.py, 
# tests/test_table_rec.py, tests/test_ocr_errors.py, tests/test_latex_ocr.py
# Running all tests in the tests/ directory to ensure the modified fixtures work correctly
pytest --no-header -rA --tb=short -p no:cacheprovider tests/
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout cd2acf0476c7f0a9e7c7f00882a42993952ca8d3 "tests/conftest.py"