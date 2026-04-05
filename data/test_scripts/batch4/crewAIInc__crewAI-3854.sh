#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit and test files
git checkout f6aed9798bae90bcb8f619fe7dc5c13aeeaa355b "lib/crewai/tests/mcp/test_mcp_config.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/lib/crewai/tests/mcp/test_mcp_config.py b/lib/crewai/tests/mcp/test_mcp_config.py
--- a/lib/crewai/tests/mcp/test_mcp_config.py
+++ b/lib/crewai/tests/mcp/test_mcp_config.py
@@ -1,4 +1,5 @@
-from unittest.mock import AsyncMock, patch
+import asyncio
+from unittest.mock import AsyncMock, MagicMock, patch
 
 import pytest
 from crewai.agent.core import Agent
@@ -134,3 +135,66 @@ def test_agent_with_sse_mcp_config(mock_tool_definitions):
         transport = call_args.kwargs["transport"]
         assert transport.url == "https://api.example.com/mcp/sse"
         assert transport.headers == {"Authorization": "Bearer test_token"}
+
+
+def test_mcp_tool_execution_in_sync_context(mock_tool_definitions):
+    """Test MCPNativeTool execution in synchronous context (normal crew execution)."""
+    http_config = MCPServerHTTP(url="https://api.example.com/mcp")
+
+    with patch("crewai.agent.core.MCPClient") as mock_client_class:
+        mock_client = AsyncMock()
+        mock_client.list_tools = AsyncMock(return_value=mock_tool_definitions)
+        mock_client.connected = False
+        mock_client.connect = AsyncMock()
+        mock_client.disconnect = AsyncMock()
+        mock_client.call_tool = AsyncMock(return_value="test result")
+        mock_client_class.return_value = mock_client
+
+        agent = Agent(
+            role="Test Agent",
+            goal="Test goal",
+            backstory="Test backstory",
+            mcps=[http_config],
+        )
+
+        tools = agent.get_mcp_tools([http_config])
+        assert len(tools) == 2
+
+
+        tool = tools[0]
+        result = tool.run(query="test query")
+
+        assert result == "test result"
+        mock_client.call_tool.assert_called()
+
+
+@pytest.mark.asyncio
+async def test_mcp_tool_execution_in_async_context(mock_tool_definitions):
+    """Test MCPNativeTool execution in async context (e.g., from a Flow)."""
+    http_config = MCPServerHTTP(url="https://api.example.com/mcp")
+
+    with patch("crewai.agent.core.MCPClient") as mock_client_class:
+        mock_client = AsyncMock()
+        mock_client.list_tools = AsyncMock(return_value=mock_tool_definitions)
+        mock_client.connected = False
+        mock_client.connect = AsyncMock()
+        mock_client.disconnect = AsyncMock()
+        mock_client.call_tool = AsyncMock(return_value="test result")
+        mock_client_class.return_value = mock_client
+
+        agent = Agent(
+            role="Test Agent",
+            goal="Test goal",
+            backstory="Test backstory",
+            mcps=[http_config],
+        )
+
+        tools = agent.get_mcp_tools([http_config])
+        assert len(tools) == 2
+
+
+        tool = tools[0]
+        result = tool.run(query="test query")
+
+        assert result == "test result"
+        mock_client.call_tool.assert_called()
EOF_114329324912

# Set environment variables for testing
export OPENAI_API_KEY=fake-api-key
export PYTHONUNBUFFERED=1
export OTEL_SDK_DISABLED=true
export PATH="/root/.cargo/bin:$PATH"

# Run target tests using uv (single process for stability)
uv run pytest lib/crewai/tests/mcp/test_mcp_config.py -vv --timeout=30 --tb=short
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes
git checkout f6aed9798bae90bcb8f619fe7dc5c13aeeaa355b "lib/crewai/tests/mcp/test_mcp_config.py"