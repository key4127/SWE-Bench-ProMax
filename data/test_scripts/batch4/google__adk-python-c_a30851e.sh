#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Ensure we're at the correct commit and checkout target test files
git checkout fe8b37b0d3046a9c0dd90e8ddca2940c28d1a93f "tests/unittests/agents/test_remote_a2a_agent.py" "tests/unittests/flows/llm_flows/test_contents.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/agents/test_remote_a2a_agent.py b/tests/unittests/agents/test_remote_a2a_agent.py
--- a/tests/unittests/agents/test_remote_a2a_agent.py
+++ b/tests/unittests/agents/test_remote_a2a_agent.py
@@ -515,7 +515,7 @@ def test_construct_message_parts_from_session_success(self):
     self.mock_session.events = [mock_event]
 
     with patch(
-        "google.adk.agents.remote_a2a_agent._convert_foreign_event"
+        "google.adk.agents.remote_a2a_agent._present_other_agent_message"
     ) as mock_convert:
       mock_convert.return_value = mock_event
 
@@ -937,7 +937,7 @@ async def test_full_workflow_with_direct_agent_card(self):
 
     # Mock dependencies
     with patch(
-        "google.adk.agents.remote_a2a_agent._convert_foreign_event"
+        "google.adk.agents.remote_a2a_agent._present_other_agent_message"
     ) as mock_convert:
       mock_convert.return_value = mock_event
 
diff --git a/tests/unittests/flows/llm_flows/test_contents.py b/tests/unittests/flows/llm_flows/test_contents.py
--- a/tests/unittests/flows/llm_flows/test_contents.py
+++ b/tests/unittests/flows/llm_flows/test_contents.py
@@ -14,12 +14,10 @@
 
 from google.adk.agents.llm_agent import Agent
 from google.adk.events.event import Event
+from google.adk.events.event_actions import EventActions
 from google.adk.flows.llm_flows import contents
-from google.adk.flows.llm_flows.contents import _convert_foreign_event
-from google.adk.flows.llm_flows.contents import _get_contents
-from google.adk.flows.llm_flows.contents import _merge_function_response_events
-from google.adk.flows.llm_flows.contents import _rearrange_events_for_async_function_responses_in_history
-from google.adk.flows.llm_flows.contents import _rearrange_events_for_latest_function_response
+from google.adk.flows.llm_flows.functions import REQUEST_CONFIRMATION_FUNCTION_CALL_NAME
+from google.adk.flows.llm_flows.functions import REQUEST_EUC_FUNCTION_CALL_NAME
 from google.adk.models.llm_request import LlmRequest
 from google.genai import types
 import pytest
@@ -28,564 +26,347 @@
 
 
 @pytest.mark.asyncio
-async def test_content_processor_no_contents():
-  """Test ContentLlmRequestProcessor when include_contents is 'none'."""
-  agent = Agent(model="gemini-1.5-flash", name="agent", include_contents="none")
-  llm_request = LlmRequest(model="gemini-1.5-flash")
+async def test_include_contents_default_full_history():
+  """Test that include_contents='default' includes full conversation history."""
+  agent = Agent(
+      model="gemini-2.5-flash", name="test_agent", include_contents="default"
+  )
+  llm_request = LlmRequest(model="gemini-2.5-flash")
   invocation_context = await testing_utils.create_invocation_context(
       agent=agent
   )
 
-  # Collect events from async generator
-  events = []
-  async for event in contents.request_processor.run_async(
+  # Create a multi-turn conversation
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("First message"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent("First response"),
+      ),
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent("Second message"),
+      ),
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Second response"),
+      ),
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent("Third message"),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
       invocation_context, llm_request
   ):
-    events.append(event)
+    pass
 
-  # Should not yield any events
-  assert len(events) == 0
-  # Contents should not be set when include_contents is 'none'
-  assert llm_request.contents == []
+  # Verify full conversation history is included
+  assert llm_request.contents == [
+      types.UserContent("First message"),
+      types.ModelContent("First response"),
+      types.UserContent("Second message"),
+      types.ModelContent("Second response"),
+      types.UserContent("Third message"),
+  ]
 
 
 @pytest.mark.asyncio
-async def test_content_processor_with_contents():
-  """Test ContentLlmRequestProcessor when include_contents is not 'none'."""
-  agent = Agent(model="gemini-1.5-flash", name="agent")
-  llm_request = LlmRequest(model="gemini-1.5-flash")
+async def test_include_contents_none_current_turn_only():
+  """Test that include_contents='none' includes only current turn context."""
+  agent = Agent(
+      model="gemini-2.5-flash", name="test_agent", include_contents="none"
+  )
+  llm_request = LlmRequest(model="gemini-2.5-flash")
   invocation_context = await testing_utils.create_invocation_context(
       agent=agent
   )
 
-  # Add some test events to the session
-  test_event = Event(
-      invocation_id="test_inv",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part.from_text(text="Hello")]
+  # Create a multi-turn conversation
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("First message"),
       ),
-  )
-  invocation_context.session.events = [test_event]
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent("First response"),
+      ),
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent("Second message"),
+      ),
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Second response"),
+      ),
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent("Current turn message"),
+      ),
+  ]
+  invocation_context.session.events = events
 
-  # Collect events from async generator
-  events = []
-  async for event in contents.request_processor.run_async(
+  # Process the request
+  async for _ in contents.request_processor.run_async(
       invocation_context, llm_request
   ):
-    events.append(event)
+    pass
 
-  # Should not yield any events (processor doesn't emit events, just modifies request)
-  assert len(events) == 0
-  # Contents should be set
-  assert llm_request.contents is not None
-  assert len(llm_request.contents) == 1
-  assert llm_request.contents[0].role == "user"
-  assert llm_request.contents[0].parts[0].text == "Hello"
+  # Verify only current turn is included (from last user message)
+  assert llm_request.contents == [
+      types.UserContent("Current turn message"),
+  ]
 
 
 @pytest.mark.asyncio
-async def test_content_processor_non_llm_agent():
-  """Test ContentLlmRequestProcessor with non-LLM agent."""
-  from google.adk.agents.base_agent import BaseAgent
-
-  # Create a base agent (not LLM agent)
-  agent = BaseAgent(name="base_agent")
-  llm_request = LlmRequest(model="gemini-1.5-flash")
+async def test_include_contents_none_multi_agent_current_turn():
+  """Test current turn detection in multi-agent scenarios with include_contents='none'."""
+  agent = Agent(
+      model="gemini-2.5-flash", name="current_agent", include_contents="none"
+  )
+  llm_request = LlmRequest(model="gemini-2.5-flash")
   invocation_context = await testing_utils.create_invocation_context(
       agent=agent
   )
 
-  # Collect events from async generator
-  events = []
-  async for event in contents.request_processor.run_async(
-      invocation_context, llm_request
-  ):
-    events.append(event)
-
-  # Should not yield any events and not modify request
-  assert len(events) == 0
-  assert llm_request.contents == []
-
-
-def test_get_contents_empty_events():
-  """Test _get_contents with empty events list."""
-  contents_result = _get_contents(None, [], "test_agent")
-  assert contents_result == []
-
-
-def test_get_contents_with_events():
-  """Test _get_contents with valid events."""
-  test_event = Event(
-      invocation_id="test_inv",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part.from_text(text="Hello")]
+  # Create multi-agent conversation where current turn starts from user
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("First user message"),
       ),
-  )
-
-  contents_result = _get_contents(None, [test_event], "test_agent")
-  assert len(contents_result) == 1
-  assert contents_result[0].role == "user"
-  assert contents_result[0].parts[0].text == "Hello"
-
-
-def test_get_contents_filters_empty_events():
-  """Test _get_contents filters out events with empty content."""
-  # Event with empty text
-  empty_event = Event(
-      invocation_id="test_inv",
-      author="user",
-      content=types.Content(role="user", parts=[types.Part.from_text(text="")]),
-  )
-
-  # Event without content
-  no_content_event = Event(
-      invocation_id="test_inv",
-      author="user",
-  )
-
-  # Valid event
-  valid_event = Event(
-      invocation_id="test_inv",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part.from_text(text="Hello")]
+      Event(
+          invocation_id="inv2",
+          author="other_agent",
+          content=types.ModelContent("Other agent response"),
       ),
-  )
-
-  contents_result = _get_contents(
-      None, [empty_event, no_content_event, valid_event], "test_agent"
-  )
-  assert len(contents_result) == 1
-  assert contents_result[0].role == "user"
-  assert contents_result[0].parts[0].text == "Hello"
-
-
-def test_get_contents_filters_auth_and_confirmation_events():
-  """Test _get_contents filters out auth and request confirmation events."""
-  auth_event = Event(
-      invocation_id="test_inv",
-      author="agent",
-      content=types.Content(
-          role="model",
-          parts=[
-              types.Part(
-                  function_call=types.FunctionCall(
-                      id="auth_func",
-                      name=contents.REQUEST_EUC_FUNCTION_CALL_NAME,
-                      args={},
-                  )
-              )
-          ],
+      Event(
+          invocation_id="inv3",
+          author="current_agent",
+          content=types.ModelContent("Current agent first response"),
       ),
-  )
-
-  confirmation_event = Event(
-      invocation_id="test_inv",
-      author="agent",
-      content=types.Content(
-          role="model",
-          parts=[
-              types.Part(
-                  function_call=types.FunctionResponse(
-                      id="confirm_func",
-                      name=contents.REQUEST_CONFIRMATION_FUNCTION_CALL_NAME,
-                      response={
-                          "confirmed": True,
-                      },
-                  )
-              )
-          ],
+      Event(
+          invocation_id="inv4",
+          author="user",
+          content=types.UserContent("Current turn request"),
       ),
-  )
-
-  valid_event = Event(
-      invocation_id="test_inv",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part.from_text(text="Hello")]
+      Event(
+          invocation_id="inv5",
+          author="another_agent",
+          content=types.ModelContent("Another agent responds"),
       ),
-  )
-
-  contents_result = _get_contents(
-      None, [auth_event, confirmation_event, valid_event], "test_agent"
-  )
-  assert len(contents_result) == 1
-  assert contents_result[0].role == "user"
-  assert contents_result[0].parts[0].text == "Hello"
-
-
-def test_convert_foreign_event():
-  """Test _convert_foreign_event function."""
-  agent_event = Event(
-      invocation_id="test_inv",
-      author="agent1",
-      content=types.Content(
-          role="model", parts=[types.Part.from_text(text="Agent response")]
+      Event(
+          invocation_id="inv6",
+          author="current_agent",
+          content=types.ModelContent("Current agent in turn"),
       ),
-  )
+  ]
+  invocation_context.session.events = events
 
-  converted_event = _convert_foreign_event(agent_event)
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
 
-  assert converted_event.author == "user"
-  assert converted_event.content.role == "user"
-  assert len(converted_event.content.parts) == 2
-  assert converted_event.content.parts[0].text == "For context:"
-  assert (
-      "[agent1] said: Agent response" in converted_event.content.parts[1].text
-  )
+  # Verify current turn starts from the most recent other agent message (inv5)
+  assert len(llm_request.contents) == 2
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[another_agent] said: Another agent responds"),
+  ]
+  assert llm_request.contents[1] == types.ModelContent("Current agent in turn")
 
 
-def test_convert_event_with_function_call():
-  """Test _convert_foreign_event with function call."""
-  function_call = types.FunctionCall(
-      id="func_123", name="test_function", args={"param": "value"}
+@pytest.mark.asyncio
+async def test_authentication_events_are_filtered():
+  """Test that authentication function calls and responses are filtered out."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
   )
 
-  agent_event = Event(
-      invocation_id="test_inv",
-      author="agent1",
-      content=types.Content(
-          role="model", parts=[types.Part(function_call=function_call)]
-      ),
+  # Create authentication function call and response
+  auth_function_call = types.FunctionCall(
+      id="auth_123",
+      name=REQUEST_EUC_FUNCTION_CALL_NAME,
+      args={"credential_type": "oauth"},
   )
-
-  converted_event = _convert_foreign_event(agent_event)
-
-  assert converted_event.author == "user"
-  assert converted_event.content.role == "user"
-  assert len(converted_event.content.parts) == 2
-  assert converted_event.content.parts[0].text == "For context:"
-  assert (
-      "[agent1] called tool `test_function`"
-      in converted_event.content.parts[1].text
+  auth_response = types.FunctionResponse(
+      id="auth_123",
+      name=REQUEST_EUC_FUNCTION_CALL_NAME,
+      response={
+          "auth_config": {"exchanged_auth_credential": {"token": "secret"}}
+      },
   )
-  assert "{'param': 'value'}" in converted_event.content.parts[1].text
 
-
-def test_convert_event_with_function_response():
-  """Test _convert_foreign_event with function response."""
-  function_response = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-
-  agent_event = Event(
-      invocation_id="test_inv",
-      author="agent1",
-      content=types.Content(
-          role="user", parts=[types.Part(function_response=function_response)]
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Please authenticate"),
       ),
-  )
-
-  converted_event = _convert_foreign_event(agent_event)
-
-  assert converted_event.author == "user"
-  assert converted_event.content.role == "user"
-  assert len(converted_event.content.parts) == 2
-  assert converted_event.content.parts[0].text == "For context:"
-  assert (
-      "[agent1] `test_function` tool returned result:"
-      in converted_event.content.parts[1].text
-  )
-  assert "{'result': 'success'}" in converted_event.content.parts[1].text
-
-
-def test_merge_function_response_events():
-  """Test _merge_function_response_events function."""
-  # Create initial function response event
-  function_response1 = types.FunctionResponse(
-      id="func_123", name="test_function", response={"status": "pending"}
-  )
-
-  initial_event = Event(
-      invocation_id="test_inv",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part(function_response=function_response1)]
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent(
+              [types.Part(function_call=auth_function_call)]
+          ),
       ),
-  )
-
-  # Create final function response event
-  function_response2 = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-
-  final_event = Event(
-      invocation_id="test_inv2",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part(function_response=function_response2)]
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.Content(
+              parts=[types.Part(function_response=auth_response)], role="user"
+          ),
       ),
-  )
-
-  merged_event = _merge_function_response_events([initial_event, final_event])
-
-  assert (
-      merged_event.invocation_id == "test_inv"
-  )  # Should keep initial event ID
-  assert len(merged_event.content.parts) == 1
-  # The first part should be replaced with the final response
-  assert merged_event.content.parts[0].function_response.response == {
-      "result": "success"
-  }
-
-
-def test_rearrange_events_for_async_function_responses():
-  """Test _rearrange_events_for_async_function_responses_in_history function."""
-  # Create function call event
-  function_call = types.FunctionCall(
-      id="func_123", name="test_function", args={"param": "value"}
-  )
-
-  call_event = Event(
-      invocation_id="test_inv1",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part(function_call=function_call)]
+      Event(
+          invocation_id="inv4",
+          author="user",
+          content=types.UserContent("Continue after auth"),
       ),
-  )
-
-  # Create function response event
-  function_response = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-
-  response_event = Event(
-      invocation_id="test_inv2",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part(function_response=function_response)]
-      ),
-  )
+  ]
+  invocation_context.session.events = events
 
-  # Test rearrangement
-  events = [call_event, response_event]
-  rearranged = _rearrange_events_for_async_function_responses_in_history(events)
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
 
-  # Should have both events in correct order
-  assert len(rearranged) == 2
-  assert rearranged[0] == call_event
-  assert rearranged[1] == response_event
+  # Verify both authentication call and response are filtered out
+  assert llm_request.contents == [
+      types.UserContent("Please authenticate"),
+      types.UserContent("Continue after auth"),
+  ]
 
 
-def test_rearrange_events_for_latest_function_response():
-  """Test _rearrange_events_for_latest_function_response function."""
-  # Create function call event
-  function_call = types.FunctionCall(
-      id="func_123", name="test_function", args={"param": "value"}
+@pytest.mark.asyncio
+async def test_confirmation_events_are_filtered():
+  """Test that confirmation function calls and responses are filtered out."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
   )
 
-  call_event = Event(
-      invocation_id="test_inv1",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part(function_call=function_call)]
-      ),
+  # Create confirmation function call and response
+  confirmation_function_call = types.FunctionCall(
+      id="confirm_123",
+      name=REQUEST_CONFIRMATION_FUNCTION_CALL_NAME,
+      args={"action": "delete_file", "confirmation": True},
   )
-
-  # Create intermediate event
-  intermediate_event = Event(
-      invocation_id="test_inv2",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part.from_text(text="Processing...")]
-      ),
+  confirmation_response = types.FunctionResponse(
+      id="confirm_123",
+      name=REQUEST_CONFIRMATION_FUNCTION_CALL_NAME,
+      response={"response": '{"confirmed": true}'},
   )
 
-  # Create function response event
-  function_response = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-
-  response_event = Event(
-      invocation_id="test_inv3",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part(function_response=function_response)]
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Delete the file"),
       ),
-  )
-
-  # Test with matching function call and response
-  events = [call_event, intermediate_event, response_event]
-  rearranged = _rearrange_events_for_latest_function_response(events)
-
-  # Should remove intermediate events and merge responses
-  assert len(rearranged) == 2
-  assert rearranged[0] == call_event
-  assert rearranged[1] == response_event
-
-
-def test_rearrange_events_for_latest_function_response_multiple_calls():
-  """Test _rearrange_events_for_latest_function_response with multiple function calls."""
-  # Create function call event with multiple calls
-  function_call1 = types.FunctionCall(
-      id="func_123", name="test_function", args={"param": "value1"}
-  )
-  function_call2 = types.FunctionCall(
-      id="func_456", name="test_function2", args={"param": "value2"}
-  )
-
-  call_event = Event(
-      invocation_id="test_inv1",
-      author="agent",
-      content=types.Content(
-          role="model",
-          parts=[
-              types.Part(function_call=function_call1),
-              types.Part(function_call=function_call2),
-          ],
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent(
+              [types.Part(function_call=confirmation_function_call)]
+          ),
       ),
-  )
-
-  # Create intermediate event
-  intermediate_event = Event(
-      invocation_id="test_inv2",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part.from_text(text="Processing...")]
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.Content(
+              parts=[types.Part(function_response=confirmation_response)],
+              role="user",
+          ),
       ),
-  )
-
-  # Create function response event with only one response
-  function_response = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-
-  response_event = Event(
-      invocation_id="test_inv3",
-      author="user",
-      content=types.Content(
-          role="user", parts=[types.Part(function_response=function_response)]
+      Event(
+          invocation_id="inv4",
+          author="user",
+          content=types.UserContent("File deleted successfully"),
       ),
-  )
-
-  # Test with matching function call and response
-  events = [call_event, intermediate_event, response_event]
-  rearranged = _rearrange_events_for_latest_function_response(events)
+  ]
+  invocation_context.session.events = events
 
-  # Should remove intermediate events and merge responses
-  assert len(rearranged) == 2
-  assert rearranged[0] == call_event
-  assert rearranged[1] == response_event
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
 
+  # Verify both confirmation call and response are filtered out
+  assert llm_request.contents == [
+      types.UserContent("Delete the file"),
+      types.UserContent("File deleted successfully"),
+  ]
 
-def test_rearrange_events_for_latest_function_response_validation_error():
-  """Test _rearrange_events_for_latest_function_response with validation error."""
-  # Create function call event with one function call
-  function_call = types.FunctionCall(
-      id="func_123", name="test_function", args={"param": "value"}
-  )
 
-  call_event = Event(
-      invocation_id="test_inv1",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part(function_call=function_call)]
-      ),
+@pytest.mark.asyncio
+async def test_events_with_empty_content_are_skipped():
+  """Test that events with empty content (state-only changes) are skipped."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
   )
 
-  # Create intermediate event
-  intermediate_event = Event(
-      invocation_id="test_inv2",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part.from_text(text="Processing...")]
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Hello"),
       ),
-  )
-
-  # Create function response event with the matching function call AND an extra one
-  function_response1 = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-  function_response2 = types.FunctionResponse(
-      id="func_456", name="other_function", response={"result": "other"}
-  )
-
-  response_event = Event(
-      invocation_id="test_inv3",
-      author="user",
-      content=types.Content(
-          role="user",
-          parts=[
-              types.Part(function_response=function_response1),
-              types.Part(function_response=function_response2),
-          ],
+      # Event with no content (state-only change)
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          actions=EventActions(state_delta={"key": "val"}),
       ),
-  )
-
-  # Test with mismatched function call and response
-  events = [call_event, intermediate_event, response_event]
-
-  with pytest.raises(
-      ValueError,
-      match=(
-          "Last response event should only contain the responses for the"
-          " function calls in the same function call event"
+      # Event with content that has no meaningful parts
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.Content(parts=[], role="model"),
       ),
-  ):
-    _rearrange_events_for_latest_function_response(events)
-
-
-def test_rearrange_events_for_latest_function_response_mixed_responses():
-  """Test _rearrange_events_for_latest_function_response with mixed function responses."""
-  # Create function call event with two calls
-  function_call1 = types.FunctionCall(
-      id="func_123", name="test_function", args={"param": "value1"}
-  )
-  function_call2 = types.FunctionCall(
-      id="func_456", name="test_function2", args={"param": "value2"}
-  )
-
-  call_event = Event(
-      invocation_id="test_inv1",
-      author="agent",
-      content=types.Content(
-          role="model",
-          parts=[
-              types.Part(function_call=function_call1),
-              types.Part(function_call=function_call2),
-          ],
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent("How are you?"),
       ),
-  )
+  ]
+  invocation_context.session.events = events
 
-  # Create intermediate event
-  intermediate_event = Event(
-      invocation_id="test_inv2",
-      author="agent",
-      content=types.Content(
-          role="model", parts=[types.Part.from_text(text="Processing...")]
-      ),
-  )
-
-  # Create function response event with one matching and one non-matching response
-  function_response1 = types.FunctionResponse(
-      id="func_123", name="test_function", response={"result": "success"}
-  )
-  function_response2 = types.FunctionResponse(
-      id="func_789", name="test_function3", response={"result": "other"}
-  )
-
-  response_event = Event(
-      invocation_id="test_inv3",
-      author="user",
-      content=types.Content(
-          role="user",
-          parts=[
-              types.Part(function_response=function_response1),
-              types.Part(function_response=function_response2),
-          ],
-      ),
-  )
-
-  # Test with mixed function responses
-  events = [call_event, intermediate_event, response_event]
-
-  with pytest.raises(
-      ValueError,
-      match=(
-          "Last response event should only contain the responses for the"
-          " function calls in the same function call event"
-      ),
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
   ):
-    _rearrange_events_for_latest_function_response(events)
+    pass
+
+  # Verify only events with meaningful content are included
+  assert llm_request.contents == [
+      types.UserContent("Hello"),
+      types.UserContent("How are you?"),
+  ]
diff --git a/tests/unittests/flows/llm_flows/test_contents_branch.py b/tests/unittests/flows/llm_flows/test_contents_branch.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/flows/llm_flows/test_contents_branch.py
@@ -0,0 +1,288 @@
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
+"""Tests for branch filtering in contents module.
+
+Branch format: agent_1.agent_2.agent_3 (parent.child.grandchild)
+Child agents can see parent agents' events, but not sibling agents' events.
+"""
+
+from google.adk.agents.llm_agent import Agent
+from google.adk.events.event import Event
+from google.adk.flows.llm_flows.contents import request_processor
+from google.adk.models.llm_request import LlmRequest
+from google.genai import types
+import pytest
+
+from ... import testing_utils
+
+
+@pytest.mark.asyncio
+async def test_branch_filtering_child_sees_parent():
+  """Test that child agents can see parent agents' events."""
+  agent = Agent(model="gemini-2.5-flash", name="child_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Set current branch as child of "parent_agent"
+  invocation_context.branch = "parent_agent.child_agent"
+
+  # Add events from parent and child levels
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("User message"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="parent_agent",
+          content=types.ModelContent("Parent agent response"),
+          branch="parent_agent",  # Parent branch - should be included
+      ),
+      Event(
+          invocation_id="inv3",
+          author="child_agent",
+          content=types.ModelContent("Child agent response"),
+          branch="parent_agent.child_agent",  # Current branch - should be included
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify child can see user message and parent events, but not sibling events
+  assert len(llm_request.contents) == 3
+  assert llm_request.contents[0] == types.UserContent("User message")
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[parent_agent] said: Parent agent response"),
+  ]
+  assert llm_request.contents[2] == types.ModelContent("Child agent response")
+
+
+@pytest.mark.asyncio
+async def test_branch_filtering_excludes_sibling_agents():
+  """Test that sibling agents cannot see each other's events."""
+  agent = Agent(model="gemini-2.5-flash", name="child_agent1")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Set current branch as first child
+  invocation_context.branch = "parent_agent.child_agent1"
+
+  # Add events from parent, current child, and sibling child
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("User message"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="parent_agent",
+          content=types.ModelContent("Parent response"),
+          branch="parent_agent",  # Parent - should be included
+      ),
+      Event(
+          invocation_id="inv3",
+          author="child_agent1",
+          content=types.ModelContent("Child1 response"),
+          branch="parent_agent.child_agent1",  # Current - should be included
+      ),
+      Event(
+          invocation_id="inv4",
+          author="child_agent2",
+          content=types.ModelContent("Sibling response"),
+          branch="parent_agent.child_agent2",  # Sibling - should be excluded
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify sibling events are excluded, but parent and current agent events included
+  assert len(llm_request.contents) == 3
+  assert llm_request.contents[0] == types.UserContent("User message")
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[parent_agent] said: Parent response"),
+  ]
+  assert llm_request.contents[2] == types.ModelContent("Child1 response")
+
+
+@pytest.mark.asyncio
+async def test_branch_filtering_no_branch_allows_all():
+  """Test that events are included when no branches are set."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # No current branch set (None)
+  invocation_context.branch = None
+
+  # Add events with and without branches
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("No branch message"),
+          branch=None,
+      ),
+      Event(
+          invocation_id="inv2",
+          author="agent1",
+          content=types.ModelContent("Agent with branch"),
+          branch="agent1",
+      ),
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent("Another no branch"),
+          branch=None,
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify all events are included when no current branch
+  assert len(llm_request.contents) == 3
+  assert llm_request.contents[0] == types.UserContent("No branch message")
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[agent1] said: Agent with branch"),
+  ]
+  assert llm_request.contents[2] == types.UserContent("Another no branch")
+
+
+@pytest.mark.asyncio
+async def test_branch_filtering_grandchild_sees_grandparent():
+  """Test that deeply nested child agents can see all ancestor events."""
+  agent = Agent(model="gemini-2.5-flash", name="grandchild_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Set deeply nested branch: grandparent.parent.grandchild
+  invocation_context.branch = "grandparent_agent.parent_agent.grandchild_agent"
+
+  # Add events from all levels of hierarchy
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="grandparent_agent",
+          content=types.ModelContent("Grandparent response"),
+          branch="grandparent_agent",
+      ),
+      Event(
+          invocation_id="inv2",
+          author="parent_agent",
+          content=types.ModelContent("Parent response"),
+          branch="grandparent_agent.parent_agent",
+      ),
+      Event(
+          invocation_id="inv3",
+          author="grandchild_agent",
+          content=types.ModelContent("Grandchild response"),
+          branch="grandparent_agent.parent_agent.grandchild_agent",
+      ),
+      Event(
+          invocation_id="inv4",
+          author="sibling_agent",
+          content=types.ModelContent("Sibling response"),
+          branch="grandparent_agent.parent_agent.sibling_agent",
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify only ancestors and current level are included
+  assert len(llm_request.contents) == 3
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[grandparent_agent] said: Grandparent response"),
+  ]
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[parent_agent] said: Parent response"),
+  ]
+  assert llm_request.contents[2] == types.ModelContent("Grandchild response")
+
+
+@pytest.mark.asyncio
+async def test_branch_filtering_parent_cannot_see_child():
+  """Test that parent agents cannot see child agents' events."""
+  agent = Agent(model="gemini-2.5-flash", name="parent_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Set current branch as parent
+  invocation_context.branch = "parent_agent"
+
+  # Add events from parent and its children
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("User message"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="parent_agent",
+          content=types.ModelContent("Parent response"),
+          branch="parent_agent",
+      ),
+      Event(
+          invocation_id="inv3",
+          author="child_agent",
+          content=types.ModelContent("Child response"),
+          branch="parent_agent.child_agent",
+      ),
+      Event(
+          invocation_id="inv4",
+          author="grandchild_agent",
+          content=types.ModelContent("Grandchild response"),
+          branch="parent_agent.child_agent.grandchild_agent",
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify parent cannot see child or grandchild events
+  assert llm_request.contents == [
+      types.UserContent("User message"),
+      types.ModelContent("Parent response"),
+  ]
diff --git a/tests/unittests/flows/llm_flows/test_contents_function.py b/tests/unittests/flows/llm_flows/test_contents_function.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/flows/llm_flows/test_contents_function.py
@@ -0,0 +1,592 @@
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
+"""Tests for function call/response rearrangement in contents module."""
+
+from google.adk.agents.llm_agent import Agent
+from google.adk.events.event import Event
+from google.adk.flows.llm_flows import contents
+from google.adk.models.llm_request import LlmRequest
+from google.genai import types
+import pytest
+
+from ... import testing_utils
+
+
+@pytest.mark.asyncio
+async def test_basic_function_call_response_processing():
+  """Test basic function call/response processing without rearrangement."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  function_call = types.FunctionCall(
+      id="call_123", name="search_tool", args={"query": "test"}
+  )
+  function_response = types.FunctionResponse(
+      id="call_123",
+      name="search_tool",
+      response={"results": ["item1", "item2"]},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Search for test"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent([types.Part(function_call=function_call)]),
+      ),
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=function_response)]
+          ),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
+
+  # Verify no rearrangement occurred
+  assert llm_request.contents == [
+      types.UserContent("Search for test"),
+      types.ModelContent([types.Part(function_call=function_call)]),
+      types.UserContent([types.Part(function_response=function_response)]),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_rearrangement_with_intermediate_function_response():
+  """Test rearrangement when intermediate function response appears after call."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  function_call = types.FunctionCall(
+      id="long_call_123", name="long_running_tool", args={"task": "process"}
+  )
+  # First intermediate response
+  intermediate_response = types.FunctionResponse(
+      id="long_call_123",
+      name="long_running_tool",
+      response={"status": "processing", "progress": 50},
+  )
+  # Final response
+  final_response = types.FunctionResponse(
+      id="long_call_123",
+      name="long_running_tool",
+      response={"status": "completed", "result": "done"},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Run long process"),
+      ),
+      # Function call
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent([types.Part(function_call=function_call)]),
+      ),
+      # Intermediate function response appears right after call
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=intermediate_response)]
+          ),
+      ),
+      # Some conversation happens
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Still processing..."),
+      ),
+      # Final function response (this triggers rearrangement)
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=final_response)]
+          ),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
+
+  # Verify rearrangement: intermediate events removed, final response replaces intermediate
+  assert llm_request.contents == [
+      types.UserContent("Run long process"),
+      types.ModelContent([types.Part(function_call=function_call)]),
+      types.UserContent([types.Part(function_response=final_response)]),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_mixed_long_running_and_normal_function_calls():
+  """Test rearrangement with mixed long-running and normal function calls in same event."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  # Two function calls: one long-running, one normal
+  long_running_call = types.FunctionCall(
+      id="lro_call_456", name="long_running_tool", args={"task": "analyze"}
+  )
+  normal_call = types.FunctionCall(
+      id="normal_call_789", name="search_tool", args={"query": "test"}
+  )
+
+  # Intermediate response for long-running tool
+  lro_intermediate_response = types.FunctionResponse(
+      id="lro_call_456",
+      name="long_running_tool",
+      response={"status": "processing", "progress": 25},
+  )
+  # Response for normal tool (complete)
+  normal_response = types.FunctionResponse(
+      id="normal_call_789",
+      name="search_tool",
+      response={"results": ["item1", "item2"]},
+  )
+  # Final response for long-running tool
+  lro_final_response = types.FunctionResponse(
+      id="lro_call_456",
+      name="long_running_tool",
+      response={"status": "completed", "analysis": "done"},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Analyze data and search for info"),
+      ),
+      # Both function calls in same event
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent([
+              types.Part(function_call=long_running_call),
+              types.Part(function_call=normal_call),
+          ]),
+      ),
+      # Intermediate responses for both tools
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent([
+              types.Part(function_response=lro_intermediate_response),
+              types.Part(function_response=normal_response),
+          ]),
+      ),
+      # Some conversation
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Analysis in progress, search completed"),
+      ),
+      # Final response for long-running tool (triggers rearrangement)
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=lro_final_response)]
+          ),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
+
+  # Verify rearrangement: LRO intermediate replaced by final, normal tool preserved
+  assert llm_request.contents == [
+      types.UserContent("Analyze data and search for info"),
+      types.ModelContent([
+          types.Part(function_call=long_running_call),
+          types.Part(function_call=normal_call),
+      ]),
+      types.UserContent([
+          types.Part(function_response=lro_final_response),
+          types.Part(function_response=normal_response),
+      ]),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_completed_long_running_function_in_history():
+  """Test that completed long-running function calls in history.
+
+  Function call/response are properly rearranged and don't affect subsequent
+  conversation.
+  """
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  function_call = types.FunctionCall(
+      id="history_call_123", name="long_running_tool", args={"task": "process"}
+  )
+  intermediate_response = types.FunctionResponse(
+      id="history_call_123",
+      name="long_running_tool",
+      response={"status": "processing", "progress": 50},
+  )
+  final_response = types.FunctionResponse(
+      id="history_call_123",
+      name="long_running_tool",
+      response={"status": "completed", "result": "done"},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Start long process"),
+      ),
+      # Function call in history
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent([types.Part(function_call=function_call)]),
+      ),
+      # Intermediate response in history
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=intermediate_response)]
+          ),
+      ),
+      # Some conversation happens
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Still processing..."),
+      ),
+      # Final response completes the long-running function in history
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=final_response)]
+          ),
+      ),
+      # Agent acknowledges completion
+      Event(
+          invocation_id="inv6",
+          author="test_agent",
+          content=types.ModelContent("Process completed successfully!"),
+      ),
+      # Latest event is regular user message, not function response
+      Event(
+          invocation_id="inv7",
+          author="user",
+          content=types.UserContent("Great! What's next?"),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
+
+  # Verify the long-running function in history was rearranged correctly:
+  # - Intermediate response was replaced by final response
+  # - Non-function events (like "Still processing...") are preserved
+  # - No further rearrangement occurs since latest event is not function response
+  assert llm_request.contents == [
+      types.UserContent("Start long process"),
+      types.ModelContent([types.Part(function_call=function_call)]),
+      types.UserContent([types.Part(function_response=final_response)]),
+      types.ModelContent("Still processing..."),
+      types.ModelContent("Process completed successfully!"),
+      types.UserContent("Great! What's next?"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_completed_mixed_function_calls_in_history():
+  """Test completed mixed long-running and normal function calls in history don't affect subsequent conversation."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  # Two function calls: one long-running, one normal
+  long_running_call = types.FunctionCall(
+      id="history_lro_123", name="long_running_tool", args={"task": "analyze"}
+  )
+  normal_call = types.FunctionCall(
+      id="history_normal_456", name="search_tool", args={"query": "data"}
+  )
+
+  # Intermediate response for long-running tool
+  lro_intermediate_response = types.FunctionResponse(
+      id="history_lro_123",
+      name="long_running_tool",
+      response={"status": "processing", "progress": 30},
+  )
+  # Complete response for normal tool
+  normal_response = types.FunctionResponse(
+      id="history_normal_456",
+      name="search_tool",
+      response={"results": ["result1", "result2"]},
+  )
+  # Final response for long-running tool
+  lro_final_response = types.FunctionResponse(
+      id="history_lro_123",
+      name="long_running_tool",
+      response={"status": "completed", "analysis": "finished"},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Analyze and search simultaneously"),
+      ),
+      # Both function calls in history
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent([
+              types.Part(function_call=long_running_call),
+              types.Part(function_call=normal_call),
+          ]),
+      ),
+      # Intermediate responses for both tools in history
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent([
+              types.Part(function_response=lro_intermediate_response),
+              types.Part(function_response=normal_response),
+          ]),
+      ),
+      # Some conversation in history
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Analysis continuing, search done"),
+      ),
+      # Final response completes the long-running function in history
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=lro_final_response)]
+          ),
+      ),
+      # Agent acknowledges completion
+      Event(
+          invocation_id="inv6",
+          author="test_agent",
+          content=types.ModelContent("Both tasks completed successfully!"),
+      ),
+      # Latest event is regular user message, not function response
+      Event(
+          invocation_id="inv7",
+          author="user",
+          content=types.UserContent("Perfect! What should we do next?"),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
+
+  # Verify mixed functions in history were rearranged correctly:
+  # - LRO intermediate was replaced by final response
+  # - Normal tool response was preserved
+  # - Non-function events preserved, no further rearrangement
+  assert llm_request.contents == [
+      types.UserContent("Analyze and search simultaneously"),
+      types.ModelContent([
+          types.Part(function_call=long_running_call),
+          types.Part(function_call=normal_call),
+      ]),
+      types.UserContent([
+          types.Part(function_response=lro_final_response),
+          types.Part(function_response=normal_response),
+      ]),
+      types.ModelContent("Analysis continuing, search done"),
+      types.ModelContent("Both tasks completed successfully!"),
+      types.UserContent("Perfect! What should we do next?"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_function_rearrangement_preserves_other_content():
+  """Test that non-function content is preserved during rearrangement."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  function_call = types.FunctionCall(
+      id="preserve_test", name="long_running_tool", args={"test": "value"}
+  )
+  intermediate_response = types.FunctionResponse(
+      id="preserve_test",
+      name="long_running_tool",
+      response={"status": "processing"},
+  )
+  final_response = types.FunctionResponse(
+      id="preserve_test",
+      name="long_running_tool",
+      response={"output": "preserved"},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Before function call"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="test_agent",
+          content=types.ModelContent([
+              types.Part(text="I'll process this for you"),
+              types.Part(function_call=function_call),
+          ]),
+      ),
+      # Intermediate response with mixed content
+      Event(
+          invocation_id="inv3",
+          author="user",
+          content=types.UserContent([
+              types.Part(text="Intermediate prefix"),
+              types.Part(function_response=intermediate_response),
+              types.Part(text="Processing..."),
+          ]),
+      ),
+      # This should be removed during rearrangement
+      Event(
+          invocation_id="inv4",
+          author="test_agent",
+          content=types.ModelContent("Still working on it..."),
+      ),
+      # Final response with mixed content (triggers rearrangement)
+      Event(
+          invocation_id="inv5",
+          author="user",
+          content=types.UserContent([
+              types.Part(text="Final prefix"),
+              types.Part(function_response=final_response),
+              types.Part(text="Final suffix"),
+          ]),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in contents.request_processor.run_async(
+      invocation_context, llm_request
+  ):
+    pass
+
+  # Verify non-function content is preserved during rearrangement
+  # Intermediate response replaced by final, but ALL text content preserved
+  assert llm_request.contents == [
+      types.UserContent("Before function call"),
+      types.ModelContent([
+          types.Part(text="I'll process this for you"),
+          types.Part(function_call=function_call),
+      ]),
+      types.UserContent([
+          types.Part(text="Intermediate prefix"),
+          types.Part(function_response=final_response),
+          types.Part(text="Processing..."),
+          types.Part(text="Final prefix"),
+          types.Part(text="Final suffix"),
+      ]),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_error_when_function_response_without_matching_call():
+  """Test error when function response has no matching function call."""
+  agent = Agent(model="gemini-2.5-flash", name="test_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  # Function response without matching call
+  orphaned_response = types.FunctionResponse(
+      id="no_matching_call",
+      name="orphaned_tool",
+      response={"error": "no matching call"},
+  )
+
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Regular message"),
+      ),
+      # Response without any prior matching function call
+      Event(
+          invocation_id="inv2",
+          author="user",
+          content=types.UserContent(
+              [types.Part(function_response=orphaned_response)]
+          ),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # This should raise a ValueError during processing
+  with pytest.raises(ValueError, match="No function call event found"):
+    async for _ in contents.request_processor.run_async(
+        invocation_context, llm_request
+    ):
+      pass
diff --git a/tests/unittests/flows/llm_flows/test_contents_other_agent.py b/tests/unittests/flows/llm_flows/test_contents_other_agent.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/flows/llm_flows/test_contents_other_agent.py
@@ -0,0 +1,388 @@
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
+"""Behavioral tests for other agent message processing in contents module."""
+
+from google.adk.agents.llm_agent import Agent
+from google.adk.events.event import Event
+from google.adk.flows.llm_flows.contents import request_processor
+from google.adk.models.llm_request import LlmRequest
+from google.genai import types
+import pytest
+
+from ... import testing_utils
+
+
+@pytest.mark.asyncio
+async def test_other_agent_message_appears_as_user_context():
+  """Test that messages from other agents appear as user context."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add event from another agent
+  other_agent_event = Event(
+      invocation_id="test_inv",
+      author="other_agent",
+      content=types.ModelContent("Hello from other agent"),
+  )
+  invocation_context.session.events = [other_agent_event]
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify the other agent's message is presented as user context
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[other_agent] said: Hello from other agent"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_other_agent_thoughts_are_excluded():
+  """Test that thoughts from other agents are excluded from context."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add event from other agent with both regular text and thoughts
+  other_agent_event = Event(
+      invocation_id="test_inv",
+      author="other_agent",
+      content=types.ModelContent([
+          types.Part(text="Public message", thought=False),
+          types.Part(text="Private thought", thought=True),
+          types.Part(text="Another public message"),
+      ]),
+  )
+  invocation_context.session.events = [other_agent_event]
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify only non-thought parts are included (thoughts excluded)
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[other_agent] said: Public message"),
+      types.Part(text="[other_agent] said: Another public message"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_other_agent_function_calls():
+  """Test that function calls from other agents are preserved in context."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add event from other agent with function call
+  function_call = types.FunctionCall(
+      id="func_123", name="search_tool", args={"query": "test query"}
+  )
+  other_agent_event = Event(
+      invocation_id="test_inv",
+      author="other_agent",
+      content=types.ModelContent([types.Part(function_call=function_call)]),
+  )
+  invocation_context.session.events = [other_agent_event]
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify function call is presented as context
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(
+          text="""\
+[other_agent] called tool `search_tool` with parameters: {'query': 'test query'}"""
+      ),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_other_agent_function_responses():
+  """Test that function responses from other agents are properly formatted."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  # Add event from other agent with function response
+  function_response = types.FunctionResponse(
+      id="func_123",
+      name="search_tool",
+      response={"results": ["item1", "item2"]},
+  )
+  other_agent_event = Event(
+      invocation_id="test_inv",
+      author="other_agent",
+      content=types.Content(
+          role="user", parts=[types.Part(function_response=function_response)]
+      ),
+  )
+  invocation_context.session.events = [other_agent_event]
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify function response is presented as context
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(
+          text=(
+              "[other_agent] `search_tool` tool returned result: {'results':"
+              " ['item1', 'item2']}"
+          )
+      ),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_other_agent_function_call_response():
+  """Test function call and response sequence from other agents."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add function call event from other agent
+  function_call = types.FunctionCall(
+      id="func_123", name="calc_tool", args={"query": "6x7"}
+  )
+  call_event = Event(
+      invocation_id="test_inv1",
+      author="other_agent",
+      content=types.ModelContent([
+          types.Part(text="Let me calculate this"),
+          types.Part(function_call=function_call),
+      ]),
+  )
+  # Add function response event
+  function_response = types.FunctionResponse(
+      id="func_123", name="calc_tool", response={"result": 42}
+  )
+  response_event = Event(
+      invocation_id="test_inv2",
+      author="other_agent",
+      content=types.UserContent(
+          parts=[types.Part(function_response=function_response)]
+      ),
+  )
+  invocation_context.session.events = [call_event, response_event]
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify function call and response are properly formatted
+  assert len(llm_request.contents) == 2
+
+  # Function call from other agent
+  assert llm_request.contents[0].role == "user"
+  assert llm_request.contents[0].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[other_agent] said: Let me calculate this"),
+      types.Part(
+          text=(
+              "[other_agent] called tool `calc_tool` with parameters: {'query':"
+              " '6x7'}"
+          )
+      ),
+  ]
+  # Function response from other agent
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(
+          text="[other_agent] `calc_tool` tool returned result: {'result': 42}"
+      ),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_other_agent_empty_content():
+  """Test that other agent messages with only thoughts or empty content are filtered out."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add events: user message, other agents with empty content, user message
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Hello"),
+      ),
+      # Other agent with only thoughts
+      Event(
+          invocation_id="inv2",
+          author="other_agent1",
+          content=types.ModelContent([
+              types.Part(text="This is a private thought", thought=True),
+              types.Part(text="Another private thought", thought=True),
+          ]),
+      ),
+      # Other agent with empty text and thoughts
+      Event(
+          invocation_id="inv3",
+          author="other_agent2",
+          content=types.ModelContent([
+              types.Part(text="", thought=False),
+              types.Part(text="Secret thought", thought=True),
+          ]),
+      ),
+      Event(
+          invocation_id="inv4",
+          author="user",
+          content=types.UserContent("World"),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify empty content events are completely filtered out
+  assert llm_request.contents == [
+      types.UserContent("Hello"),
+      types.UserContent("World"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_multiple_agents_in_conversation():
+  """Test handling multiple agents in a conversation flow."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+
+  # Create a multi-agent conversation
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="user",
+          content=types.UserContent("Hello everyone"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="agent1",
+          content=types.ModelContent("Hi from agent1"),
+      ),
+      Event(
+          invocation_id="inv3",
+          author="agent2",
+          content=types.ModelContent("Hi from agent2"),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify all messages are properly processed
+  assert len(llm_request.contents) == 3
+
+  # User message should remain as user
+  assert llm_request.contents[0] == types.UserContent("Hello everyone")
+  # Other agents' messages should be converted to user context
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[agent1] said: Hi from agent1"),
+  ]
+  assert llm_request.contents[2].role == "user"
+  assert llm_request.contents[2].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[agent2] said: Hi from agent2"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_current_agent_messages_not_converted():
+  """Test that the current agent's own messages are not converted."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add events from both current agent and other agent
+  events = [
+      Event(
+          invocation_id="inv1",
+          author="current_agent",
+          content=types.ModelContent("My own message"),
+      ),
+      Event(
+          invocation_id="inv2",
+          author="other_agent",
+          content=types.ModelContent("Other agent message"),
+      ),
+  ]
+  invocation_context.session.events = events
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify current agent's message stays as model role
+  # and other agent's message is converted to user context
+  assert len(llm_request.contents) == 2
+  assert llm_request.contents[0] == types.ModelContent("My own message")
+  assert llm_request.contents[1].role == "user"
+  assert llm_request.contents[1].parts == [
+      types.Part(text="For context:"),
+      types.Part(text="[other_agent] said: Other agent message"),
+  ]
+
+
+@pytest.mark.asyncio
+async def test_user_messages_preserved():
+  """Test that user messages are preserved as-is."""
+  agent = Agent(model="gemini-2.5-flash", name="current_agent")
+  llm_request = LlmRequest(model="gemini-2.5-flash")
+  invocation_context = await testing_utils.create_invocation_context(
+      agent=agent
+  )
+  # Add user message
+  user_event = Event(
+      invocation_id="inv1",
+      author="user",
+      content=types.UserContent("User message"),
+  )
+  invocation_context.session.events = [user_event]
+
+  # Process the request
+  async for _ in request_processor.run_async(invocation_context, llm_request):
+    pass
+
+  # Verify user message is preserved exactly
+  assert len(llm_request.contents) == 1
+  assert llm_request.contents[0] == types.UserContent("User message")
EOF_114329324912

# Execute the target test files using pytest
# Running in single-process mode for safety in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider \
    tests/unittests/agents/test_remote_a2a_agent.py \
    tests/unittests/flows/llm_flows/test_contents.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore to clean state
git checkout fe8b37b0d3046a9c0dd90e8ddca2940c28d1a93f "tests/unittests/agents/test_remote_a2a_agent.py" "tests/unittests/flows/llm_flows/test_contents.py"