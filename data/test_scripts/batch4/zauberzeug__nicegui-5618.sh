#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Start Xvfb in the background for headless Chrome testing
Xvfb :99 -screen 0 1920x1080x24 > /dev/null 2>&1 &
XVFB_PID=$!

# Give Xvfb a moment to start
sleep 2

# Ensure DISPLAY is set
export DISPLAY=:99

# Checkout the original test files to ensure clean state
git checkout e4ed5ea4c6e960c9cccfd6fb34b78953276d7bd7 tests/test_page.py tests/test_sub_pages.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_page.py b/tests/test_page.py
--- a/tests/test_page.py
+++ b/tests/test_page.py
@@ -133,27 +133,35 @@ async def page():
 
 
 def test_exception(screen: Screen):
+    exceptions = []
+
     @ui.page('/')
     def page():
+        ui.on_exception(exceptions.append)
         raise RuntimeError('some exception')
 
     screen.allowed_js_errors.append('/ - Failed to load resource')
     screen.open('/')
     screen.should_contain('500')
     screen.should_contain('Server error')
     screen.assert_py_logger('ERROR', 'some exception')
+    assert not exceptions, 'ui.on_exception is for in-page exceptions (after page sent to browser)'
 
 
 def test_exception_after_connected(screen: Screen):
+    exceptions = []
+
     @ui.page('/')
     async def page():
+        ui.on_exception(exceptions.append)
         await ui.context.client.connected()
         ui.label('this is shown')
         raise RuntimeError('some exception')
 
     screen.open('/')
     screen.should_contain('this is shown')
     screen.assert_py_logger('ERROR', 'some exception')
+    assert exceptions, 'in-page exception should be caught by ui.on_exception'
 
 
 def test_api_exception(screen: Screen):
diff --git a/tests/test_sub_pages.py b/tests/test_sub_pages.py
--- a/tests/test_sub_pages.py
+++ b/tests/test_sub_pages.py
@@ -980,9 +980,12 @@ def other():
 
 
 def test_exception_in_page_builder(screen: Screen):
+    exceptions = []
+
     @ui.page('/')
     @ui.page('/{_:path}')
     def index():
+        ui.on_exception(exceptions.append)
         ui.link('Go to exception', '/')
         ui.link('Go to content with exception', '/content_with_exception')
         ui.link('Go to async exception', '/async')
@@ -1028,6 +1031,8 @@ async def async_exception():
     screen.assert_py_logger('ERROR', msg_content)
     screen.should_not_contain('content before exception')
 
+    assert len(exceptions) == 4
+
 
 def test_disabling_404(screen: Screen):
     @ui.page('/')
EOF_114329324912

# Run the target test files using uv
# Using -v for verbose output
# --tb=short for concise traceback output
# Single-process mode for stability in virtualized environment
uv run pytest tests/test_page.py tests/test_sub_pages.py -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout e4ed5ea4c6e960c9cccfd6fb34b78953276d7bd7 tests/test_page.py tests/test_sub_pages.py

# Clean up Xvfb process
kill $XVFB_PID 2>/dev/null || true

exit $rc