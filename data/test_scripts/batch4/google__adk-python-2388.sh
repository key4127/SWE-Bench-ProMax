#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the target test file to ensure it's at the correct commit
git checkout 54cc849de7e4c01e7954b2d896cc47d0ec390886 \
    "tests/unittests/tools/test_tool_config.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/tools/test_tool_config.py b/tests/unittests/tools/test_tool_config.py
--- a/tests/unittests/tools/test_tool_config.py
+++ b/tests/unittests/tools/test_tool_config.py
@@ -13,7 +13,7 @@
 # limitations under the License.
 
 from google.adk.tools import VertexAiSearchTool
-from google.adk.tools.base_tool import ToolConfig
+from google.adk.tools.tool_configs import ToolConfig
 from google.genai import types
 import yaml
 
EOF_114329324912

# Verify the test file exists after patch application
echo "=== Verifying test file exists ==="
if [ -f "tests/unittests/tools/test_tool_config.py" ]; then
    echo "Test file found: tests/unittests/tools/test_tool_config.py"
else
    echo "ERROR: Test file not found after patch application"
    exit 1
fi
echo ""

# Run the target test file using pytest
# Using -v for verbose output to help with debugging
# Running in single-process mode for stability in virtualized environment
# Using --tb=short for concise traceback output
echo "=== Running tests ==="
pytest -v --tb=short --no-header -rA tests/unittests/tools/test_tool_config.py
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 54cc849de7e4c01e7954b2d896cc47d0ec390886 \
    "tests/unittests/tools/test_tool_config.py"

# Exit with the captured return code
exit $rc