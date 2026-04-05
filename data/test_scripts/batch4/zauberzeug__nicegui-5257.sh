#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout aa8a72bf5f0799ba656297663e1aea4213c61c5d tests/test_vbuild.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_vbuild.py b/tests/test_vbuild.py
--- a/tests/test_vbuild.py
+++ b/tests/test_vbuild.py
@@ -27,9 +27,7 @@ def test_template_only():
             <h1 data-TEST>Hello, World!</h1>
         </script>
     ''', css='''
-    ''', js='''
-        var TEST = Vue.component(\'TEST\', {template:"#tpl-TEST",});
-    ''')
+    ''', js='')
 
 
 def test_template_with_style():
@@ -48,9 +46,7 @@ def test_template_with_style():
         </script>
     ''', css='''
         h1 {color: red; }
-    ''', js='''
-        var TEST = Vue.component(\'TEST\', {template:"#tpl-TEST",});
-    ''')
+    ''', js='')
 
 
 def test_template_with_scoped_style():
@@ -69,9 +65,7 @@ def test_template_with_scoped_style():
         </script>
     ''', css='''
         *[data-TEST] h1 {color: red; }
-    ''', js='''
-        var TEST = Vue.component(\'TEST\', {template:"#tpl-TEST",});
-    ''')
+    ''', js='')
 
 
 def test_template_with_script():
@@ -94,13 +88,13 @@ def test_template_with_script():
         </script>
     ''', css='''
     ''', js='''
-        var TEST = Vue.component(\'TEST\', {template:"#tpl-TEST",
-                methods: {
-                    hello() {
-                        alert('Hello, World!');
-                    }
+        export default {
+            methods: {
+                hello() {
+                    alert('Hello, World!');
                 }
-            });
+            }
+        }
     ''')
 
 
EOF_114329324912

# Run the target test file
# Using -v for verbose output to help with debugging
# --tb=short for concise traceback output
# Single-process mode for stability in virtualized environment
pytest tests/test_vbuild.py -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout aa8a72bf5f0799ba656297663e1aea4213c61c5d tests/test_vbuild.py

exit $rc