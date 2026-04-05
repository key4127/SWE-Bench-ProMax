#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 786e24fb65ba62909cef7d90cec633671666d262 tests/test_binding.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_binding.py b/tests/test_binding.py
--- a/tests/test_binding.py
+++ b/tests/test_binding.py
@@ -1,3 +1,4 @@
+import weakref
 from typing import Dict, Optional, Tuple
 
 from selenium.webdriver.common.keys import Keys
@@ -125,3 +126,35 @@ class TestClass:
     assert len(binding.bindings) == 2
     assert len(binding.active_links) == 1
     assert binding.active_links[0][1] == 'not_bindable'
+
+
+def test_automatic_cleanup(screen: Screen):
+    class Model:
+        value = binding.BindableProperty()
+
+        def __init__(self, value: str) -> None:
+            self.value = value
+
+    def create_model_and_label(value: str) -> Tuple[Model, weakref.ref, ui.label]:
+        model = Model(value)
+        label = ui.label(value).bind_text(model, 'value')
+        return id(model), weakref.ref(model), label
+
+    model_id1, ref1, label1 = create_model_and_label('first label')
+    model_id2, ref2, _label2 = create_model_and_label('second label')
+
+    def is_alive(ref: weakref.ref) -> bool:
+        return ref() is not None
+
+    def has_bindable_property(model_id: int) -> bool:
+        return any(obj_id == model_id for obj_id, _ in binding.bindable_properties)
+
+    screen.open('/')
+    screen.should_contain('first label')
+    screen.should_contain('second label')
+    assert is_alive(ref1) and has_bindable_property(model_id1)
+    assert is_alive(ref2) and has_bindable_property(model_id2)
+
+    binding.remove([label1])
+    assert not is_alive(ref1) and not has_bindable_property(model_id1)
+    assert is_alive(ref2) and has_bindable_property(model_id2)
EOF_114329324912

# Run the target test file using Poetry
# Using -v for verbose output to help with debugging
# No parallel execution to ensure stability in virtualized environment
poetry run pytest tests/test_binding.py -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 786e24fb65ba62909cef7d90cec633671666d262 tests/test_binding.py