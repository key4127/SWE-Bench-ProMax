#!/bin/bash
set -uxo pipefail
cd /testbed

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Checkout the original test file to ensure clean state
git checkout b5f5df9fa8f616b855c186fcef45bade00653c77 "tests/unittests/tools/mcp_tool/test_mcp_session_manager.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/tools/mcp_tool/test_mcp_session_manager.py b/tests/unittests/tools/mcp_tool/test_mcp_session_manager.py
--- a/tests/unittests/tools/mcp_tool/test_mcp_session_manager.py
+++ b/tests/unittests/tools/mcp_tool/test_mcp_session_manager.py
@@ -146,6 +146,59 @@ def test_init_with_streamable_http_params(self):
 
     assert manager._connection_params == http_params
 
+  @patch("google.adk.tools.mcp_tool.mcp_session_manager.streamablehttp_client")
+  def test_init_with_streamable_http_custom_httpx_factory(
+      self, mock_streamablehttp_client
+  ):
+    """Test that streamablehttp_client is called with custom httpx_client_factory."""
+    from datetime import timedelta
+
+    custom_httpx_factory = Mock()
+
+    http_params = StreamableHTTPConnectionParams(
+        url="https://example.com/mcp",
+        timeout=15.0,
+        httpx_client_factory=custom_httpx_factory,
+    )
+    manager = MCPSessionManager(http_params)
+
+    manager._create_client()
+
+    mock_streamablehttp_client.assert_called_once_with(
+        url="https://example.com/mcp",
+        headers=None,
+        timeout=timedelta(seconds=15.0),
+        sse_read_timeout=timedelta(seconds=300.0),
+        terminate_on_close=True,
+        httpx_client_factory=custom_httpx_factory,
+    )
+
+  @pytest.mark.asyncio
+  @patch("google.adk.tools.mcp_tool.mcp_session_manager.streamablehttp_client")
+  async def test_init_with_streamable_http_default_httpx_factory(
+      self, mock_streamablehttp_client
+  ):
+    """Test that streamablehttp_client is called with custom httpx_client_factory."""
+    from datetime import timedelta
+
+    from mcp.client.streamable_http import create_mcp_http_client
+
+    http_params = StreamableHTTPConnectionParams(
+        url="https://example.com/mcp", timeout=15.0
+    )
+    manager = MCPSessionManager(http_params)
+
+    manager._create_client()
+
+    mock_streamablehttp_client.assert_called_once_with(
+        url="https://example.com/mcp",
+        headers=None,
+        timeout=timedelta(seconds=15.0),
+        sse_read_timeout=timedelta(seconds=300.0),
+        terminate_on_close=True,
+        httpx_client_factory=create_mcp_http_client,
+    )
+
   def test_generate_session_key_stdio(self):
     """Test session key generation for stdio connections."""
     manager = MCPSessionManager(self.mock_stdio_connection_params)
EOF_114329324912

# Run target test with pytest
# Using single-process mode for safety in virtualized environment
# -v for verbose output, --tb=short for concise tracebacks
# --no-header and -rA for structured output
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/unittests/tools/mcp_tool/test_mcp_session_manager.py

# Capture exit code
rc=$?

# Echo exit code for test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout b5f5df9fa8f616b855c186fcef45bade00653c77 "tests/unittests/tools/mcp_tool/test_mcp_session_manager.py"