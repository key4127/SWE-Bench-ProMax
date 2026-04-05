#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 729637a347cceac75201f3f89ea48f135d9d75ba "libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py b/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py
--- a/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py
+++ b/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py
@@ -1,14 +1,9 @@
-import pytest
+import warnings
+from types import ModuleType
 from typing import Any
 from unittest.mock import patch
-from types import ModuleType
 
-from syrupy.assertion import SnapshotAssertion
-
-import warnings
-from langgraph.runtime import Runtime
-from typing_extensions import Annotated
-from pydantic import BaseModel, Field
+import pytest
 from langchain_core.language_models import BaseChatModel
 from langchain_core.language_models.chat_models import BaseChatModel
 from langchain_core.messages import (
@@ -18,31 +13,42 @@
     ToolCall,
     ToolMessage,
 )
-from langchain_core.tools import tool, InjectedToolCallId
+from langchain_core.outputs import ChatGeneration, ChatResult
+from langchain_core.tools import InjectedToolCallId, tool
+from langgraph.checkpoint.base import BaseCheckpointSaver
+from langgraph.checkpoint.memory import InMemorySaver
+from langgraph.constants import END
+from langgraph.graph.message import REMOVE_ALL_MESSAGES
+from langgraph.runtime import Runtime
+from langgraph.types import Command
+from pydantic import BaseModel, Field
+from syrupy.assertion import SnapshotAssertion
+from typing_extensions import Annotated
 
-from langchain.agents.middleware_agent import create_agent
-from langchain.tools import InjectedState
 from langchain.agents.middleware.human_in_the_loop import (
-    HumanInTheLoopMiddleware,
     ActionRequest,
+    HumanInTheLoopMiddleware,
+)
+from langchain.agents.middleware.planning import (
+    PlanningMiddleware,
+    PlanningState,
+    WRITE_TODOS_SYSTEM_PROMPT,
+    write_todos,
+    WRITE_TODOS_TOOL_DESCRIPTION,
 )
 from langchain.agents.middleware.prompt_caching import AnthropicPromptCachingMiddleware
 from langchain.agents.middleware.summarization import SummarizationMiddleware
 from langchain.agents.middleware.types import (
     AgentMiddleware,
-    ModelRequest,
     AgentState,
+    ModelRequest,
     OmitFromInput,
     OmitFromOutput,
     PrivateStateAttr,
 )
-
-from langgraph.checkpoint.base import BaseCheckpointSaver
-from langgraph.checkpoint.memory import InMemorySaver
-from langgraph.constants import END
-from langgraph.graph.message import REMOVE_ALL_MESSAGES
-from langgraph.types import Command
+from langchain.agents.middleware_agent import create_agent
 from langchain.agents.structured_output import ToolStrategy
+from langchain.tools import InjectedState
 
 from .messages import _AnyIdHumanMessage, _AnyIdToolMessage
 from .model import FakeToolCallingModel
@@ -1105,14 +1111,9 @@ def test_summarization_middleware_summary_creation() -> None:
 
     class MockModel(BaseChatModel):
         def invoke(self, prompt):
-            from langchain_core.messages import AIMessage
-
             return AIMessage(content="Generated summary")
 
         def _generate(self, messages, **kwargs):
-            from langchain_core.outputs import ChatResult, ChatGeneration
-            from langchain_core.messages import AIMessage
-
             return ChatResult(generations=[ChatGeneration(message=AIMessage(content="Summary"))])
 
         @property
@@ -1136,9 +1137,6 @@ def invoke(self, prompt):
             raise Exception("Model error")
 
         def _generate(self, messages, **kwargs):
-            from langchain_core.outputs import ChatResult, ChatGeneration
-            from langchain_core.messages import AIMessage
-
             return ChatResult(generations=[ChatGeneration(message=AIMessage(content="Summary"))])
 
         @property
@@ -1155,14 +1153,9 @@ def test_summarization_middleware_full_workflow() -> None:
 
     class MockModel(BaseChatModel):
         def invoke(self, prompt):
-            from langchain_core.messages import AIMessage
-
             return AIMessage(content="Generated summary")
 
         def _generate(self, messages, **kwargs):
-            from langchain_core.outputs import ChatResult, ChatGeneration
-            from langchain_core.messages import AIMessage
-
             return ChatResult(generations=[ChatGeneration(message=AIMessage(content="Summary"))])
 
         @property
@@ -1423,3 +1416,248 @@ def after_model(self, state: AgentState) -> dict[str, Any]:
     agent = agent.compile()
     result = agent.invoke({"messages": [HumanMessage("Hello")]})
     assert "jump_to" not in result
+
+
+# Tests for PlanningMiddleware
+def test_planning_middleware_initialization() -> None:
+    """Test that PlanningMiddleware initializes correctly."""
+    middleware = PlanningMiddleware()
+    assert middleware.state_schema == PlanningState
+    assert len(middleware.tools) == 1
+    assert middleware.tools[0].name == "write_todos"
+
+
+@pytest.mark.parametrize(
+    "original_prompt,expected_prompt_prefix",
+    [
+        ("Original prompt", "Original prompt\n\n## `write_todos`"),
+        (None, "## `write_todos`"),
+    ],
+)
+def test_planning_middleware_modify_model_request(original_prompt, expected_prompt_prefix) -> None:
+    """Test that modify_model_request handles system prompts correctly."""
+    middleware = PlanningMiddleware()
+    model = FakeToolCallingModel()
+
+    request = ModelRequest(
+        model=model,
+        system_prompt=original_prompt,
+        messages=[HumanMessage(content="Hello")],
+        tool_choice=None,
+        tools=[],
+        response_format=None,
+        model_settings={},
+    )
+
+    state: PlanningState = {"messages": [HumanMessage(content="Hello")]}
+    modified_request = middleware.modify_model_request(request, state)
+    assert modified_request.system_prompt.startswith(expected_prompt_prefix)
+
+
+@pytest.mark.parametrize(
+    "todos,expected_message",
+    [
+        ([], "Updated todo list to []"),
+        (
+            [{"content": "Task 1", "status": "pending"}],
+            "Updated todo list to [{'content': 'Task 1', 'status': 'pending'}]",
+        ),
+        (
+            [
+                {"content": "Task 1", "status": "pending"},
+                {"content": "Task 2", "status": "in_progress"},
+            ],
+            "Updated todo list to [{'content': 'Task 1', 'status': 'pending'}, {'content': 'Task 2', 'status': 'in_progress'}]",
+        ),
+        (
+            [
+                {"content": "Task 1", "status": "pending"},
+                {"content": "Task 2", "status": "in_progress"},
+                {"content": "Task 3", "status": "completed"},
+            ],
+            "Updated todo list to [{'content': 'Task 1', 'status': 'pending'}, {'content': 'Task 2', 'status': 'in_progress'}, {'content': 'Task 3', 'status': 'completed'}]",
+        ),
+    ],
+)
+def test_planning_middleware_write_todos_tool_execution(todos, expected_message) -> None:
+    """Test that the write_todos tool executes correctly."""
+    tool_call = {
+        "args": {"todos": todos},
+        "name": "write_todos",
+        "type": "tool_call",
+        "id": "test_call",
+    }
+    result = write_todos.invoke(tool_call)
+    assert result.update["todos"] == todos
+    assert result.update["messages"][0].content == expected_message
+
+
+@pytest.mark.parametrize(
+    "invalid_todos",
+    [
+        [{"content": "Task 1", "status": "invalid_status"}],
+        [{"status": "pending"}],
+    ],
+)
+def test_planning_middleware_write_todos_tool_validation_errors(invalid_todos) -> None:
+    """Test that the write_todos tool rejects invalid input."""
+    tool_call = {
+        "args": {"todos": invalid_todos},
+        "name": "write_todos",
+        "type": "tool_call",
+        "id": "test_call",
+    }
+    with pytest.raises(Exception):
+        write_todos.invoke(tool_call)
+
+
+def test_planning_middleware_agent_creation_with_middleware() -> None:
+    """Test that an agent can be created with the planning middleware."""
+    model = FakeToolCallingModel(
+        tool_calls=[
+            [
+                {
+                    "args": {"todos": [{"content": "Task 1", "status": "pending"}]},
+                    "name": "write_todos",
+                    "type": "tool_call",
+                    "id": "test_call",
+                }
+            ],
+            [
+                {
+                    "args": {"todos": [{"content": "Task 1", "status": "in_progress"}]},
+                    "name": "write_todos",
+                    "type": "tool_call",
+                    "id": "test_call",
+                }
+            ],
+            [
+                {
+                    "args": {"todos": [{"content": "Task 1", "status": "completed"}]},
+                    "name": "write_todos",
+                    "type": "tool_call",
+                    "id": "test_call",
+                }
+            ],
+            [],
+        ]
+    )
+    middleware = PlanningMiddleware()
+    agent = create_agent(model=model, middleware=[middleware])
+    agent = agent.compile()
+
+    result = agent.invoke({"messages": [HumanMessage("Hello")]})
+    assert result["todos"] == [{"content": "Task 1", "status": "completed"}]
+
+    # human message (1)
+    # ai message (2) - initial todo
+    # tool message (3)
+    # ai message (4) - updated todo
+    # tool message (5)
+    # ai message (6) - complete todo
+    # tool message (7)
+    # ai message (8) - no tool calls
+    assert len(result["messages"]) == 8
+
+
+def test_planning_middleware_custom_system_prompt() -> None:
+    """Test that PlanningMiddleware can be initialized with custom system prompt."""
+    custom_system_prompt = "Custom todo system prompt for testing"
+    middleware = PlanningMiddleware(system_prompt=custom_system_prompt)
+    model = FakeToolCallingModel()
+
+    request = ModelRequest(
+        model=model,
+        system_prompt="Original prompt",
+        messages=[HumanMessage(content="Hello")],
+        tool_choice=None,
+        tools=[],
+        response_format=None,
+        model_settings={},
+    )
+
+    state: PlanningState = {"messages": [HumanMessage(content="Hello")]}
+    modified_request = middleware.modify_model_request(request, state)
+    assert modified_request.system_prompt == f"Original prompt\n\n{custom_system_prompt}"
+
+
+def test_planning_middleware_custom_tool_description() -> None:
+    """Test that PlanningMiddleware can be initialized with custom tool description."""
+    custom_tool_description = "Custom tool description for testing"
+    middleware = PlanningMiddleware(tool_description=custom_tool_description)
+
+    assert len(middleware.tools) == 1
+    tool = middleware.tools[0]
+    assert tool.description == custom_tool_description
+
+
+def test_planning_middleware_custom_system_prompt_and_tool_description() -> None:
+    """Test that PlanningMiddleware can be initialized with both custom prompts."""
+    custom_system_prompt = "Custom system prompt"
+    custom_tool_description = "Custom tool description"
+    middleware = PlanningMiddleware(
+        system_prompt=custom_system_prompt,
+        tool_description=custom_tool_description,
+    )
+
+    # Verify system prompt
+    model = FakeToolCallingModel()
+    request = ModelRequest(
+        model=model,
+        system_prompt=None,
+        messages=[HumanMessage(content="Hello")],
+        tool_choice=None,
+        tools=[],
+        response_format=None,
+        model_settings={},
+    )
+
+    state: PlanningState = {"messages": [HumanMessage(content="Hello")]}
+    modified_request = middleware.modify_model_request(request, state)
+    assert modified_request.system_prompt == custom_system_prompt
+
+    # Verify tool description
+    assert len(middleware.tools) == 1
+    tool = middleware.tools[0]
+    assert tool.description == custom_tool_description
+
+
+def test_planning_middleware_default_prompts() -> None:
+    """Test that PlanningMiddleware uses default prompts when none provided."""
+    middleware = PlanningMiddleware()
+
+    # Verify default system prompt
+    assert middleware.system_prompt == WRITE_TODOS_SYSTEM_PROMPT
+
+    # Verify default tool description
+    assert middleware.tool_description == WRITE_TODOS_TOOL_DESCRIPTION
+    assert len(middleware.tools) == 1
+    tool = middleware.tools[0]
+    assert tool.description == WRITE_TODOS_TOOL_DESCRIPTION
+
+
+def test_planning_middleware_custom_system_prompt() -> None:
+    """Test that custom tool executes correctly in an agent."""
+    middleware = PlanningMiddleware(system_prompt="call the write_todos tool")
+
+    model = FakeToolCallingModel(
+        tool_calls=[
+            [
+                {
+                    "args": {"todos": [{"content": "Custom task", "status": "pending"}]},
+                    "name": "write_todos",
+                    "type": "tool_call",
+                    "id": "test_call",
+                }
+            ],
+            [],
+        ]
+    )
+
+    agent = create_agent(model=model, middleware=[middleware])
+    agent = agent.compile()
+
+    result = agent.invoke({"messages": [HumanMessage("Hello")]})
+    assert result["todos"] == [{"content": "Custom task", "status": "pending"}]
+    # assert custom system prompt is in the first AI message
+    assert "call the write_todos tool" in result["messages"][1].content
EOF_114329324912

# Set environment variables
export PYTHONPATH=/testbed:$PYTHONPATH
export LANGGRAPH_TEST_FAST=1

# Change to the langchain_v1 package directory
cd /testbed/libs/langchain_v1

# Run the target test file using uv run
# Using -v for verbose output and --tb=short for concise tracebacks
uv run pytest tests/unit_tests/agents/test_middleware_agent.py -v --tb=short

# Capture exit code immediately after test execution
rc=$?

# Required: Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Reset the test file to original state
cd /testbed
git checkout 729637a347cceac75201f3f89ea48f135d9d75ba "libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py"

# Exit with the captured return code
exit $rc