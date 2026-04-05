#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 5f9e3e33cd51c3fffd0111302476412f49a06e01 "libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py b/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py
--- a/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py
+++ b/libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py
@@ -29,7 +29,7 @@
 from typing_extensions import Annotated
 
 from langchain.agents.middleware.human_in_the_loop import (
-    ActionRequest,
+    Action,
     HumanInTheLoopMiddleware,
 )
 from langchain.agents.middleware.planning import (
@@ -463,14 +463,12 @@ def test_human_in_the_loop_middleware_initialization() -> None:
     """Test HumanInTheLoopMiddleware initialization."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_accept": True, "allow_edit": True, "allow_respond": True}
-        },
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}},
         description_prefix="Custom prefix",
     )
 
     assert middleware.interrupt_on == {
-        "test_tool": {"allow_accept": True, "allow_edit": True, "allow_respond": True}
+        "test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}
     }
     assert middleware.description_prefix == "Custom prefix"
 
@@ -479,9 +477,7 @@ def test_human_in_the_loop_middleware_no_interrupts_needed() -> None:
     """Test HumanInTheLoopMiddleware when no interrupts are needed."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_respond": True, "allow_edit": True, "allow_accept": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     # Test with no messages
@@ -508,9 +504,7 @@ def test_human_in_the_loop_middleware_single_tool_accept() -> None:
     """Test HumanInTheLoopMiddleware with single tool accept response."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_respond": True, "allow_edit": True, "allow_accept": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -520,7 +514,7 @@ def test_human_in_the_loop_middleware_single_tool_accept() -> None:
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_accept(requests):
-        return [{"type": "accept", "args": None}]
+        return {"decisions": [{"type": "approve"}]}
 
     with patch("langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_accept):
         result = middleware.after_model(state, None)
@@ -543,9 +537,7 @@ def mock_accept(requests):
 def test_human_in_the_loop_middleware_single_tool_edit() -> None:
     """Test HumanInTheLoopMiddleware with single tool edit response."""
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_respond": True, "allow_edit": True, "allow_accept": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -555,15 +547,17 @@ def test_human_in_the_loop_middleware_single_tool_edit() -> None:
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_edit(requests):
-        return [
-            {
-                "type": "edit",
-                "args": ActionRequest(
-                    action="test_tool",
-                    args={"input": "edited"},
-                ),
-            }
-        ]
+        return {
+            "decisions": [
+                {
+                    "type": "edit",
+                    "edited_action": Action(
+                        name="test_tool",
+                        arguments={"input": "edited"},
+                    ),
+                }
+            ]
+        }
 
     with patch("langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_edit):
         result = middleware.after_model(state, None)
@@ -578,9 +572,7 @@ def test_human_in_the_loop_middleware_single_tool_response() -> None:
     """Test HumanInTheLoopMiddleware with single tool response with custom message."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_respond": True, "allow_edit": True, "allow_accept": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -590,7 +582,7 @@ def test_human_in_the_loop_middleware_single_tool_response() -> None:
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_response(requests):
-        return [{"type": "response", "args": "Custom response message"}]
+        return {"decisions": [{"type": "reject", "message": "Custom response message"}]}
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_response
@@ -611,8 +603,8 @@ def test_human_in_the_loop_middleware_multiple_tools_mixed_responses() -> None:
 
     middleware = HumanInTheLoopMiddleware(
         interrupt_on={
-            "get_forecast": {"allow_accept": True, "allow_edit": True, "allow_respond": True},
-            "get_temperature": {"allow_accept": True, "allow_edit": True, "allow_respond": True},
+            "get_forecast": {"allowed_decisions": ["approve", "edit", "reject"]},
+            "get_temperature": {"allowed_decisions": ["approve", "edit", "reject"]},
         }
     )
 
@@ -626,10 +618,12 @@ def test_human_in_the_loop_middleware_multiple_tools_mixed_responses() -> None:
     state = {"messages": [HumanMessage(content="What's the weather?"), ai_message]}
 
     def mock_mixed_responses(requests):
-        return [
-            {"type": "accept", "args": None},
-            {"type": "response", "args": "User rejected this tool call"},
-        ]
+        return {
+            "decisions": [
+                {"type": "approve"},
+                {"type": "reject", "message": "User rejected this tool call"},
+            ]
+        }
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_mixed_responses
@@ -659,8 +653,8 @@ def test_human_in_the_loop_middleware_multiple_tools_edit_responses() -> None:
 
     middleware = HumanInTheLoopMiddleware(
         interrupt_on={
-            "get_forecast": {"allow_accept": True, "allow_edit": True, "allow_respond": True},
-            "get_temperature": {"allow_accept": True, "allow_edit": True, "allow_respond": True},
+            "get_forecast": {"allowed_decisions": ["approve", "edit", "reject"]},
+            "get_temperature": {"allowed_decisions": ["approve", "edit", "reject"]},
         }
     )
 
@@ -674,22 +668,24 @@ def test_human_in_the_loop_middleware_multiple_tools_edit_responses() -> None:
     state = {"messages": [HumanMessage(content="What's the weather?"), ai_message]}
 
     def mock_edit_responses(requests):
-        return [
-            {
-                "type": "edit",
-                "args": ActionRequest(
-                    action="get_forecast",
-                    args={"location": "New York"},
-                ),
-            },
-            {
-                "type": "edit",
-                "args": ActionRequest(
-                    action="get_temperature",
-                    args={"location": "New York"},
-                ),
-            },
-        ]
+        return {
+            "decisions": [
+                {
+                    "type": "edit",
+                    "edited_action": Action(
+                        name="get_forecast",
+                        arguments={"location": "New York"},
+                    ),
+                },
+                {
+                    "type": "edit",
+                    "edited_action": Action(
+                        name="get_temperature",
+                        arguments={"location": "New York"},
+                    ),
+                },
+            ]
+        }
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_edit_responses
@@ -710,9 +706,7 @@ def test_human_in_the_loop_middleware_edit_with_modified_args() -> None:
     """Test HumanInTheLoopMiddleware with edit action that includes modified args."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_accept": True, "allow_edit": True, "allow_respond": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -722,15 +716,17 @@ def test_human_in_the_loop_middleware_edit_with_modified_args() -> None:
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_edit_with_args(requests):
-        return [
-            {
-                "type": "edit",
-                "args": ActionRequest(
-                    action="test_tool",
-                    args={"input": "modified"},
-                ),
-            }
-        ]
+        return {
+            "decisions": [
+                {
+                    "type": "edit",
+                    "edited_action": Action(
+                        name="test_tool",
+                        arguments={"input": "modified"},
+                    ),
+                }
+            ]
+        }
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt",
@@ -750,9 +746,7 @@ def mock_edit_with_args(requests):
 def test_human_in_the_loop_middleware_unknown_response_type() -> None:
     """Test HumanInTheLoopMiddleware with unknown response type."""
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_accept": True, "allow_edit": True, "allow_respond": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -762,12 +756,12 @@ def test_human_in_the_loop_middleware_unknown_response_type() -> None:
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_unknown(requests):
-        return [{"type": "unknown", "args": None}]
+        return {"decisions": [{"type": "unknown"}]}
 
     with patch("langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_unknown):
         with pytest.raises(
             ValueError,
-            match=r"Unexpected human response: {'type': 'unknown', 'args': None}. Response action 'unknown' is not allowed for tool 'test_tool'. Expected one of \['accept', 'edit', 'response'\] based on the tool's configuration.",
+            match=r"Unexpected human decision: {'type': 'unknown'}. Decision type 'unknown' is not allowed for tool 'test_tool'. Expected one of \['approve', 'edit', 'reject'\] based on the tool's configuration.",
         ):
             middleware.after_model(state, None)
 
@@ -777,9 +771,7 @@ def test_human_in_the_loop_middleware_disallowed_action() -> None:
 
     # edit is not allowed by tool config
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_respond": True, "allow_edit": False, "allow_accept": True}
-        }
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -789,23 +781,25 @@ def test_human_in_the_loop_middleware_disallowed_action() -> None:
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_disallowed_action(requests):
-        return [
-            {
-                "type": "edit",
-                "args": ActionRequest(
-                    action="test_tool",
-                    args={"input": "modified"},
-                ),
-            }
-        ]
+        return {
+            "decisions": [
+                {
+                    "type": "edit",
+                    "edited_action": Action(
+                        name="test_tool",
+                        arguments={"input": "modified"},
+                    ),
+                }
+            ]
+        }
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt",
         side_effect=mock_disallowed_action,
     ):
         with pytest.raises(
             ValueError,
-            match=r"Unexpected human response: {'type': 'edit', 'args': {'action': 'test_tool', 'args': {'input': 'modified'}}}. Response action 'edit' is not allowed for tool 'test_tool'. Expected one of \['accept', 'response'\] based on the tool's configuration.",
+            match=r"Unexpected human decision: {'type': 'edit', 'edited_action': {'name': 'test_tool', 'arguments': {'input': 'modified'}}}. Decision type 'edit' is not allowed for tool 'test_tool'. Expected one of \['approve', 'reject'\] based on the tool's configuration.",
         ):
             middleware.after_model(state, None)
 
@@ -814,9 +808,7 @@ def test_human_in_the_loop_middleware_mixed_auto_approved_and_interrupt() -> Non
     """Test HumanInTheLoopMiddleware with mix of auto-approved and interrupt tools."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "interrupt_tool": {"allow_respond": True, "allow_edit": True, "allow_accept": True}
-        }
+        interrupt_on={"interrupt_tool": {"allowed_decisions": ["approve", "edit", "reject"]}}
     )
 
     ai_message = AIMessage(
@@ -829,7 +821,7 @@ def test_human_in_the_loop_middleware_mixed_auto_approved_and_interrupt() -> Non
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
     def mock_accept(requests):
-        return [{"type": "accept", "args": None}]
+        return {"decisions": [{"type": "approve"}]}
 
     with patch("langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_accept):
         result = middleware.after_model(state, None)
@@ -848,9 +840,7 @@ def test_human_in_the_loop_middleware_interrupt_request_structure() -> None:
     """Test that interrupt requests are structured correctly."""
 
     middleware = HumanInTheLoopMiddleware(
-        interrupt_on={
-            "test_tool": {"allow_accept": True, "allow_edit": True, "allow_respond": True}
-        },
+        interrupt_on={"test_tool": {"allowed_decisions": ["approve", "edit", "reject"]}},
         description_prefix="Custom prefix",
     )
 
@@ -860,31 +850,34 @@ def test_human_in_the_loop_middleware_interrupt_request_structure() -> None:
     )
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
-    captured_requests = []
+    captured_request = None
 
-    def mock_capture_requests(requests):
-        captured_requests.extend(requests)
-        return [{"type": "accept", "args": None}]
+    def mock_capture_requests(request):
+        nonlocal captured_request
+        captured_request = request
+        return {"decisions": [{"type": "approve"}]}
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_capture_requests
     ):
         middleware.after_model(state, None)
 
-        assert len(captured_requests) == 1
-        request = captured_requests[0]
+        assert captured_request is not None
+        assert "action_requests" in captured_request
+        assert "review_configs" in captured_request
 
-        assert "action_request" in request
-        assert "config" in request
-        assert "description" in request
+        assert len(captured_request["action_requests"]) == 1
+        action_request = captured_request["action_requests"][0]
+        assert action_request["name"] == "test_tool"
+        assert action_request["arguments"] == {"input": "test", "location": "SF"}
+        assert "Custom prefix" in action_request["description"]
+        assert "Tool: test_tool" in action_request["description"]
+        assert "Args: {'input': 'test', 'location': 'SF'}" in action_request["description"]
 
-        assert request["action_request"]["action"] == "test_tool"
-        assert request["action_request"]["args"] == {"input": "test", "location": "SF"}
-        expected_config = {"allow_accept": True, "allow_edit": True, "allow_respond": True}
-        assert request["config"] == expected_config
-        assert "Custom prefix" in request["description"]
-        assert "Tool: test_tool" in request["description"]
-        assert "Args: {'input': 'test', 'location': 'SF'}" in request["description"]
+        assert len(captured_request["review_configs"]) == 1
+        review_config = captured_request["review_configs"][0]
+        assert review_config["action_name"] == "test_tool"
+        assert review_config["allowed_decisions"] == ["approve", "edit", "reject"]
 
 
 def test_human_in_the_loop_middleware_boolean_configs() -> None:
@@ -900,7 +893,7 @@ def test_human_in_the_loop_middleware_boolean_configs() -> None:
     # Test accept
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt",
-        return_value=[{"type": "accept", "args": None}],
+        return_value={"decisions": [{"type": "approve"}]},
     ):
         result = middleware.after_model(state, None)
         assert result is not None
@@ -911,15 +904,17 @@ def test_human_in_the_loop_middleware_boolean_configs() -> None:
     # Test edit
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt",
-        return_value=[
-            {
-                "type": "edit",
-                "args": ActionRequest(
-                    action="test_tool",
-                    args={"input": "edited"},
-                ),
-            }
-        ],
+        return_value={
+            "decisions": [
+                {
+                    "type": "edit",
+                    "edited_action": Action(
+                        name="test_tool",
+                        arguments={"input": "edited"},
+                    ),
+                }
+            ]
+        },
     ):
         result = middleware.after_model(state, None)
         assert result is not None
@@ -947,25 +942,27 @@ def test_human_in_the_loop_middleware_sequence_mismatch() -> None:
     # Test with too few responses
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt",
-        return_value=[],  # No responses for 1 tool call
+        return_value={"decisions": []},  # No responses for 1 tool call
     ):
         with pytest.raises(
             ValueError,
-            match=r"Number of human responses \(0\) does not match number of hanging tool calls \(1\)\.",
+            match=r"Number of human decisions \(0\) does not match number of hanging tool calls \(1\)\.",
         ):
             middleware.after_model(state, None)
 
     # Test with too many responses
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt",
-        return_value=[
-            {"type": "accept", "args": None},
-            {"type": "accept", "args": None},
-        ],  # 2 responses for 1 tool call
+        return_value={
+            "decisions": [
+                {"type": "approve"},
+                {"type": "approve"},
+            ]
+        },  # 2 responses for 1 tool call
     ):
         with pytest.raises(
             ValueError,
-            match=r"Number of human responses \(2\) does not match number of hanging tool calls \(1\)\.",
+            match=r"Number of human decisions \(2\) does not match number of hanging tool calls \(1\)\.",
         ):
             middleware.after_model(state, None)
 
@@ -979,8 +976,14 @@ def custom_description(tool_call: ToolCall, state: AgentState, runtime: Runtime)
 
     middleware = HumanInTheLoopMiddleware(
         interrupt_on={
-            "tool_with_callable": {"allow_accept": True, "description": custom_description},
-            "tool_with_string": {"allow_accept": True, "description": "Static description"},
+            "tool_with_callable": {
+                "allowed_decisions": ["approve"],
+                "description": custom_description,
+            },
+            "tool_with_string": {
+                "allowed_decisions": ["approve"],
+                "description": "Static description",
+            },
         }
     )
 
@@ -993,26 +996,30 @@ def custom_description(tool_call: ToolCall, state: AgentState, runtime: Runtime)
     )
     state = {"messages": [HumanMessage(content="Hello"), ai_message]}
 
-    captured_requests = []
+    captured_request = None
 
-    def mock_capture_requests(requests):
-        captured_requests.extend(requests)
-        return [{"type": "accept"}, {"type": "accept"}]
+    def mock_capture_requests(request):
+        nonlocal captured_request
+        captured_request = request
+        return {"decisions": [{"type": "approve"}, {"type": "approve"}]}
 
     with patch(
         "langchain.agents.middleware.human_in_the_loop.interrupt", side_effect=mock_capture_requests
     ):
         middleware.after_model(state, None)
 
-        assert len(captured_requests) == 2
+        assert captured_request is not None
+        assert "action_requests" in captured_request
+        assert len(captured_request["action_requests"]) == 2
 
         # Check callable description
         assert (
-            captured_requests[0]["description"] == "Custom: tool_with_callable with args {'x': 1}"
+            captured_request["action_requests"][0]["description"]
+            == "Custom: tool_with_callable with args {'x': 1}"
         )
 
         # Check string description
-        assert captured_requests[1]["description"] == "Static description"
+        assert captured_request["action_requests"][1]["description"] == "Static description"
 
 
 # Tests for AnthropicPromptCachingMiddleware
EOF_114329324912

# Change to the langchain_v1 package directory as specified in project structure
cd /testbed/libs/langchain_v1

# Set environment variables for test execution
export UV_FROZEN=true
export LANGGRAPH_TEST_FAST=1

# Execute the target test file using uv with pytest
# Running in single-process mode for safety in virtualized environment
# Disabling socket connections as specified in the project's test configuration
uv run --group test pytest \
    tests/unit_tests/agents/test_middleware_agent.py \
    --disable-socket --allow-unix-socket \
    -v

# Capture exit code immediately after test execution
rc=$?

# Required: Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Reset the test files to original state
cd /testbed
git checkout 5f9e3e33cd51c3fffd0111302476412f49a06e01 "libs/langchain_v1/tests/unit_tests/agents/test_middleware_agent.py"