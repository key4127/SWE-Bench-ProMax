#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 53e404b75e9b29aae66a04040fb02ac1a5c87d07 nicegui/testing/screen.py tests/test_binding.py tests/test_page.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/nicegui/testing/screen.py b/nicegui/testing/screen.py
--- a/nicegui/testing/screen.py
+++ b/nicegui/testing/screen.py
@@ -258,7 +258,7 @@ def assert_py_logger(self, level: str, message: Union[str, re.Pattern]) -> None:
             else:
                 assert record.message.strip() == message, f'Expected "{message}" but got "{record.message}"'
         finally:
-            self.caplog.records.clear()
+            self.caplog.records.pop(0)
 
     @contextmanager
     def implicitly_wait(self, t: float) -> Generator[None, None, None]:
diff --git a/tests/test_binding.py b/tests/test_binding.py
--- a/tests/test_binding.py
+++ b/tests/test_binding.py
@@ -2,6 +2,7 @@
 import weakref
 from typing import Optional
 
+import pytest
 from selenium.webdriver.common.keys import Keys
 
 from nicegui import binding, ui
@@ -161,7 +162,7 @@ class Model:
         def __init__(self, value: str) -> None:
             self.value = value
 
-    def create_model_and_label(value: str) -> tuple[Model, weakref.ref, ui.label]:
+    def create_model_and_label(value: str) -> tuple[int, weakref.ref, ui.label]:
         model = Model(value)
         label = ui.label(value).bind_text(model, 'value')
         return id(model), weakref.ref(model), label
@@ -205,3 +206,32 @@ def change_a(self) -> None:
 
     await user.open('/')
     await user.should_see('a = 2')  # the final value of a should be 2
+
+
+def test_binding_other_dict_is_strict(screen: Screen):
+    data: dict[str, str] = {}
+    label = ui.label()
+    with pytest.raises(KeyError):
+        binding.bind(label, 'text', data, 'non_existent_key', other_strict=True)
+
+    screen.open('/')
+
+
+def test_binding_object_is_strict(screen: Screen):
+    class Model:
+        attribute = 'existing-attribute'
+    model = Model()
+    label = ui.label()
+    with pytest.raises(AttributeError):
+        binding.bind(model, 'no_attribute', label, 'no_text')
+
+    screen.open('/')
+
+
+def test_binding_dict_is_not_strict(screen: Screen):
+    data: dict[str, str] = {}
+    label = ui.label()
+    binding.bind(data, 'non_existing_key', label, 'text')
+
+    screen.open('/')
+    # no warning
diff --git a/tests/test_page.py b/tests/test_page.py
--- a/tests/test_page.py
+++ b/tests/test_page.py
@@ -192,6 +192,7 @@ async def page():
     screen.open('/')
     screen.should_contain('this is shown')
     screen.assert_py_logger('ERROR', 'some exception')
+    screen.assert_py_logger('ERROR', re.compile('Exception in callback'))
 
 
 def test_page_with_args(screen: Screen):
EOF_114329324912

# Run the target test files using Poetry
# Using -v for verbose output to help with debugging
# --driver Chrome for Selenium WebDriver
# --tb=short for concise traceback output
# Single-process mode for stability in virtualized environment
poetry run pytest tests/test_binding.py tests/test_page.py --driver Chrome -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 53e404b75e9b29aae66a04040fb02ac1a5c87d07 nicegui/testing/screen.py tests/test_binding.py tests/test_page.py

exit $rc