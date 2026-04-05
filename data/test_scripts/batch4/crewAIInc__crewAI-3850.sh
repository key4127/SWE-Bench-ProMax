#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit
git checkout 9e5906c52f39f97ae044174fd8702f650f834c51

# Apply test patch to add/modify test files
git apply -v - <<'EOF_114329324912'
diff --git a/lib/crewai/tests/mcp/__init__.py b/lib/crewai/tests/mcp/__init__.py
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/mcp/__init__.py
@@ -0,0 +1,4 @@
+"""Tests for MCP (Model Context Protocol) integration."""
+
+
+
diff --git a/lib/crewai/tests/mcp/test_mcp_config.py b/lib/crewai/tests/mcp/test_mcp_config.py
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/mcp/test_mcp_config.py
@@ -0,0 +1,136 @@
+from unittest.mock import AsyncMock, patch
+
+import pytest
+from crewai.agent.core import Agent
+from crewai.mcp.config import MCPServerHTTP, MCPServerSSE, MCPServerStdio
+from crewai.tools.base_tool import BaseTool
+
+
+@pytest.fixture
+def mock_tool_definitions():
+    """Create mock MCP tool definitions (as returned by list_tools)."""
+    return [
+        {
+            "name": "test_tool_1",
+            "description": "Test tool 1 description",
+            "inputSchema": {
+                "type": "object",
+                "properties": {
+                    "query": {"type": "string", "description": "Search query"}
+                },
+                "required": ["query"]
+            }
+        },
+        {
+            "name": "test_tool_2",
+            "description": "Test tool 2 description",
+            "inputSchema": {}
+        }
+    ]
+
+
+def test_agent_with_stdio_mcp_config(mock_tool_definitions):
+    """Test agent setup with MCPServerStdio configuration."""
+    stdio_config = MCPServerStdio(
+        command="python",
+        args=["server.py"],
+        env={"API_KEY": "test_key"},
+    )
+
+    agent = Agent(
+        role="Test Agent",
+        goal="Test goal",
+        backstory="Test backstory",
+        mcps=[stdio_config],
+    )
+
+
+    with patch("crewai.agent.core.MCPClient") as mock_client_class:
+        mock_client = AsyncMock()
+        mock_client.list_tools = AsyncMock(return_value=mock_tool_definitions)
+        mock_client.connected = False  # Will trigger connect
+        mock_client.connect = AsyncMock()
+        mock_client.disconnect = AsyncMock()
+        mock_client_class.return_value = mock_client
+
+        tools = agent.get_mcp_tools([stdio_config])
+
+        assert len(tools) == 2
+        assert all(isinstance(tool, BaseTool) for tool in tools)
+
+        mock_client_class.assert_called_once()
+        call_args = mock_client_class.call_args
+        transport = call_args.kwargs["transport"]
+        assert transport.command == "python"
+        assert transport.args == ["server.py"]
+        assert transport.env == {"API_KEY": "test_key"}
+
+
+def test_agent_with_http_mcp_config(mock_tool_definitions):
+    """Test agent setup with MCPServerHTTP configuration."""
+    http_config = MCPServerHTTP(
+        url="https://api.example.com/mcp",
+        headers={"Authorization": "Bearer test_token"},
+        streamable=True,
+    )
+
+    agent = Agent(
+        role="Test Agent",
+        goal="Test goal",
+        backstory="Test backstory",
+        mcps=[http_config],
+    )
+
+    with patch("crewai.agent.core.MCPClient") as mock_client_class:
+        mock_client = AsyncMock()
+        mock_client.list_tools = AsyncMock(return_value=mock_tool_definitions)
+        mock_client.connected = False  # Will trigger connect
+        mock_client.connect = AsyncMock()
+        mock_client.disconnect = AsyncMock()
+        mock_client_class.return_value = mock_client
+
+        tools = agent.get_mcp_tools([http_config])
+
+        assert len(tools) == 2
+        assert all(isinstance(tool, BaseTool) for tool in tools)
+
+        mock_client_class.assert_called_once()
+        call_args = mock_client_class.call_args
+        transport = call_args.kwargs["transport"]
+        assert transport.url == "https://api.example.com/mcp"
+        assert transport.headers == {"Authorization": "Bearer test_token"}
+        assert transport.streamable is True
+
+
+def test_agent_with_sse_mcp_config(mock_tool_definitions):
+    """Test agent setup with MCPServerSSE configuration."""
+    sse_config = MCPServerSSE(
+        url="https://api.example.com/mcp/sse",
+        headers={"Authorization": "Bearer test_token"},
+    )
+
+    agent = Agent(
+        role="Test Agent",
+        goal="Test goal",
+        backstory="Test backstory",
+        mcps=[sse_config],
+    )
+
+    with patch("crewai.agent.core.MCPClient") as mock_client_class:
+        mock_client = AsyncMock()
+        mock_client.list_tools = AsyncMock(return_value=mock_tool_definitions)
+        mock_client.connected = False
+        mock_client.connect = AsyncMock()
+        mock_client.disconnect = AsyncMock()
+        mock_client_class.return_value = mock_client
+
+        tools = agent.get_mcp_tools([sse_config])
+
+        assert len(tools) == 2
+        assert all(isinstance(tool, BaseTool) for tool in tools)
+
+        mock_client_class.assert_called_once()
+        call_args = mock_client_class.call_args
+        transport = call_args.kwargs["transport"]
+        assert transport.url == "https://api.example.com/mcp/sse"
+        assert transport.headers == {"Authorization": "Bearer test_token"}
EOF_114329324912

# Determine which test files were added/modified by the patch
# Extract test file paths from the git diff
TEST_FILES=$(git diff --name-only HEAD | grep -E "test_.*\.py$" || true)

if [ -z "$TEST_FILES" ]; then
    echo "No test files found in patch, running all tests in lib/crewai/tests/"
    cd /testbed/lib/crewai
    uv run pytest tests/ --block-network --timeout=30 -vv --maxfail=3
    rc=$?
else
    echo "Found test files in patch: $TEST_FILES"
    
    # Separate test files by package location
    CREWAI_TESTS=""
    CREWAI_TOOLS_TESTS=""
    
    for test_file in $TEST_FILES; do
        if [[ $test_file == lib/crewai/tests/* ]]; then
            # Extract relative path from lib/crewai/
            CREWAI_TESTS="$CREWAI_TESTS ${test_file#lib/crewai/}"
        elif [[ $test_file == lib/crewai-tools/tests/* ]]; then
            # Extract relative path from lib/crewai-tools/
            CREWAI_TOOLS_TESTS="$CREWAI_TOOLS_TESTS ${test_file#lib/crewai-tools/}"
        fi
    done
    
    # Run crewai tests if any
    if [ -n "$CREWAI_TESTS" ]; then
        echo "Running crewai tests: $CREWAI_TESTS"
        cd /testbed/lib/crewai
        uv run pytest $CREWAI_TESTS --block-network --timeout=30 -vv --maxfail=3
        rc=$?
    fi
    
    # Run crewai-tools tests if any
    if [ -n "$CREWAI_TOOLS_TESTS" ]; then
        echo "Running crewai-tools tests: $CREWAI_TOOLS_TESTS"
        cd /testbed/lib/crewai-tools
        uv run pytest $CREWAI_TOOLS_TESTS --block-network --timeout=30 -vv --maxfail=3
        tools_rc=$?
        # Use the last non-zero exit code if any
        if [ $tools_rc -ne 0 ]; then
            rc=$tools_rc
        fi
    fi
fi

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes
git checkout 9e5906c52f39f97ae044174fd8702f650f834c51