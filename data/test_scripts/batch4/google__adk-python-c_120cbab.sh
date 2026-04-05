#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 29cd183aa1b47dc4f5d8afe22f410f8546634abc "tests/unittests/flows/llm_flows/test_functions_simple.py" "tests/unittests/test_runners.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/flows/llm_flows/test_functions_simple.py b/tests/unittests/flows/llm_flows/test_functions_simple.py
--- a/tests/unittests/flows/llm_flows/test_functions_simple.py
+++ b/tests/unittests/flows/llm_flows/test_functions_simple.py
@@ -17,6 +17,9 @@
 from typing import Callable
 
 from google.adk.agents import Agent
+from google.adk.events.event import Event
+from google.adk.flows.llm_flows.functions import find_matching_function_call
+from google.adk.sessions.session import Session
 from google.adk.tools import ToolContext
 from google.adk.tools.function_tool import FunctionTool
 from google.genai import types
@@ -256,3 +259,136 @@ def increase_by_one(x: int) -> int:
           assert part.function_response.id is None
   assert events[0].content.parts[0].function_call.id.startswith('adk-')
   assert events[1].content.parts[0].function_response.id.startswith('adk-')
+
+
+def test_find_function_call_event_no_function_response_in_last_event():
+  """Test when last event has no function response."""
+  events = [
+      Event(
+          invocation_id='inv1',
+          author='user',
+          content=types.Content(role='user', parts=[types.Part(text='Hello')]),
+      )
+  ]
+
+  result = find_matching_function_call(events)
+  assert result is None
+
+
+def test_find_function_call_event_empty_session_events():
+  """Test when session has no events."""
+  events = []
+
+  result = find_matching_function_call(events)
+  assert result is None
+
+
+def test_find_function_call_event_function_response_but_no_matching_call():
+  """Test when last event has function response but no matching call found."""
+  # Create a function response
+  function_response = types.FunctionResponse(
+      id='func_123', name='test_func', response={}
+  )
+
+  events = [
+      Event(
+          invocation_id='inv1',
+          author='agent1',
+          content=types.Content(
+              role='model',
+              parts=[types.Part(text='Some other response')],
+          ),
+      ),
+      Event(
+          invocation_id='inv2',
+          author='user',
+          content=types.Content(
+              role='user',
+              parts=[types.Part(function_response=function_response)],
+          ),
+      ),
+  ]
+
+  result = find_matching_function_call(events)
+  assert result is None
+
+
+def test_find_function_call_event_function_response_with_matching_call():
+  """Test when last event has function response with matching function call."""
+  # Create a function call
+  function_call = types.FunctionCall(id='func_123', name='test_func', args={})
+
+  # Create a function response with matching ID
+  function_response = types.FunctionResponse(
+      id='func_123', name='test_func', response={}
+  )
+
+  call_event = Event(
+      invocation_id='inv1',
+      author='agent1',
+      content=types.Content(
+          role='model', parts=[types.Part(function_call=function_call)]
+      ),
+  )
+
+  response_event = Event(
+      invocation_id='inv2',
+      author='user',
+      content=types.Content(
+          role='user', parts=[types.Part(function_response=function_response)]
+      ),
+  )
+
+  events = [call_event, response_event]
+
+  result = find_matching_function_call(events)
+  assert result == call_event
+
+
+def test_find_function_call_event_multiple_function_responses():
+  """Test when last event has multiple function responses."""
+  # Create function calls
+  function_call1 = types.FunctionCall(id='func_123', name='test_func1', args={})
+  function_call2 = types.FunctionCall(id='func_456', name='test_func2', args={})
+
+  # Create function responses
+  function_response1 = types.FunctionResponse(
+      id='func_123', name='test_func1', response={}
+  )
+  function_response2 = types.FunctionResponse(
+      id='func_456', name='test_func2', response={}
+  )
+
+  call_event1 = Event(
+      invocation_id='inv1',
+      author='agent1',
+      content=types.Content(
+          role='model', parts=[types.Part(function_call=function_call1)]
+      ),
+  )
+
+  call_event2 = Event(
+      invocation_id='inv2',
+      author='agent2',
+      content=types.Content(
+          role='model', parts=[types.Part(function_call=function_call2)]
+      ),
+  )
+
+  response_event = Event(
+      invocation_id='inv3',
+      author='user',
+      content=types.Content(
+          role='user',
+          parts=[
+              types.Part(function_response=function_response1),
+              types.Part(function_response=function_response2),
+          ],
+      ),
+  )
+
+  events = [call_event1, call_event2, response_event]
+
+  # Should return the first matching function call event found
+  result = find_matching_function_call(events)
+  assert result == call_event1  # First match (func_123)
diff --git a/tests/unittests/test_runners.py b/tests/unittests/test_runners.py
--- a/tests/unittests/test_runners.py
+++ b/tests/unittests/test_runners.py
@@ -18,7 +18,6 @@
 from google.adk.agents.llm_agent import LlmAgent
 from google.adk.artifacts.in_memory_artifact_service import InMemoryArtifactService
 from google.adk.events.event import Event
-from google.adk.runners import _find_function_call_event_if_last_event_is_function_response
 from google.adk.runners import Runner
 from google.adk.sessions.in_memory_session_service import InMemorySessionService
 from google.adk.sessions.session import Session
@@ -73,176 +72,6 @@ async def _run_async_impl(self, invocation_context):
     )
 
 
-class TestFindFunctionCallEventIfLastEventIsFunctionResponse:
-  """Tests for _find_function_call_event_if_last_event_is_function_response function."""
-
-  def test_no_function_response_in_last_event(self):
-    """Test when last event has no function response."""
-    session = Session(
-        id="test_session",
-        user_id="test_user",
-        app_name="test_app",
-        events=[
-            Event(
-                invocation_id="inv1",
-                author="user",
-                content=types.Content(
-                    role="user", parts=[types.Part(text="Hello")]
-                ),
-            )
-        ],
-    )
-
-    result = _find_function_call_event_if_last_event_is_function_response(
-        session
-    )
-    assert result is None
-
-  def test_empty_session_events(self):
-    """Test when session has no events."""
-    session = Session(
-        id="test_session", user_id="test_user", app_name="test_app", events=[]
-    )
-
-    result = _find_function_call_event_if_last_event_is_function_response(
-        session
-    )
-    assert result is None
-
-  def test_last_event_has_function_response_but_no_matching_call(self):
-    """Test when last event has function response but no matching call found."""
-    # Create a function response
-    function_response = types.FunctionResponse(
-        id="func_123", name="test_func", response={}
-    )
-
-    session = Session(
-        id="test_session",
-        user_id="test_user",
-        app_name="test_app",
-        events=[
-            Event(
-                invocation_id="inv1",
-                author="agent1",
-                content=types.Content(
-                    role="model",
-                    parts=[types.Part(text="Some other response")],
-                ),
-            ),
-            Event(
-                invocation_id="inv2",
-                author="user",
-                content=types.Content(
-                    role="user",
-                    parts=[types.Part(function_response=function_response)],
-                ),
-            ),
-        ],
-    )
-
-    result = _find_function_call_event_if_last_event_is_function_response(
-        session
-    )
-    assert result is None
-
-  def test_last_event_has_function_response_with_matching_call(self):
-    """Test when last event has function response with matching function call."""
-    # Create a function call
-    function_call = types.FunctionCall(id="func_123", name="test_func", args={})
-
-    # Create a function response with matching ID
-    function_response = types.FunctionResponse(
-        id="func_123", name="test_func", response={}
-    )
-
-    call_event = Event(
-        invocation_id="inv1",
-        author="agent1",
-        content=types.Content(
-            role="model", parts=[types.Part(function_call=function_call)]
-        ),
-    )
-
-    response_event = Event(
-        invocation_id="inv2",
-        author="user",
-        content=types.Content(
-            role="user", parts=[types.Part(function_response=function_response)]
-        ),
-    )
-
-    session = Session(
-        id="test_session",
-        user_id="test_user",
-        app_name="test_app",
-        events=[call_event, response_event],
-    )
-
-    result = _find_function_call_event_if_last_event_is_function_response(
-        session
-    )
-    assert result == call_event
-
-  def test_last_event_has_multiple_function_responses(self):
-    """Test when last event has multiple function responses."""
-    # Create function calls
-    function_call1 = types.FunctionCall(
-        id="func_123", name="test_func1", args={}
-    )
-    function_call2 = types.FunctionCall(
-        id="func_456", name="test_func2", args={}
-    )
-
-    # Create function responses
-    function_response1 = types.FunctionResponse(
-        id="func_123", name="test_func1", response={}
-    )
-    function_response2 = types.FunctionResponse(
-        id="func_456", name="test_func2", response={}
-    )
-
-    call_event1 = Event(
-        invocation_id="inv1",
-        author="agent1",
-        content=types.Content(
-            role="model", parts=[types.Part(function_call=function_call1)]
-        ),
-    )
-
-    call_event2 = Event(
-        invocation_id="inv2",
-        author="agent2",
-        content=types.Content(
-            role="model", parts=[types.Part(function_call=function_call2)]
-        ),
-    )
-
-    response_event = Event(
-        invocation_id="inv3",
-        author="user",
-        content=types.Content(
-            role="user",
-            parts=[
-                types.Part(function_response=function_response1),
-                types.Part(function_response=function_response2),
-            ],
-        ),
-    )
-
-    session = Session(
-        id="test_session",
-        user_id="test_user",
-        app_name="test_app",
-        events=[call_event1, call_event2, response_event],
-    )
-
-    # Should return the first matching function call event found
-    result = _find_function_call_event_if_last_event_is_function_response(
-        session
-    )
-    assert result == call_event1  # First match (func_123)
-
-
 class TestRunnerFindAgentToRun:
   """Tests for Runner._find_agent_to_run method."""
 
EOF_114329324912

# Run the target test files
# Using single-process mode for stability in virtualized environment
# --no-header: cleaner output
# -rA: show summary of all test outcomes
# --tb=short: shorter traceback format for better readability
# -p no:cacheprovider: disable cache for clean test execution
pytest --no-header -rA --tb=short -p no:cacheprovider tests/unittests/flows/llm_flows/test_functions_simple.py tests/unittests/test_runners.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test files to their original state
git checkout 29cd183aa1b47dc4f5d8afe22f410f8546634abc "tests/unittests/flows/llm_flows/test_functions_simple.py" "tests/unittests/test_runners.py"