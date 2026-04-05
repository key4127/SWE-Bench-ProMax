#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 2d4ca621700eed97f0cb8a19d02a05fc088b26d2 tests/template_tests/filter_tests/test_center.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/template_tests/filter_tests/test_center.py b/tests/template_tests/filter_tests/test_center.py
--- a/tests/template_tests/filter_tests/test_center.py
+++ b/tests/template_tests/filter_tests/test_center.py
@@ -35,6 +35,12 @@ def test_center(self):
     def test_non_string_input(self):
         self.assertEqual(center(123, 5), " 123 ")
 
+    def test_odd_input(self):
+        self.assertEqual(center("odd", 6), " odd  ")
+
+    def test_even_input(self):
+        self.assertEqual(center("even", 7), " even  ")
+
     def test_widths(self):
         value = "something"
         for i in range(-1, len(value) + 1):
EOF_114329324912

# Run the target test file
python tests/runtests.py template_tests.filter_tests.test_center
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 2d4ca621700eed97f0cb8a19d02a05fc088b26d2 tests/template_tests/filter_tests/test_center.py