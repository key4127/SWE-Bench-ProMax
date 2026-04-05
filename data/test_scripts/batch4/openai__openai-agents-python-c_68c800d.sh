#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 300e12c19815f793f348bb9ed17d2eae66690b0b "tests/test_run_step_execution.py" "tests/test_run_step_processing.py" "tests/voice/test_openai_stt.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/mcp/__init__.py b/tests/mcp/__init__.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/__init__.py

diff --git a/tests/mcp/conftest.py b/tests/mcp/conftest.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/conftest.py
@@ -0,0 +1,11 @@
+import os
+import sys
+
+
+# Skip MCP tests on Python 3.9
+def pytest_ignore_collect(collection_path, config):
+    if sys.version_info[:2] == (3, 9):
+        this_dir = os.path.dirname(__file__)
+
+        if str(collection_path).startswith(this_dir):
+            return True
diff --git a/tests/mcp/helpers.py b/tests/mcp/helpers.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/helpers.py
@@ -0,0 +1,54 @@
+import json
+import shutil
+from typing import Any
+
+from mcp import Tool as MCPTool
+from mcp.types import CallToolResult, TextContent
+
+from agents.mcp import MCPServer
+
+tee = shutil.which("tee") or ""
+assert tee, "tee not found"
+
+
+# Added dummy stream classes for patching stdio_client to avoid real I/O during tests
+class DummyStream:
+    async def send(self, msg):
+        pass
+
+    async def receive(self):
+        raise Exception("Dummy receive not implemented")
+
+
+class DummyStreamsContextManager:
+    async def __aenter__(self):
+        return (DummyStream(), DummyStream())
+
+    async def __aexit__(self, exc_type, exc_val, exc_tb):
+        pass
+
+
+class FakeMCPServer(MCPServer):
+    def __init__(self, tools: list[MCPTool] | None = None):
+        self.tools: list[MCPTool] = tools or []
+        self.tool_calls: list[str] = []
+        self.tool_results: list[str] = []
+
+    def add_tool(self, name: str, input_schema: dict[str, Any]):
+        self.tools.append(MCPTool(name=name, inputSchema=input_schema))
+
+    async def connect(self):
+        pass
+
+    async def cleanup(self):
+        pass
+
+    async def list_tools(self):
+        return self.tools
+
+    async def call_tool(self, tool_name: str, arguments: dict[str, Any] | None) -> CallToolResult:
+        self.tool_calls.append(tool_name)
+        self.tool_results.append(f"result_{tool_name}_{json.dumps(arguments)}")
+        return CallToolResult(
+            content=[TextContent(text=self.tool_results[-1], type="text")],
+        )
diff --git a/tests/mcp/test_caching.py b/tests/mcp/test_caching.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/test_caching.py
@@ -0,0 +1,57 @@
+from unittest.mock import AsyncMock, patch
+
+import pytest
+from mcp.types import ListToolsResult, Tool as MCPTool
+
+from agents.mcp import MCPServerStdio
+
+from .helpers import DummyStreamsContextManager, tee
+
+
+@pytest.mark.asyncio
+@patch("mcp.client.stdio.stdio_client", return_value=DummyStreamsContextManager())
+@patch("mcp.client.session.ClientSession.initialize", new_callable=AsyncMock, return_value=None)
+@patch("mcp.client.session.ClientSession.list_tools")
+async def test_server_caching_works(
+    mock_list_tools: AsyncMock, mock_initialize: AsyncMock, mock_stdio_client
+):
+    """Test that if we turn caching on, the list of tools is cached and not fetched from the server
+    on each call to `list_tools()`.
+    """
+    server = MCPServerStdio(
+        params={
+            "command": tee,
+        },
+        cache_tools_list=True,
+    )
+
+    tools = [
+        MCPTool(name="tool1", inputSchema={}),
+        MCPTool(name="tool2", inputSchema={}),
+    ]
+
+    mock_list_tools.return_value = ListToolsResult(tools=tools)
+
+    async with server:
+        # Call list_tools() multiple times
+        tools = await server.list_tools()
+        assert tools == tools
+
+        assert mock_list_tools.call_count == 1, "list_tools() should have been called once"
+
+        # Call list_tools() again, should return the cached value
+        tools = await server.list_tools()
+        assert tools == tools
+
+        assert mock_list_tools.call_count == 1, "list_tools() should not have been called again"
+
+        # Invalidate the cache and call list_tools() again
+        server.invalidate_tools_cache()
+        tools = await server.list_tools()
+        assert tools == tools
+
+        assert mock_list_tools.call_count == 2, "list_tools() should be called again"
+
+        # Without invalidating the cache, calling list_tools() again should return the cached value
+        tools = await server.list_tools()
+        assert tools == tools
diff --git a/tests/mcp/test_connect_disconnect.py b/tests/mcp/test_connect_disconnect.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/test_connect_disconnect.py
@@ -0,0 +1,69 @@
+from unittest.mock import AsyncMock, patch
+
+import pytest
+from mcp.types import ListToolsResult, Tool as MCPTool
+
+from agents.mcp import MCPServerStdio
+
+from .helpers import DummyStreamsContextManager, tee
+
+
+@pytest.mark.asyncio
+@patch("mcp.client.stdio.stdio_client", return_value=DummyStreamsContextManager())
+@patch("mcp.client.session.ClientSession.initialize", new_callable=AsyncMock, return_value=None)
+@patch("mcp.client.session.ClientSession.list_tools")
+async def test_async_ctx_manager_works(
+    mock_list_tools: AsyncMock, mock_initialize: AsyncMock, mock_stdio_client
+):
+    """Test that the async context manager works."""
+    server = MCPServerStdio(
+        params={
+            "command": tee,
+        },
+        cache_tools_list=True,
+    )
+
+    tools = [
+        MCPTool(name="tool1", inputSchema={}),
+        MCPTool(name="tool2", inputSchema={}),
+    ]
+
+    mock_list_tools.return_value = ListToolsResult(tools=tools)
+
+    assert server.session is None, "Server should not be connected"
+
+    async with server:
+        assert server.session is not None, "Server should be connected"
+
+    assert server.session is None, "Server should be disconnected"
+
+
+@pytest.mark.asyncio
+@patch("mcp.client.stdio.stdio_client", return_value=DummyStreamsContextManager())
+@patch("mcp.client.session.ClientSession.initialize", new_callable=AsyncMock, return_value=None)
+@patch("mcp.client.session.ClientSession.list_tools")
+async def test_manual_connect_disconnect_works(
+    mock_list_tools: AsyncMock, mock_initialize: AsyncMock, mock_stdio_client
+):
+    """Test that the async context manager works."""
+    server = MCPServerStdio(
+        params={
+            "command": tee,
+        },
+        cache_tools_list=True,
+    )
+
+    tools = [
+        MCPTool(name="tool1", inputSchema={}),
+        MCPTool(name="tool2", inputSchema={}),
+    ]
+
+    mock_list_tools.return_value = ListToolsResult(tools=tools)
+
+    assert server.session is None, "Server should not be connected"
+
+    await server.connect()
+    assert server.session is not None, "Server should be connected"
+
+    await server.cleanup()
+    assert server.session is None, "Server should be disconnected"
diff --git a/tests/mcp/test_mcp_util.py b/tests/mcp/test_mcp_util.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/test_mcp_util.py
@@ -0,0 +1,109 @@
+import logging
+from typing import Any
+
+import pytest
+from mcp.types import Tool as MCPTool
+from pydantic import BaseModel
+
+from agents import FunctionTool, RunContextWrapper
+from agents.exceptions import AgentsException, ModelBehaviorError
+from agents.mcp import MCPServer, MCPUtil
+
+from .helpers import FakeMCPServer
+
+
+class Foo(BaseModel):
+    bar: str
+    baz: int
+
+
+class Bar(BaseModel):
+    qux: str
+
+
+@pytest.mark.asyncio
+async def test_get_all_function_tools():
+    """Test that the get_all_function_tools function returns all function tools from a list of MCP
+    servers.
+    """
+    names = ["test_tool_1", "test_tool_2", "test_tool_3", "test_tool_4", "test_tool_5"]
+    schemas = [
+        {},
+        {},
+        {},
+        Foo.model_json_schema(),
+        Bar.model_json_schema(),
+    ]
+
+    server1 = FakeMCPServer()
+    server1.add_tool(names[0], schemas[0])
+    server1.add_tool(names[1], schemas[1])
+
+    server2 = FakeMCPServer()
+    server2.add_tool(names[2], schemas[2])
+    server2.add_tool(names[3], schemas[3])
+
+    server3 = FakeMCPServer()
+    server3.add_tool(names[4], schemas[4])
+
+    servers: list[MCPServer] = [server1, server2, server3]
+    tools = await MCPUtil.get_all_function_tools(servers)
+    assert len(tools) == 5
+    assert all(tool.name in names for tool in tools)
+
+    for idx, tool in enumerate(tools):
+        assert isinstance(tool, FunctionTool)
+        assert tool.params_json_schema == schemas[idx]
+        assert tool.name == names[idx]
+
+
+@pytest.mark.asyncio
+async def test_invoke_mcp_tool():
+    """Test that the invoke_mcp_tool function invokes an MCP tool and returns the result."""
+    server = FakeMCPServer()
+    server.add_tool("test_tool_1", {})
+
+    ctx = RunContextWrapper(context=None)
+    tool = MCPTool(name="test_tool_1", inputSchema={})
+
+    await MCPUtil.invoke_mcp_tool(server, tool, ctx, "")
+    # Just making sure it doesn't crash
+
+
+@pytest.mark.asyncio
+async def test_mcp_invoke_bad_json_errors(caplog: pytest.LogCaptureFixture):
+    caplog.set_level(logging.DEBUG)
+
+    """Test that bad JSON input errors are logged and re-raised."""
+    server = FakeMCPServer()
+    server.add_tool("test_tool_1", {})
+
+    ctx = RunContextWrapper(context=None)
+    tool = MCPTool(name="test_tool_1", inputSchema={})
+
+    with pytest.raises(ModelBehaviorError):
+        await MCPUtil.invoke_mcp_tool(server, tool, ctx, "not_json")
+
+    assert "Invalid JSON input for tool test_tool_1" in caplog.text
+
+
+class CrashingFakeMCPServer(FakeMCPServer):
+    async def call_tool(self, tool_name: str, arguments: dict[str, Any] | None):
+        raise Exception("Crash!")
+
+
+@pytest.mark.asyncio
+async def test_mcp_invocation_crash_causes_error(caplog: pytest.LogCaptureFixture):
+    caplog.set_level(logging.DEBUG)
+
+    """Test that bad JSON input errors are logged and re-raised."""
+    server = CrashingFakeMCPServer()
+    server.add_tool("test_tool_1", {})
+
+    ctx = RunContextWrapper(context=None)
+    tool = MCPTool(name="test_tool_1", inputSchema={})
+
+    with pytest.raises(AgentsException):
+        await MCPUtil.invoke_mcp_tool(server, tool, ctx, "")
+
+    assert "Error invoking MCP tool test_tool_1" in caplog.text
diff --git a/tests/mcp/test_runner_calls_mcp.py b/tests/mcp/test_runner_calls_mcp.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/test_runner_calls_mcp.py
@@ -0,0 +1,197 @@
+import json
+
+import pytest
+from pydantic import BaseModel
+
+from agents import Agent, ModelBehaviorError, Runner, UserError
+
+from ..fake_model import FakeModel
+from ..test_responses import get_function_tool_call, get_text_message
+from .helpers import FakeMCPServer
+
+
+@pytest.mark.asyncio
+@pytest.mark.parametrize("streaming", [False, True])
+async def test_runner_calls_mcp_tool(streaming: bool):
+    """Test that the runner calls an MCP tool when the model produces a tool call."""
+    server = FakeMCPServer()
+    server.add_tool("test_tool_1", {})
+    server.add_tool("test_tool_2", {})
+    server.add_tool("test_tool_3", {})
+    model = FakeModel()
+    agent = Agent(
+        name="test",
+        model=model,
+        mcp_servers=[server],
+    )
+
+    model.add_multiple_turn_outputs(
+        [
+            # First turn: a message and tool call
+            [get_text_message("a_message"), get_function_tool_call("test_tool_2", "")],
+            # Second turn: text message
+            [get_text_message("done")],
+        ]
+    )
+
+    if streaming:
+        result = Runner.run_streamed(agent, input="user_message")
+        async for _ in result.stream_events():
+            pass
+    else:
+        await Runner.run(agent, input="user_message")
+
+    assert server.tool_calls == ["test_tool_2"]
+
+
+@pytest.mark.asyncio
+@pytest.mark.parametrize("streaming", [False, True])
+async def test_runner_asserts_when_mcp_tool_not_found(streaming: bool):
+    """Test that the runner asserts when an MCP tool is not found."""
+    server = FakeMCPServer()
+    server.add_tool("test_tool_1", {})
+    server.add_tool("test_tool_2", {})
+    server.add_tool("test_tool_3", {})
+    model = FakeModel()
+    agent = Agent(
+        name="test",
+        model=model,
+        mcp_servers=[server],
+    )
+
+    model.add_multiple_turn_outputs(
+        [
+            # First turn: a message and tool call
+            [get_text_message("a_message"), get_function_tool_call("test_tool_doesnt_exist", "")],
+            # Second turn: text message
+            [get_text_message("done")],
+        ]
+    )
+
+    with pytest.raises(ModelBehaviorError):
+        if streaming:
+            result = Runner.run_streamed(agent, input="user_message")
+            async for _ in result.stream_events():
+                pass
+        else:
+            await Runner.run(agent, input="user_message")
+
+
+@pytest.mark.asyncio
+@pytest.mark.parametrize("streaming", [False, True])
+async def test_runner_works_with_multiple_mcp_servers(streaming: bool):
+    """Test that the runner works with multiple MCP servers."""
+    server1 = FakeMCPServer()
+    server1.add_tool("test_tool_1", {})
+
+    server2 = FakeMCPServer()
+    server2.add_tool("test_tool_2", {})
+    server2.add_tool("test_tool_3", {})
+
+    model = FakeModel()
+    agent = Agent(
+        name="test",
+        model=model,
+        mcp_servers=[server1, server2],
+    )
+
+    model.add_multiple_turn_outputs(
+        [
+            # First turn: a message and tool call
+            [get_text_message("a_message"), get_function_tool_call("test_tool_2", "")],
+            # Second turn: text message
+            [get_text_message("done")],
+        ]
+    )
+
+    if streaming:
+        result = Runner.run_streamed(agent, input="user_message")
+        async for _ in result.stream_events():
+            pass
+    else:
+        await Runner.run(agent, input="user_message")
+
+    assert server1.tool_calls == []
+    assert server2.tool_calls == ["test_tool_2"]
+
+
+@pytest.mark.asyncio
+@pytest.mark.parametrize("streaming", [False, True])
+async def test_runner_errors_when_mcp_tools_clash(streaming: bool):
+    """Test that the runner errors when multiple servers have the same tool name."""
+    server1 = FakeMCPServer()
+    server1.add_tool("test_tool_1", {})
+    server1.add_tool("test_tool_2", {})
+
+    server2 = FakeMCPServer()
+    server2.add_tool("test_tool_2", {})
+    server2.add_tool("test_tool_3", {})
+
+    model = FakeModel()
+    agent = Agent(
+        name="test",
+        model=model,
+        mcp_servers=[server1, server2],
+    )
+
+    model.add_multiple_turn_outputs(
+        [
+            # First turn: a message and tool call
+            [get_text_message("a_message"), get_function_tool_call("test_tool_3", "")],
+            # Second turn: text message
+            [get_text_message("done")],
+        ]
+    )
+
+    with pytest.raises(UserError):
+        if streaming:
+            result = Runner.run_streamed(agent, input="user_message")
+            async for _ in result.stream_events():
+                pass
+        else:
+            await Runner.run(agent, input="user_message")
+
+
+class Foo(BaseModel):
+    bar: str
+    baz: int
+
+
+@pytest.mark.asyncio
+@pytest.mark.parametrize("streaming", [False, True])
+async def test_runner_calls_mcp_tool_with_args(streaming: bool):
+    """Test that the runner calls an MCP tool when the model produces a tool call."""
+    server = FakeMCPServer()
+    await server.connect()
+    server.add_tool("test_tool_1", {})
+    server.add_tool("test_tool_2", Foo.model_json_schema())
+    server.add_tool("test_tool_3", {})
+    model = FakeModel()
+    agent = Agent(
+        name="test",
+        model=model,
+        mcp_servers=[server],
+    )
+
+    json_args = json.dumps(Foo(bar="baz", baz=1).model_dump())
+
+    model.add_multiple_turn_outputs(
+        [
+            # First turn: a message and tool call
+            [get_text_message("a_message"), get_function_tool_call("test_tool_2", json_args)],
+            # Second turn: text message
+            [get_text_message("done")],
+        ]
+    )
+
+    if streaming:
+        result = Runner.run_streamed(agent, input="user_message")
+        async for _ in result.stream_events():
+            pass
+    else:
+        await Runner.run(agent, input="user_message")
+
+    assert server.tool_calls == ["test_tool_2"]
+    assert server.tool_results == [f"result_test_tool_2_{json_args}"]
+
+    await server.cleanup()
diff --git a/tests/mcp/test_server_errors.py b/tests/mcp/test_server_errors.py
new file mode 100644
--- /dev/null
+++ b/tests/mcp/test_server_errors.py
@@ -0,0 +1,38 @@
+import pytest
+
+from agents.exceptions import UserError
+from agents.mcp.server import _MCPServerWithClientSession
+
+
+class CrashingClientSessionServer(_MCPServerWithClientSession):
+    def __init__(self):
+        super().__init__(cache_tools_list=False)
+        self.cleanup_called = False
+
+    def create_streams(self):
+        raise ValueError("Crash!")
+
+    async def cleanup(self):
+        self.cleanup_called = True
+        await super().cleanup()
+
+
+@pytest.mark.asyncio
+async def test_server_errors_cause_error_and_cleanup_called():
+    server = CrashingClientSessionServer()
+
+    with pytest.raises(ValueError):
+        await server.connect()
+
+    assert server.cleanup_called
+
+
+@pytest.mark.asyncio
+async def test_not_calling_connect_causes_error():
+    server = CrashingClientSessionServer()
+
+    with pytest.raises(UserError):
+        await server.list_tools()
+
+    with pytest.raises(UserError):
+        await server.call_tool("foo", {})
diff --git a/tests/test_run_step_execution.py b/tests/test_run_step_execution.py
--- a/tests/test_run_step_execution.py
+++ b/tests/test_run_step_execution.py
@@ -290,6 +290,7 @@ async def get_execute_result(
 
     processed_response = RunImpl.process_model_response(
         agent=agent,
+        all_tools=await agent.get_all_tools(),
         response=response,
         output_schema=output_schema,
         handoffs=handoffs,
diff --git a/tests/test_run_step_processing.py b/tests/test_run_step_processing.py
--- a/tests/test_run_step_processing.py
+++ b/tests/test_run_step_processing.py
@@ -43,7 +43,11 @@ def test_empty_response():
     )
 
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=[],
     )
     assert not result.handoffs
     assert not result.functions
@@ -57,13 +61,14 @@ def test_no_tool_calls():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent, response=response, output_schema=None, handoffs=[], all_tools=[]
     )
     assert not result.handoffs
     assert not result.functions
 
 
-def test_single_tool_call():
+@pytest.mark.asyncio
+async def test_single_tool_call():
     agent = Agent(name="test", tools=[get_function_tool(name="test")])
     response = ModelResponse(
         output=[
@@ -74,7 +79,11 @@ def test_single_tool_call():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await agent.get_all_tools(),
     )
     assert not result.handoffs
     assert result.functions and len(result.functions) == 1
@@ -84,7 +93,8 @@ def test_single_tool_call():
     assert func.tool_call.arguments == ""
 
 
-def test_missing_tool_call_raises_error():
+@pytest.mark.asyncio
+async def test_missing_tool_call_raises_error():
     agent = Agent(name="test", tools=[get_function_tool(name="test")])
     response = ModelResponse(
         output=[
@@ -97,11 +107,16 @@ def test_missing_tool_call_raises_error():
 
     with pytest.raises(ModelBehaviorError):
         RunImpl.process_model_response(
-            agent=agent, response=response, output_schema=None, handoffs=[]
+            agent=agent,
+            response=response,
+            output_schema=None,
+            handoffs=[],
+            all_tools=await agent.get_all_tools(),
         )
 
 
-def test_multiple_tool_calls():
+@pytest.mark.asyncio
+async def test_multiple_tool_calls():
     agent = Agent(
         name="test",
         tools=[
@@ -121,7 +136,11 @@ def test_multiple_tool_calls():
     )
 
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await agent.get_all_tools(),
     )
     assert not result.handoffs
     assert result.functions and len(result.functions) == 2
@@ -146,7 +165,11 @@ async def test_handoffs_parsed_correctly():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=agent_3, response=response, output_schema=None, handoffs=[]
+        agent=agent_3,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await agent_3.get_all_tools(),
     )
     assert not result.handoffs, "Shouldn't have a handoff here"
 
@@ -160,6 +183,7 @@ async def test_handoffs_parsed_correctly():
         response=response,
         output_schema=None,
         handoffs=Runner._get_handoffs(agent_3),
+        all_tools=await agent_3.get_all_tools(),
     )
     assert len(result.handoffs) == 1, "Should have a handoff here"
     handoff = result.handoffs[0]
@@ -189,10 +213,12 @@ async def test_missing_handoff_fails():
             response=response,
             output_schema=None,
             handoffs=Runner._get_handoffs(agent_3),
+            all_tools=await agent_3.get_all_tools(),
         )
 
 
-def test_multiple_handoffs_doesnt_error():
+@pytest.mark.asyncio
+async def test_multiple_handoffs_doesnt_error():
     agent_1 = Agent(name="test_1")
     agent_2 = Agent(name="test_2")
     agent_3 = Agent(name="test_3", handoffs=[agent_1, agent_2])
@@ -210,6 +236,7 @@ def test_multiple_handoffs_doesnt_error():
         response=response,
         output_schema=None,
         handoffs=Runner._get_handoffs(agent_3),
+        all_tools=await agent_3.get_all_tools(),
     )
     assert len(result.handoffs) == 2, "Should have multiple handoffs here"
 
@@ -218,7 +245,8 @@ class Foo(BaseModel):
     bar: str
 
 
-def test_final_output_parsed_correctly():
+@pytest.mark.asyncio
+async def test_final_output_parsed_correctly():
     agent = Agent(name="test", output_type=Foo)
     response = ModelResponse(
         output=[
@@ -234,10 +262,12 @@ def test_final_output_parsed_correctly():
         response=response,
         output_schema=Runner._get_output_schema(agent),
         handoffs=[],
+        all_tools=await agent.get_all_tools(),
     )
 
 
-def test_file_search_tool_call_parsed_correctly():
+@pytest.mark.asyncio
+async def test_file_search_tool_call_parsed_correctly():
     # Ensure that a ResponseFileSearchToolCall output is parsed into a ToolCallItem and that no tool
     # runs are scheduled.
 
@@ -254,7 +284,11 @@ def test_file_search_tool_call_parsed_correctly():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await agent.get_all_tools(),
     )
     # The final item should be a ToolCallItem for the file search call
     assert any(
@@ -265,7 +299,8 @@ def test_file_search_tool_call_parsed_correctly():
     assert not result.handoffs
 
 
-def test_function_web_search_tool_call_parsed_correctly():
+@pytest.mark.asyncio
+async def test_function_web_search_tool_call_parsed_correctly():
     agent = Agent(name="test")
     web_search_call = ResponseFunctionWebSearch(id="w1", status="completed", type="web_search_call")
     response = ModelResponse(
@@ -274,7 +309,11 @@ def test_function_web_search_tool_call_parsed_correctly():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await agent.get_all_tools(),
     )
     assert any(
         isinstance(item, ToolCallItem) and item.raw_item is web_search_call
@@ -284,7 +323,8 @@ def test_function_web_search_tool_call_parsed_correctly():
     assert not result.handoffs
 
 
-def test_reasoning_item_parsed_correctly():
+@pytest.mark.asyncio
+async def test_reasoning_item_parsed_correctly():
     # Verify that a Reasoning output item is converted into a ReasoningItem.
 
     reasoning = ResponseReasoningItem(
@@ -296,7 +336,11 @@ def test_reasoning_item_parsed_correctly():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=Agent(name="test"), response=response, output_schema=None, handoffs=[]
+        agent=Agent(name="test"),
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await Agent(name="test").get_all_tools(),
     )
     assert any(
         isinstance(item, ReasoningItem) and item.raw_item is reasoning for item in result.new_items
@@ -342,7 +386,8 @@ def drag(self, path: list[tuple[int, int]]) -> None:
         return None  # pragma: no cover
 
 
-def test_computer_tool_call_without_computer_tool_raises_error():
+@pytest.mark.asyncio
+async def test_computer_tool_call_without_computer_tool_raises_error():
     # If the agent has no ComputerTool in its tools, process_model_response should raise a
     # ModelBehaviorError when encountering a ResponseComputerToolCall.
     computer_call = ResponseComputerToolCall(
@@ -360,11 +405,16 @@ def test_computer_tool_call_without_computer_tool_raises_error():
     )
     with pytest.raises(ModelBehaviorError):
         RunImpl.process_model_response(
-            agent=Agent(name="test"), response=response, output_schema=None, handoffs=[]
+            agent=Agent(name="test"),
+            response=response,
+            output_schema=None,
+            handoffs=[],
+            all_tools=await Agent(name="test").get_all_tools(),
         )
 
 
-def test_computer_tool_call_with_computer_tool_parsed_correctly():
+@pytest.mark.asyncio
+async def test_computer_tool_call_with_computer_tool_parsed_correctly():
     # If the agent contains a ComputerTool, ensure that a ResponseComputerToolCall is parsed into a
     # ToolCallItem and scheduled to run in computer_actions.
     dummy_computer = DummyComputer()
@@ -383,7 +433,11 @@ def test_computer_tool_call_with_computer_tool_parsed_correctly():
         referenceable_id=None,
     )
     result = RunImpl.process_model_response(
-        agent=agent, response=response, output_schema=None, handoffs=[]
+        agent=agent,
+        response=response,
+        output_schema=None,
+        handoffs=[],
+        all_tools=await agent.get_all_tools(),
     )
     assert any(
         isinstance(item, ToolCallItem) and item.raw_item is computer_call
@@ -392,7 +446,8 @@ def test_computer_tool_call_with_computer_tool_parsed_correctly():
     assert result.computer_actions and result.computer_actions[0].tool_call == computer_call
 
 
-def test_tool_and_handoff_parsed_correctly():
+@pytest.mark.asyncio
+async def test_tool_and_handoff_parsed_correctly():
     agent_1 = Agent(name="test_1")
     agent_2 = Agent(name="test_2")
     agent_3 = Agent(
@@ -413,6 +468,7 @@ def test_tool_and_handoff_parsed_correctly():
         response=response,
         output_schema=None,
         handoffs=Runner._get_handoffs(agent_3),
+        all_tools=await agent_3.get_all_tools(),
     )
     assert result.functions and len(result.functions) == 1
     assert len(result.handoffs) == 1, "Should have a handoff here"
diff --git a/tests/voice/test_openai_stt.py b/tests/voice/test_openai_stt.py
--- a/tests/voice/test_openai_stt.py
+++ b/tests/voice/test_openai_stt.py
@@ -269,7 +269,7 @@ def fake_time_func():
             async for _ in turns:
                 pass
 
-            assert "Timeout waiting for transcription_session.created event" in str(exc_info.value)
+        assert "Timeout waiting for transcription_session.created event" in str(exc_info.value)
 
         await session.close()
 
@@ -302,13 +302,11 @@ async def test_session_error_event():
             trace_include_sensitive_audio_data=False,
         )
 
-        with pytest.raises(STTWebsocketConnectionError) as exc_info:
+        with pytest.raises(STTWebsocketConnectionError):
             turns = session.transcribe_turns()
             async for _ in turns:
                 pass
 
-            assert "Simulated server error!" in str(exc_info.value)
-
         await session.close()
 
 
@@ -362,8 +360,8 @@ async def test_inactivity_timeout():
             async for turn in session.transcribe_turns():
                 collected_turns.append(turn)
 
-            assert "Timeout waiting for transcription_session" in str(exc_info.value)
+        assert "Timeout waiting for transcription_session" in str(exc_info.value)
 
-            assert len(collected_turns) == 0, "No transcripts expected, but we got something?"
+        assert len(collected_turns) == 0, "No transcripts expected, but we got something?"
 
         await session.close()
EOF_114329324912

# Ensure environment variables are set
export UV_FROZEN=1
export OPENAI_API_KEY=fake-for-tests

# Run the specified test files using uv run pytest
# Note: Running in single-process mode for stability in virtualized environment
uv run pytest --no-header -rA --tb=short -v \
    tests/test_run_step_execution.py \
    tests/test_run_step_processing.py \
    tests/voice/test_openai_stt.py

# Capture the exit code
rc=$?

# Echo the exit code for the test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 300e12c19815f793f348bb9ed17d2eae66690b0b "tests/test_run_step_execution.py" "tests/test_run_step_processing.py" "tests/voice/test_openai_stt.py"

# Exit with the captured return code
exit $rc