#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 125a749a9ab785757dd898e2f88bfb8fd3f65e11 "wagtail/admin/tests/test_edit_handlers.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/wagtail/admin/tests/test_edit_handlers.py b/wagtail/admin/tests/test_edit_handlers.py
--- a/wagtail/admin/tests/test_edit_handlers.py
+++ b/wagtail/admin/tests/test_edit_handlers.py
@@ -886,6 +886,12 @@ def _get_bound_panel(
             instance=self.event,
         )
 
+    def test_accessing_db_field_before_bind(self):
+        field_panel = FieldPanel("barbecue")
+
+        with self.assertRaises(ImproperlyConfigured):
+            field_panel.db_field
+
     def test_non_model_field(self):
         # defining a FieldPanel for a field which isn't part of a model is OK,
         # because it might be defined on the form instead
EOF_114329324912

# Run the target test file using the recommended test execution method
python runtests.py wagtail.admin.tests.test_edit_handlers
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 125a749a9ab785757dd898e2f88bfb8fd3f65e11 "wagtail/admin/tests/test_edit_handlers.py"