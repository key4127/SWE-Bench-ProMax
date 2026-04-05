#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 9944a4045543d2a6ae25cc5f06235e3c93c7a58e tests/test_refreshable.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_refreshable.py b/tests/test_refreshable.py
--- a/tests/test_refreshable.py
+++ b/tests/test_refreshable.py
@@ -235,3 +235,43 @@ def page():
 
     screen.open('/')
     screen.should_contain('42')
+
+
+def test_awaitable_refresh(screen: Screen):
+    events = []
+
+    @ui.refreshable
+    async def content(number: int):
+        events.append('refresh started')
+        await asyncio.sleep(0.5)
+        ui.label(f'1 / {number} = {1 / number}')
+        events.append('refresh finished')
+
+    async def update(number: int):
+        events.append('update started')
+        try:
+            await content.refresh(number)
+        except ZeroDivisionError:
+            events.append('refresh failed')
+            ui.label('error handled')
+        events.append('update finished')
+
+    @ui.page('/')
+    async def page():
+        await content(1)
+        ui.button('Try 2', on_click=lambda: update(2))
+        ui.button('Try 0', on_click=lambda: update(0))
+
+    screen.open('/')
+    screen.should_contain('1 / 1 = 1.0')
+    assert events == ['refresh started', 'refresh finished']
+
+    events.clear()
+    screen.click('Try 2')
+    screen.should_contain('1 / 2 = 0.5')
+    assert events == ['update started', 'refresh started', 'refresh finished', 'update finished']
+
+    events.clear()
+    screen.click('Try 0')
+    screen.should_contain('error handled')
+    assert events == ['update started', 'refresh started', 'refresh failed', 'update finished']
EOF_114329324912

# Run the target test file using Poetry
# Using -v for verbose output to help with debugging
# --driver Chrome for Selenium WebDriver
# --tb=short for concise traceback output
# Single-process mode for stability in virtualized environment
poetry run pytest tests/test_refreshable.py --driver Chrome -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 9944a4045543d2a6ae25cc5f06235e3c93c7a58e tests/test_refreshable.py

exit $rc