#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit and test files
git checkout 34bed359a6b060034099203393e6fd0777e4edc5 "tests/agents/test_agent_reasoning.py" "tests/memory/test_short_term_memory.py" "tests/test_llm.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/agents/test_agent_reasoning.py b/tests/agents/test_agent_reasoning.py
--- a/tests/agents/test_agent_reasoning.py
+++ b/tests/agents/test_agent_reasoning.py
@@ -1,11 +1,11 @@
 """Tests for reasoning in agents."""
 
 import json
+
 import pytest
 
 from crewai import Agent, Task
 from crewai.llm import LLM
-from crewai.utilities.reasoning_handler import AgentReasoning
 
 
 @pytest.fixture
@@ -79,10 +79,8 @@ def mock_llm_call(messages, *args, **kwargs):
             call_count[0] += 1
             if call_count[0] == 1:
                 return mock_llm_responses["not_ready"]
-            else:
-                return mock_llm_responses["ready_after_refine"]
-        else:
-            return "2x"
+            return mock_llm_responses["ready_after_refine"]
+        return "2x"
 
     agent.llm.call = mock_llm_call
 
@@ -121,8 +119,7 @@ def mock_llm_call(messages, *args, **kwargs):
         ) or any("refine your plan" in msg.get("content", "") for msg in messages):
             call_count[0] += 1
             return f"Attempt {call_count[0]}: I need more time to think.\n\nNOT READY: I need to refine my plan further."
-        else:
-            return "This is an unsolved problem in mathematics."
+        return "This is an unsolved problem in mathematics."
 
     agent.llm.call = mock_llm_call
 
@@ -135,26 +132,6 @@ def mock_llm_call(messages, *args, **kwargs):
     assert "Reasoning Plan:" in task.description
 
 
-def test_agent_reasoning_input_validation():
-    """Test input validation in AgentReasoning."""
-    llm = LLM("gpt-3.5-turbo")
-
-    agent = Agent(
-        role="Test Agent",
-        goal="To test the reasoning feature",
-        backstory="I am a test agent created to verify the reasoning feature works correctly.",
-        llm=llm,
-        reasoning=True,
-    )
-
-    with pytest.raises(ValueError, match="Both task and agent must be provided"):
-        AgentReasoning(task=None, agent=agent)
-
-    task = Task(description="Simple task", expected_output="Simple output")
-    with pytest.raises(ValueError, match="Both task and agent must be provided"):
-        AgentReasoning(task=task, agent=None)
-
-
 def test_agent_reasoning_error_handling():
     """Test error handling during the reasoning process."""
     llm = LLM("gpt-3.5-turbo")
@@ -215,8 +192,7 @@ def mock_function_call(messages, *args, **kwargs):
             return json.dumps(
                 {"plan": "I'll solve this simple math problem: 2+2=4.", "ready": True}
             )
-        else:
-            return "4"
+        return "4"
 
     agent.llm.call = mock_function_call
 
@@ -251,8 +227,7 @@ def test_agent_with_function_calling_fallback():
     def mock_function_call(messages, *args, **kwargs):
         if "tools" in kwargs:
             return "Invalid JSON that will trigger fallback. READY: I am ready to execute the task."
-        else:
-            return "4"
+        return "4"
 
     agent.llm.call = mock_function_call
 
diff --git a/tests/memory/test_short_term_memory.py b/tests/memory/test_short_term_memory.py
--- a/tests/memory/test_short_term_memory.py
+++ b/tests/memory/test_short_term_memory.py
@@ -39,7 +39,7 @@ def short_term_memory():
 def test_short_term_memory_search_events(short_term_memory):
     events = defaultdict(list)
 
-    with patch("crewai.rag.chromadb.client.ChromaDBClient.search", return_value=[]):
+    with patch.object(short_term_memory.storage, "search", return_value=[]):
         with crewai_event_bus.scoped_handlers():
 
             @crewai_event_bus.on(MemoryQueryStartedEvent)
diff --git a/tests/test_llm.py b/tests/test_llm.py
--- a/tests/test_llm.py
+++ b/tests/test_llm.py
@@ -7,15 +7,14 @@
 from pydantic import BaseModel
 
 from crewai.agents.agent_builder.utilities.base_token_process import TokenProcess
-from crewai.llm import CONTEXT_WINDOW_USAGE_RATIO, LLM
 from crewai.events.event_types import (
     LLMCallCompletedEvent,
     LLMStreamChunkEvent,
-    ToolUsageStartedEvent,
-    ToolUsageFinishedEvent,
     ToolUsageErrorEvent,
+    ToolUsageFinishedEvent,
+    ToolUsageStartedEvent,
 )
-
+from crewai.llm import CONTEXT_WINDOW_USAGE_RATIO, LLM
 from crewai.utilities.token_counter_callback import TokenCalcHandler
 
 
@@ -376,11 +375,11 @@ def get_weather_tool_schema():
 
 
 def test_context_window_exceeded_error_handling():
-    """Test that litellm.ContextWindowExceededError is converted to LLMContextLengthExceededException."""
+    """Test that litellm.ContextWindowExceededError is converted to LLMContextLengthExceededError."""
     from litellm.exceptions import ContextWindowExceededError
 
     from crewai.utilities.exceptions.context_window_exceeding_exception import (
-        LLMContextLengthExceededException,
+        LLMContextLengthExceededError,
     )
 
     llm = LLM(model="gpt-4")
@@ -393,7 +392,7 @@ def test_context_window_exceeded_error_handling():
             llm_provider="openai",
         )
 
-        with pytest.raises(LLMContextLengthExceededException) as excinfo:
+        with pytest.raises(LLMContextLengthExceededError) as excinfo:
             llm.call("This is a test message")
 
         assert "context length exceeded" in str(excinfo.value).lower()
@@ -408,7 +407,7 @@ def test_context_window_exceeded_error_handling():
             llm_provider="openai",
         )
 
-        with pytest.raises(LLMContextLengthExceededException) as excinfo:
+        with pytest.raises(LLMContextLengthExceededError) as excinfo:
             llm.call("This is a test message")
 
         assert "context length exceeded" in str(excinfo.value).lower()
EOF_114329324912

# Set environment variables for testing
export OPENAI_API_KEY=fake-api-key
export PYTHONUNBUFFERED=1
export OTEL_SDK_DISABLED=true

# Run target tests using uv (single process for stability)
uv run pytest tests/agents/test_agent_reasoning.py tests/memory/test_short_term_memory.py tests/test_llm.py -vv --timeout=30 --maxfail=3
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes
git checkout 34bed359a6b060034099203393e6fd0777e4edc5 "tests/agents/test_agent_reasoning.py" "tests/memory/test_short_term_memory.py" "tests/test_llm.py"