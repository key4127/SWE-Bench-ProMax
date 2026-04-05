#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 971eafab96af63ac3d625a4a6df0c4f62f4cf30c "tests/unittests/utils/test_env_utils.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/utils/test_env_utils.py b/tests/unittests/utils/test_env_utils.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/utils/test_env_utils.py
@@ -0,0 +1,49 @@
+# Copyright 2025 Google LLC
+#
+# Licensed under the Apache License, Version 2.0 (the "License");
+# you may not use this file except in compliance with the License.
+# You may obtain a copy of the License at
+#
+#     http://www.apache.org/licenses/LICENSE-2.0
+#
+# Unless required by applicable law or agreed to in writing, software
+# distributed under the License is distributed on an "AS IS" BASIS,
+# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+# See the License for the specific language governing permissions and
+# limitations under the License.
+
+from google.adk.utils.env_utils import is_env_enabled
+import pytest
+
+
+@pytest.mark.parametrize(
+    'env_value,expected',
+    [
+        ('true', True),
+        ('TRUE', True),
+        ('TrUe', True),
+        ('1', True),
+        ('false', False),
+        ('FALSE', False),
+        ('0', False),
+        ('', False),
+    ],
+)
+def test_is_env_enabled(monkeypatch, env_value, expected):
+  """Test is_env_enabled with various environment variable values."""
+  monkeypatch.setenv('TEST_FLAG', env_value)
+  assert is_env_enabled('TEST_FLAG') is expected
+
+
+@pytest.mark.parametrize(
+    'default,expected',
+    [
+        ('0', False),
+        ('1', True),
+        ('true', True),
+    ],
+)
+def test_is_env_enabled_with_defaults(monkeypatch, default, expected):
+  """Test is_env_enabled when env var is not set with different defaults."""
+  monkeypatch.delenv('TEST_FLAG', raising=False)
+  assert is_env_enabled('TEST_FLAG', default=default) is expected
EOF_114329324912

# Verify the test file exists after patch application
echo "=== Verifying test file exists ==="
if [ -f "tests/unittests/utils/test_env_utils.py" ]; then
    echo "Test file found: tests/unittests/utils/test_env_utils.py"
else
    echo "ERROR: Test file not found after patch application"
    exit 1
fi
echo ""

# Run the target test file with pytest
# Using -v for verbose output, --tb=short for concise traceback, and --no-header to reduce clutter
# Running in single-process mode for stability in virtualized environment
echo "=== Running tests ==="
pytest tests/unittests/utils/test_env_utils.py -v --tb=short --no-header -rA

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 971eafab96af63ac3d625a4a6df0c4f62f4cf30c "tests/unittests/utils/test_env_utils.py"

# Exit with the captured return code
exit $rc