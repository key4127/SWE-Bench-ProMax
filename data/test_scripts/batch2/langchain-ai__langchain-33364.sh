#!/bin/bash
set -uxo pipefail

# Navigate to testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 68c56440cfb95a20c42bfe87f15cdbae16df0876 "libs/langchain_v1/tests/unit_tests/agents/test_on_tool_call_middleware.py" "libs/langchain_v1/tests/unit_tests/tools/test_on_tool_call.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/libs/langchain_v1/tests/unit_tests/agents/test_on_tool_call_middleware.py b/libs/langchain_v1/tests/unit_tests/agents/test_on_tool_call_middleware.py
--- a/libs/langchain_v1/tests/unit_tests/agents/test_on_tool_call_middleware.py
+++ b/libs/langchain_v1/tests/unit_tests/agents/test_on_tool_call_middleware.py
@@ -1,6 +1,6 @@
 """Unit tests for on_tool_call middleware integration."""
 
-from collections.abc import Generator
+from collections.abc import Callable
 
 import pytest
 from langchain_core.messages import HumanMessage, ToolCall, ToolMessage
@@ -41,11 +41,14 @@ class LoggingMiddleware(AgentMiddleware):
         """Middleware that logs tool calls."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append(f"before_{request.tool.name}")
-            response = yield request
+            response = handler(request)
             call_log.append(f"after_{request.tool.name}")
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -79,13 +82,15 @@ class ModifyArgsMiddleware(AgentMiddleware):
         """Middleware that modifies tool arguments."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             # Add prefix to query
             if request.tool.name == "search":
                 original_query = request.tool_call["args"]["query"]
                 request.tool_call["args"]["query"] = f"modified: {original_query}"
-            response = yield request
+            return handler(request)
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -119,9 +124,11 @@ class ResponseInspectionMiddleware(AgentMiddleware):
         """Middleware that inspects responses."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
-            response = yield request
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
+            response = handler(request)
 
             # Record response details
             if isinstance(response, ToolMessage):
@@ -131,6 +138,7 @@ def on_tool_call(
                         "content": response.content,
                     }
                 )
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -166,13 +174,15 @@ class ConditionalRetryMiddleware(AgentMiddleware):
         """Middleware that retries based on response content."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             nonlocal call_count
             max_retries = 2
 
             for attempt in range(max_retries):
-                response = yield request
+                response = handler(request)
                 call_count += 1
 
                 # Check if we should retry based on content
@@ -185,6 +195,9 @@ def on_tool_call(
                     continue
 
                 # Return on success or final attempt
+                return response
+
+            return response
 
     # Use search tool which always succeeds - we'll modify request to test retry logic
     model = FakeToolCallingModel(
@@ -220,21 +233,27 @@ class OuterMiddleware(AgentMiddleware):
         """Outer middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("outer_before")
-            response = yield request
+            response = handler(request)
             call_log.append("outer_after")
+            return response
 
     class InnerMiddleware(AgentMiddleware):
         """Inner middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("inner_before")
-            response = yield request
+            response = handler(request)
             call_log.append("inner_after")
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -269,10 +288,12 @@ class LoggingMiddleware(AgentMiddleware):
         """Middleware that logs tool calls."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append(request.tool.name)
-            response = yield request
+            return handler(request)
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -313,17 +334,20 @@ class StateInspectionMiddleware(AgentMiddleware):
         """Middleware that inspects state."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
-            # Record state - state could be dict or list
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
+            # Record state - state is now in request.state
+            state = request.state
             if state is not None:
                 if isinstance(state, dict) and "messages" in state:
                     state_seen.append(("dict", len(state["messages"])))
                 elif isinstance(state, list):
                     state_seen.append(("list", len(state)))
                 else:
                     state_seen.append(("other", type(state).__name__))
-            response = yield request
+            return handler(request)
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -383,36 +407,41 @@ def before_model(self, state, runtime):
 
 
 def test_generator_composition_immediate_outer_return() -> None:
-    """Test composition when outer generator returns after first yield."""
+    """Test composition when outer handler intercepts response."""
     call_log = []
 
     class ImmediateReturnMiddleware(AgentMiddleware):
-        """Outer middleware that returns after first yield."""
+        """Outer middleware that intercepts and modifies response."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("outer_yield")
-            # Yield once, receive response from inner
-            response = yield request
+            # Call handler, receive response from inner
+            response = handler(request)
             call_log.append("outer_got_response")
-            # Yield modified message to make it the final result
+            # Return modified message
             modified = ToolMessage(
                 content="Outer intercepted",
                 tool_call_id=request.tool_call["id"],
                 name=request.tool_call["name"],
             )
-            yield modified
+            return modified
 
     class InnerMiddleware(AgentMiddleware):
         """Inner middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("inner_called")
-            response = yield request
+            response = handler(request)
             call_log.append("inner_got_response")
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -442,17 +471,19 @@ def on_tool_call(
 
 
 def test_generator_composition_short_circuit() -> None:
-    """Test composition when inner generator short-circuits after first yield."""
+    """Test composition when inner handler short-circuits."""
     call_log = []
 
     class OuterMiddleware(AgentMiddleware):
         """Outer middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("outer_before")
-            response = yield request
+            response = handler(request)
             call_log.append("outer_after")
             # Modify response from inner
             if isinstance(response, ToolMessage):
@@ -461,19 +492,20 @@ def on_tool_call(
                     tool_call_id=response.tool_call_id,
                     name=response.name,
                 )
-                yield modified
+                return modified
+            return response
 
     class InnerShortCircuitMiddleware(AgentMiddleware):
         """Inner middleware that short-circuits without calling actual tool."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("inner_short_circuit")
-            # Yield request but return custom response instead of actual tool result
-            _ = yield request
-            # Return custom result without using actual tool response
-            yield ToolMessage(
+            # Don't call handler, return custom response directly
+            return ToolMessage(
                 content="inner_short_circuit_result",
                 tool_call_id=request.tool_call["id"],
                 name=request.tool_call["name"],
@@ -507,42 +539,49 @@ def on_tool_call(
 
 
 def test_generator_composition_nested_retries() -> None:
-    """Test composition when both outer and inner generators retry."""
+    """Test composition when both outer and inner handlers retry."""
     call_log = []
 
     class OuterRetryMiddleware(AgentMiddleware):
         """Outer middleware with retry logic."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             for outer_attempt in range(2):
                 call_log.append(f"outer_{outer_attempt}")
-                response = yield request
+                response = handler(request)
 
                 if isinstance(response, ToolMessage) and response.content == "inner_final_failure":
                     # Inner failed, retry once
                     continue
+                return response
+            return response
 
     class InnerRetryMiddleware(AgentMiddleware):
         """Inner middleware with retry logic."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             for inner_attempt in range(2):
                 call_log.append(f"inner_{inner_attempt}")
-                response = yield request
+                response = handler(request)
 
                 # Check for error in tool result
                 if isinstance(response, ToolMessage):
                     if inner_attempt == 0 and "Results for:" in response.content:
                         # First attempt succeeded, but let's pretend it's a soft failure
                         # to test inner retry
                         continue
+                    return response
 
             # Inner exhausted retries
-            yield ToolMessage(
+            return ToolMessage(
                 content="inner_final_failure",
                 tool_call_id=request.tool_call["id"],
                 name=request.tool_call["name"],
@@ -584,31 +623,40 @@ class OuterMiddleware(AgentMiddleware):
         """Outermost middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("outer_before")
-            response = yield request
+            response = handler(request)
             call_log.append("outer_after")
+            return response
 
     class MiddleMiddleware(AgentMiddleware):
         """Middle middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("middle_before")
-            response = yield request
+            response = handler(request)
             call_log.append("middle_after")
+            return response
 
     class InnerMiddleware(AgentMiddleware):
         """Innermost middleware."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("inner_before")
-            response = yield request
+            response = handler(request)
             call_log.append("inner_after")
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -644,26 +692,29 @@ def on_tool_call(
 
 
 def test_generator_composition_return_value_extraction() -> None:
-    """Test that return values are properly extracted from StopIteration."""
+    """Test that handler can modify and return response."""
     final_content = []
 
     class ModifyingMiddleware(AgentMiddleware):
         """Middleware that modifies the final result."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest, ToolMessage, None]:
-            response = yield request
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
+            response = handler(request)
 
-            # Explicitly return a modified response
+            # Return a modified response
             if isinstance(response, ToolMessage):
                 modified = ToolMessage(
                     content=f"modified: {response.content}",
                     tool_call_id=response.tool_call_id,
                     name=response.name,
                 )
                 final_content.append(modified.content)
-                yield modified
+                return modified
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
@@ -693,30 +744,35 @@ def on_tool_call(
 
 
 def test_generator_composition_with_mixed_passthrough_and_intercepting() -> None:
-    """Test composition with mix of pass-through and intercepting generators."""
+    """Test composition with mix of pass-through and intercepting handlers."""
     call_log = []
 
     class FirstPassthroughMiddleware(AgentMiddleware):
         """First middleware that passes through."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("first_before")
-            response = yield request
+            response = handler(request)
             call_log.append("first_after")
+            return response
 
     class SecondInterceptingMiddleware(AgentMiddleware):
         """Second middleware that intercepts and returns custom result."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("second_intercept")
-            # Yield request but ignore the actual result
-            _ = yield request
+            # Call handler but ignore the result
+            _ = handler(request)
             # Return custom result
-            yield ToolMessage(
+            return ToolMessage(
                 content="intercepted_result",
                 tool_call_id=request.tool_call["id"],
                 name=request.tool_call["name"],
@@ -726,11 +782,14 @@ class ThirdPassthroughMiddleware(AgentMiddleware):
         """Third middleware that passes through."""
 
         def on_tool_call(
-            self, request: ToolCallRequest, state, runtime
-        ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+            self,
+            request: ToolCallRequest,
+            handler: Callable[[ToolCallRequest], ToolMessage | Command],
+        ) -> ToolMessage | Command:
             call_log.append("third_called")
-            response = yield request
+            response = handler(request)
             call_log.append("third_after")
+            return response
 
     model = FakeToolCallingModel(
         tool_calls=[
diff --git a/libs/langchain_v1/tests/unit_tests/tools/test_on_tool_call.py b/libs/langchain_v1/tests/unit_tests/tools/test_on_tool_call.py
--- a/libs/langchain_v1/tests/unit_tests/tools/test_on_tool_call.py
+++ b/libs/langchain_v1/tests/unit_tests/tools/test_on_tool_call.py
@@ -1,7 +1,6 @@
 """Unit tests for on_tool_call handler in ToolNode."""
 
-from collections.abc import Generator
-from typing import Any
+from collections.abc import Callable
 
 import pytest
 from langchain_core.messages import AIMessage, ToolCall, ToolMessage
@@ -39,10 +38,11 @@ def test_passthrough_handler() -> None:
     """Test a simple passthrough handler that doesn't modify anything."""
 
     def passthrough_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Simple passthrough handler."""
-        yield request
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=passthrough_handler)
 
@@ -74,10 +74,11 @@ async def test_passthrough_handler_async() -> None:
     """Test passthrough handler with async tool."""
 
     def passthrough_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Simple passthrough handler."""
-        yield request
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=passthrough_handler)
 
@@ -108,14 +109,15 @@ def test_modify_arguments() -> None:
     """Test handler that modifies tool arguments before execution."""
 
     def modify_args_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that doubles the input arguments."""
         # Modify the arguments
         request.tool_call["args"]["a"] *= 2
         request.tool_call["args"]["b"] *= 2
 
-        yield request
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=modify_args_handler)
 
@@ -143,15 +145,14 @@ def modify_args_handler(
 
 
 def test_handler_validation_no_return() -> None:
-    """Test that handler with explicit None return works (returns last sent message)."""
+    """Test that handler must return a result."""
 
     def handler_with_explicit_none(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that returns None explicitly - should still work."""
-        yield request
-        # Explicit None return - protocol uses last sent message as result
-        return None
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that executes and returns result."""
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=handler_with_explicit_none)
 
@@ -180,50 +181,54 @@ def handler_with_explicit_none(
 
 
 def test_handler_validation_no_yield() -> None:
-    """Test that handler must yield at least once."""
+    """Test that handler that doesn't call execute returns None (bad behavior)."""
 
     def bad_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that ends immediately without yielding."""
-        # End immediately without yielding anything
-        # Need unreachable yield to make this a generator function
-        if False:
-            yield request
-        return
+        _request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that doesn't call execute - will cause type error."""
+        # Don't call execute, just return None (invalid)
+        return None  # type: ignore[return-value]
 
     tool_node = ToolNode([add], on_tool_call=bad_handler)
 
-    with pytest.raises(ValueError, match="must yield at least once"):
-        tool_node.invoke(
-            {
-                "messages": [
-                    AIMessage(
-                        "adding",
-                        tool_calls=[
-                            {
-                                "name": "add",
-                                "args": {"a": 1, "b": 2},
-                                "id": "call_7",
-                            }
-                        ],
-                    )
-                ]
-            }
-        )
+    # This will return None wrapped in messages
+    result = tool_node.invoke(
+        {
+            "messages": [
+                AIMessage(
+                    "adding",
+                    tool_calls=[
+                        {
+                            "name": "add",
+                            "args": {"a": 1, "b": 2},
+                            "id": "call_7",
+                        }
+                    ],
+                )
+            ]
+        }
+    )
+
+    # Result contains None in messages (bad handler behavior)
+    assert isinstance(result, dict)
+    assert result["messages"][0] is None
 
 
 def test_handler_with_handle_tool_errors_true() -> None:
     """Test that handle_tool_errors=True works with on_tool_call handler."""
 
     def passthrough_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Simple passthrough handler."""
-        message = yield request
+        message = execute(request)
         # When handle_tool_errors=True, errors should be converted to error messages
         assert isinstance(message, ToolMessage)
         assert message.status == "error"
+        return message
 
     tool_node = ToolNode([failing_tool], on_tool_call=passthrough_handler, handle_tool_errors=True)
 
@@ -254,12 +259,13 @@ def test_multiple_tool_calls_with_handler() -> None:
     call_count = 0
 
     def counting_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that counts calls."""
         nonlocal call_count
         call_count += 1
-        yield request
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=counting_handler)
 
@@ -305,11 +311,15 @@ def counting_handler(
 def test_tool_call_request_dataclass() -> None:
     """Test ToolCallRequest dataclass."""
     tool_call: ToolCall = {"name": "add", "args": {"a": 1, "b": 2}, "id": "call_1"}
+    state: dict = {"messages": []}
+    runtime = None
 
-    request = ToolCallRequest(tool_call=tool_call, tool=add)
+    request = ToolCallRequest(tool_call=tool_call, tool=add, state=state, runtime=runtime)
 
     assert request.tool_call == tool_call
     assert request.tool == add
+    assert request.state == state
+    assert request.runtime is None
     assert request.tool_call["name"] == "add"
 
 
@@ -322,13 +332,14 @@ async def async_add(a: int, b: int) -> int:
         return a + b
 
     def modifying_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that modifies arguments."""
         # Add 10 to both arguments
         request.tool_call["args"]["a"] += 10
         request.tool_call["args"]["b"] += 10
-        yield request
+        return execute(request)
 
     tool_node = ToolNode([async_add], on_tool_call=modifying_handler)
 
@@ -356,21 +367,19 @@ def modifying_handler(
 
 
 def test_short_circuit_with_tool_message() -> None:
-    """Test handler that yields ToolMessage to short-circuit tool execution."""
+    """Test handler that returns ToolMessage to short-circuit tool execution."""
 
     def short_circuit_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that returns cached result without executing tool."""
-        # Yield a ToolMessage directly instead of a ToolCallRequest
-        cached_result = ToolMessage(
+        # Return a ToolMessage directly instead of calling execute
+        return ToolMessage(
             content="cached_result",
             tool_call_id=request.tool_call["id"],
             name=request.tool_call["name"],
         )
-        message = yield cached_result
-        # Message should be our cached message sent back
-        assert message == cached_result
 
     tool_node = ToolNode([add], on_tool_call=short_circuit_handler)
 
@@ -399,18 +408,18 @@ def short_circuit_handler(
 
 
 async def test_short_circuit_with_tool_message_async() -> None:
-    """Test async handler that yields ToolMessage to short-circuit tool execution."""
+    """Test async handler that returns ToolMessage to short-circuit tool execution."""
 
     def short_circuit_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that returns cached result without executing tool."""
-        cached_result = ToolMessage(
+        return ToolMessage(
             content="async_cached_result",
             tool_call_id=request.tool_call["id"],
             name=request.tool_call["name"],
         )
-        yield cached_result
 
     tool_node = ToolNode([add], on_tool_call=short_circuit_handler)
 
@@ -442,23 +451,22 @@ def test_conditional_short_circuit() -> None:
     call_count = {"count": 0}
 
     def conditional_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that caches even numbers, executes odd."""
         call_count["count"] += 1
         a = request.tool_call["args"]["a"]
 
         if a % 2 == 0:
             # Even: use cached result
-            cached = ToolMessage(
+            return ToolMessage(
                 content=f"cached_{a}",
                 tool_call_id=request.tool_call["id"],
                 name=request.tool_call["name"],
             )
-            yield cached
-        else:
-            # Odd: execute normally
-            yield request
+        # Odd: execute normally
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=conditional_handler)
 
@@ -506,18 +514,15 @@ def conditional_handler(
 
 
 def test_direct_return_tool_message() -> None:
-    """Test handler that returns ToolMessage directly without yielding."""
+    """Test handler that returns ToolMessage directly without calling execute."""
 
     def direct_return_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that returns ToolMessage directly."""
-        # Return ToolMessage directly
-        # Note: We still need this to be a generator, so we use return (not yield)
-        # The generator protocol will catch the StopIteration with the return value
-        if False:
-            yield  # Makes this a generator function
-        yield ToolMessage(
+        # Return ToolMessage directly instead of calling execute
+        return ToolMessage(
             content="direct_return",
             tool_call_id=request.tool_call["id"],
             name=request.tool_call["name"],
@@ -550,15 +555,14 @@ def direct_return_handler(
 
 
 async def test_direct_return_tool_message_async() -> None:
-    """Test async handler that returns ToolMessage directly without yielding."""
+    """Test async handler that returns ToolMessage directly without calling execute."""
 
     def direct_return_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that returns ToolMessage directly."""
-        if False:
-            yield  # Makes this a generator function
-        yield ToolMessage(
+        return ToolMessage(
             content="async_direct_return",
             tool_call_id=request.tool_call["id"],
             name=request.tool_call["name"],
@@ -593,23 +597,21 @@ def test_conditional_direct_return() -> None:
     """Test handler that conditionally returns ToolMessage directly or executes tool."""
 
     def conditional_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that returns cached or executes based on condition."""
         a = request.tool_call["args"]["a"]
 
         if a == 0:
             # Return ToolMessage directly for zero
-            if False:
-                yield  # Makes this a generator
-            yield ToolMessage(
+            return ToolMessage(
                 content="zero_cached",
                 tool_call_id=request.tool_call["id"],
                 name=request.tool_call["name"],
             )
-        else:
-            # Execute tool normally
-            yield request
+        # Execute tool normally
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=conditional_handler)
 
@@ -660,14 +662,16 @@ def test_handler_can_throw_exception() -> None:
     """Test that a handler can throw an exception to signal error."""
 
     def throwing_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that throws an exception after receiving response."""
-        response = yield request
+        response = execute(request)
         # Check response and throw if invalid
         if isinstance(response, ToolMessage):
             msg = "Handler rejected the response"
-            raise ValueError(msg)  # noqa: TRY004
+            raise TypeError(msg)
+        return response
 
     tool_node = ToolNode([add], on_tool_call=throwing_handler, handle_tool_errors=True)
 
@@ -700,10 +704,11 @@ def test_handler_throw_without_handle_errors() -> None:
     """Test that exception propagates when handle_tool_errors=False."""
 
     def throwing_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that throws an exception."""
-        yield request
+        execute(request)
         msg = "Handler error"
         raise ValueError(msg)
 
@@ -729,28 +734,28 @@ def throwing_handler(
 
 
 def test_retry_middleware_with_exception() -> None:
-    """Test retry middleware pattern that throws after exhausting retries."""
+    """Test retry middleware pattern that can call execute multiple times."""
     attempt_count = {"count": 0}
 
     def retry_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that retries up to 3 times, then throws."""
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that can retry by calling execute multiple times."""
         max_retries = 3
 
-        for attempt in range(max_retries):
+        for _attempt in range(max_retries):
             attempt_count["count"] += 1
-            response = yield request
+            response = execute(request)
 
             # Simulate checking for retriable errors
             # In real use case, would check response.status or content
-            if isinstance(response, ToolMessage) and attempt < max_retries - 1:
-                # Could retry based on some condition
+            if isinstance(response, ToolMessage):
                 # For this test, just succeed immediately
-                break
+                return response
 
-        # If we exhausted retries, could throw
-        # For this test, we succeed on first try
+        # If we exhausted retries, return last response
+        return response
 
     tool_node = ToolNode([add], on_tool_call=retry_handler)
 
@@ -783,13 +788,13 @@ async def test_async_handler_can_throw_exception() -> None:
     """Test that async execution also supports exception throwing."""
 
     def throwing_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that throws an exception after receiving response."""
-        response = yield request
-        if isinstance(response, ToolMessage):
-            msg = "Async handler rejected the response"
-            raise ValueError(msg)  # noqa: TRY004
+        _request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that throws an exception before calling execute."""
+        # Throw exception before executing (to avoid async/await complications)
+        msg = "Async handler rejected the request"
+        raise ValueError(msg)
 
     tool_node = ToolNode([add], on_tool_call=throwing_handler, handle_tool_errors=True)
 
@@ -815,90 +820,93 @@ def throwing_handler(
     assert len(messages) == 1
     assert isinstance(messages[0], ToolMessage)
     assert messages[0].status == "error"
-    assert "Async handler rejected the response" in messages[0].content
+    assert "Async handler rejected the request" in messages[0].content
 
 
 def test_handler_cannot_yield_multiple_tool_messages() -> None:
-    """Test that yielding multiple `ToolMessage` objects is rejected."""
-
-    def multi_message_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that incorrectly yields multiple `ToolMessage` objects."""
-        # First short-circuit
-        yield ToolMessage("first", tool_call_id=request.tool_call["id"], name="add")
-        # Second short-circuit - should fail
-        yield ToolMessage("second", tool_call_id=request.tool_call["id"], name="add")
-
-    tool_node = ToolNode([add], on_tool_call=multi_message_handler)
-
-    with pytest.raises(
-        ValueError,
-        match="on_tool_call handler yielded multiple values after short-circuit",
-    ):
-        tool_node.invoke(
-            {
-                "messages": [
-                    AIMessage(
-                        "adding",
-                        tool_calls=[
-                            {
-                                "name": "add",
-                                "args": {"a": 1, "b": 2},
-                                "id": "call_multi_1",
-                            }
-                        ],
-                    )
-                ]
-            }
-        )
+    """Test that handler can only return once (not applicable to handler pattern)."""
+    # With handler pattern, you can only return once by definition
+    # This test is no longer relevant - handlers naturally return once
+    # Keep test for compatibility but with simple passthrough
+
+    def single_return_handler(
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that returns once (as all handlers do)."""
+        return execute(request)
+
+    tool_node = ToolNode([add], on_tool_call=single_return_handler)
+
+    result = tool_node.invoke(
+        {
+            "messages": [
+                AIMessage(
+                    "adding",
+                    tool_calls=[
+                        {
+                            "name": "add",
+                            "args": {"a": 1, "b": 2},
+                            "id": "call_multi_1",
+                        }
+                    ],
+                )
+            ]
+        }
+    )
+
+    # Should succeed - handlers can only return once
+    assert isinstance(result, dict)
+    assert len(result["messages"]) == 1
 
 
 def test_handler_cannot_yield_request_after_tool_message() -> None:
-    """Test that yielding ToolCallRequest after ToolMessage is rejected."""
-
-    def confused_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that incorrectly switches from short-circuit to execution."""
-        # First short-circuit with cached result
-        yield ToolMessage("cached", tool_call_id=request.tool_call["id"], name="add")
-        # Then try to execute - should fail
-        yield request
-
-    tool_node = ToolNode([add], on_tool_call=confused_handler)
-
-    with pytest.raises(
-        ValueError,
-        match="on_tool_call handler yielded ToolCallRequest after short-circuit",
-    ):
-        tool_node.invoke(
-            {
-                "messages": [
-                    AIMessage(
-                        "adding",
-                        tool_calls=[
-                            {
-                                "name": "add",
-                                "args": {"a": 1, "b": 2},
-                                "id": "call_confused_1",
-                            }
-                        ],
-                    )
-                ]
-            }
-        )
+    """Test that handler pattern doesn't allow multiple returns (not applicable)."""
+    # With handler pattern, you can only return once
+    # This test is no longer relevant
+
+    def single_return_handler(
+        request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that returns cached result."""
+        # Return cached result (short-circuit)
+        return ToolMessage("cached", tool_call_id=request.tool_call["id"], name="add")
+
+    tool_node = ToolNode([add], on_tool_call=single_return_handler)
+
+    result = tool_node.invoke(
+        {
+            "messages": [
+                AIMessage(
+                    "adding",
+                    tool_calls=[
+                        {
+                            "name": "add",
+                            "args": {"a": 1, "b": 2},
+                            "id": "call_confused_1",
+                        }
+                    ],
+                )
+            ]
+        }
+    )
+
+    # Should succeed with cached result
+    assert isinstance(result, dict)
+    assert result["messages"][0].content == "cached"
 
 
 def test_handler_can_short_circuit_with_command() -> None:
-    """Test that handler can short-circuit by yielding Command."""
+    """Test that handler can short-circuit by returning Command."""
 
     def command_handler(
-        _request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        _request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that short-circuits with Command."""
         # Short-circuit with Command instead of executing tool
-        yield Command(goto="end")
+        return Command(goto="end")
 
     tool_node = ToolNode([add], on_tool_call=command_handler)
 
@@ -927,90 +935,95 @@ def command_handler(
 
 
 def test_handler_cannot_yield_multiple_commands() -> None:
-    """Test that yielding multiple Commands is rejected."""
-
-    def multi_command_handler(
-        _request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that incorrectly yields multiple Commands."""
-        # First short-circuit
-        yield Command(goto="step1")
-        # Second short-circuit - should fail
-        yield Command(goto="step2")
-
-    tool_node = ToolNode([add], on_tool_call=multi_command_handler)
-
-    with pytest.raises(
-        ValueError,
-        match="on_tool_call handler yielded multiple values after short-circuit",
-    ):
-        tool_node.invoke(
-            {
-                "messages": [
-                    AIMessage(
-                        "adding",
-                        tool_calls=[
-                            {
-                                "name": "add",
-                                "args": {"a": 1, "b": 2},
-                                "id": "call_multicmd_1",
-                            }
-                        ],
-                    )
-                ]
-            }
-        )
+    """Test that handler can only return once (not applicable to handler pattern)."""
+    # With handler pattern, you can only return once
+    # This test is no longer relevant
+
+    def single_command_handler(
+        _request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that returns Command once."""
+        return Command(goto="step1")
+
+    tool_node = ToolNode([add], on_tool_call=single_command_handler)
+
+    result = tool_node.invoke(
+        {
+            "messages": [
+                AIMessage(
+                    "adding",
+                    tool_calls=[
+                        {
+                            "name": "add",
+                            "args": {"a": 1, "b": 2},
+                            "id": "call_multicmd_1",
+                        }
+                    ],
+                )
+            ]
+        }
+    )
+
+    # Should succeed - handlers naturally return once
+    assert isinstance(result, list)
+    assert len(result) == 1
+    assert isinstance(result[0], Command)
+    assert result[0].goto == "step1"
 
 
 def test_handler_cannot_yield_request_after_command() -> None:
-    """Test that yielding ToolCallRequest after Command is rejected."""
-
-    def command_then_request_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
-        """Handler that incorrectly yields request after Command."""
-        # First short-circuit with Command
-        yield Command(goto="somewhere")
-        # Then try to execute - should fail
-        yield request
-
-    tool_node = ToolNode([add], on_tool_call=command_then_request_handler)
-
-    with pytest.raises(
-        ValueError,
-        match="on_tool_call handler yielded ToolCallRequest after short-circuit",
-    ):
-        tool_node.invoke(
-            {
-                "messages": [
-                    AIMessage(
-                        "adding",
-                        tool_calls=[
-                            {
-                                "name": "add",
-                                "args": {"a": 1, "b": 2},
-                                "id": "call_cmdreq_1",
-                            }
-                        ],
-                    )
-                ]
-            }
-        )
+    """Test that handler can only return once (not applicable to handler pattern)."""
+    # With handler pattern, you can only return once
+    # This test is no longer relevant
+
+    def command_handler(
+        _request: ToolCallRequest,
+        _execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
+        """Handler that returns Command."""
+        return Command(goto="somewhere")
+
+    tool_node = ToolNode([add], on_tool_call=command_handler)
+
+    result = tool_node.invoke(
+        {
+            "messages": [
+                AIMessage(
+                    "adding",
+                    tool_calls=[
+                        {
+                            "name": "add",
+                            "args": {"a": 1, "b": 2},
+                            "id": "call_cmdreq_1",
+                        }
+                    ],
+                )
+            ]
+        }
+    )
+
+    # Should succeed with Command
+    assert isinstance(result, list)
+    assert len(result) == 1
+    assert isinstance(result[0], Command)
+    assert result[0].goto == "somewhere"
 
 
 def test_tool_returning_command_sent_to_handler() -> None:
     """Test that when tool returns Command, it's sent to handler."""
     received_commands = []
 
     def command_inspector_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that inspects Command returned by tool."""
-        result = yield request
+        result = execute(request)
         # Should receive Command from tool
         if isinstance(result, Command):
             received_commands.append(result)
-        # Can end here, returning the Command
+        return result
 
     tool_node = ToolNode([command_tool], on_tool_call=command_inspector_handler)
 
@@ -1046,15 +1059,15 @@ def test_handler_can_modify_command_from_tool() -> None:
     """Test that handler can inspect and modify Command from tool."""
 
     def command_modifier_handler(
-        request: ToolCallRequest, _state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that modifies Command returned by tool."""
-        result = yield request
+        result = execute(request)
         # Modify the Command
         if isinstance(result, Command):
-            modified_cmd = Command(goto=f"modified_{result.goto}")
-            yield modified_cmd
-        # Otherwise pass through
+            return Command(goto=f"modified_{result.goto}")
+        return result
 
     tool_node = ToolNode([command_tool], on_tool_call=command_modifier_handler)
 
@@ -1087,11 +1100,12 @@ def test_state_extraction_with_dict_input() -> None:
     state_seen = []
 
     def state_inspector_handler(
-        request: ToolCallRequest, state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that records the state it receives."""
-        state_seen.append(state)
-        yield request
+        state_seen.append(request.state)
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=state_inspector_handler)
 
@@ -1121,11 +1135,12 @@ def test_state_extraction_with_list_input() -> None:
     state_seen = []
 
     def state_inspector_handler(
-        request: ToolCallRequest, state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that records the state it receives."""
-        state_seen.append(state)
-        yield request
+        state_seen.append(request.state)
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=state_inspector_handler)
 
@@ -1154,11 +1169,12 @@ def test_state_extraction_with_tool_call_with_context() -> None:
     state_seen = []
 
     def state_inspector_handler(
-        request: ToolCallRequest, state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that records the state it receives."""
-        state_seen.append(state)
-        yield request
+        state_seen.append(request.state)
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=state_inspector_handler)
 
@@ -1196,11 +1212,12 @@ async def test_state_extraction_with_tool_call_with_context_async() -> None:
     state_seen = []
 
     def state_inspector_handler(
-        request: ToolCallRequest, state: Any, _runtime: Any
-    ) -> Generator[ToolCallRequest | ToolMessage | Command, ToolMessage | Command, None]:
+        request: ToolCallRequest,
+        execute: Callable[[ToolCallRequest], ToolMessage | Command],
+    ) -> ToolMessage | Command:
         """Handler that records the state it receives."""
-        state_seen.append(state)
-        yield request
+        state_seen.append(request.state)
+        return execute(request)
 
     tool_node = ToolNode([add], on_tool_call=state_inspector_handler)
 
EOF_114329324912

# Change to the langchain_v1 package directory as specified in project structure
cd /testbed/libs/langchain_v1

# Set environment variables for test execution
export UV_FROZEN=true
export LANGGRAPH_TEST_FAST=1

# Execute the target test files using uv with pytest
# Running in single-process mode for safety in virtualized environment
# Disabling socket connections as specified in the project's test configuration
uv run --group test pytest \
    tests/unit_tests/agents/test_on_tool_call_middleware.py \
    tests/unit_tests/tools/test_on_tool_call.py \
    --disable-socket --allow-unix-socket \
    -v

# Capture exit code immediately after test execution
rc=$?

# Required: Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: Reset the test files to original state
cd /testbed
git checkout 68c56440cfb95a20c42bfe87f15cdbae16df0876 "libs/langchain_v1/tests/unit_tests/agents/test_on_tool_call_middleware.py" "libs/langchain_v1/tests/unit_tests/tools/test_on_tool_call.py"