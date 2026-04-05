#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout e229ef4e1995221873a46ab7adb2e052923579a1 \
    "lib/crewai/tests/agents/agent_adapters/test_base_agent_adapter.py" \
    "lib/crewai/tests/agents/test_agent.py" \
    "lib/crewai/tests/agents/test_lite_agent.py" \
    "lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[save].yaml" \
    "lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[search].yaml" \
    "lib/crewai/tests/cassettes/test_crew_train_success.yaml" \
    "lib/crewai/tests/cassettes/test_json_property_without_output_json.yaml" \
    "lib/crewai/tests/cassettes/test_long_term_memory_with_memory_flag.yaml" \
    "lib/crewai/tests/cassettes/test_memory_events_are_emitted.yaml" \
    "lib/crewai/tests/cassettes/test_output_pydantic_hierarchical.yaml" \
    "lib/crewai/tests/cassettes/test_output_pydantic_sequential.yaml" \
    "lib/crewai/tests/cassettes/test_output_pydantic_to_another_task.yaml" \
    "lib/crewai/tests/cassettes/test_save_task_pydantic_output.yaml" \
    "lib/crewai/tests/cassettes/test_using_contextual_memory.yaml" \
    "lib/crewai/tests/cli/test_token_manager.py" \
    "lib/crewai/tests/conftest.py" \
    "lib/crewai/tests/llms/openai/test_openai.py" \
    "lib/crewai/tests/test_crew.py" \
    "lib/crewai/tests/test_custom_llm.py" \
    "lib/crewai/tests/test_task.py" \
    "lib/crewai/tests/tracing/test_tracing.py" \
    "lib/crewai/tests/utilities/cassettes/test_convert_with_instructions.yaml" \
    "lib/crewai/tests/utilities/cassettes/test_converter_with_nested_model.yaml" \
    "lib/crewai/tests/utilities/test_converter.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/crewai/tests/agents/agent_adapters/test_base_agent_adapter.py b/lib/crewai/tests/agents/agent_adapters/test_base_agent_adapter.py
--- a/lib/crewai/tests/agents/agent_adapters/test_base_agent_adapter.py
+++ b/lib/crewai/tests/agents/agent_adapters/test_base_agent_adapter.py
@@ -1,10 +1,10 @@
 from typing import Any
 
 import pytest
-from crewai.agent import BaseAgent
+from crewai.agents.agent_builder.base_agent import BaseAgent
 from crewai.agents.agent_adapters.base_agent_adapter import BaseAgentAdapter
 from crewai.tools.base_tool import BaseTool
-from crewai.utilities.token_counter_callback import TokenProcess
+from crewai.agents.agent_builder.utilities.base_token_process import TokenProcess
 from pydantic import BaseModel
 
 
diff --git a/lib/crewai/tests/agents/test_agent.py b/lib/crewai/tests/agents/test_agent.py
--- a/lib/crewai/tests/agents/test_agent.py
+++ b/lib/crewai/tests/agents/test_agent.py
@@ -1342,7 +1342,7 @@ def test_ensure_first_task_allow_crewai_trigger_context_is_false_does_not_inject
     assert "Trigger Payload: Context data" in second_prompt
 
 
-@patch("crewai.agent.CrewTrainingHandler")
+@patch("crewai.agent.core.CrewTrainingHandler")
 def test_agent_training_handler(crew_training_handler):
     task_prompt = "What is 1 + 1?"
     agent = Agent(
@@ -1351,7 +1351,7 @@ def test_agent_training_handler(crew_training_handler):
         backstory="test backstory",
         verbose=True,
     )
-    crew_training_handler().load.return_value = {
+    crew_training_handler.return_value.load.return_value = {
         f"{agent.id!s}": {"0": {"human_feedback": "good"}}
     }
 
@@ -1360,11 +1360,11 @@ def test_agent_training_handler(crew_training_handler):
     assert result == "What is 1 + 1?\n\nYou MUST follow these instructions: \n good"
 
     crew_training_handler.assert_has_calls(
-        [mock.call(), mock.call("training_data.pkl"), mock.call().load()]
+        [mock.call("training_data.pkl"), mock.call().load()]
     )
 
 
-@patch("crewai.agent.CrewTrainingHandler")
+@patch("crewai.agent.core.CrewTrainingHandler")
 def test_agent_use_trained_data(crew_training_handler):
     task_prompt = "What is 1 + 1?"
     agent = Agent(
@@ -1373,7 +1373,7 @@ def test_agent_use_trained_data(crew_training_handler):
         backstory="test backstory",
         verbose=True,
     )
-    crew_training_handler().load.return_value = {
+    crew_training_handler.return_value.load.return_value = {
         agent.role: {
             "suggestions": [
                 "The result of the math operation must be right.",
@@ -1389,7 +1389,7 @@ def test_agent_use_trained_data(crew_training_handler):
         " - The result of the math operation must be right.\n - Result must be better than 1."
     )
     crew_training_handler.assert_has_calls(
-        [mock.call(), mock.call("trained_agents_data.pkl"), mock.call().load()]
+        [mock.call("trained_agents_data.pkl"), mock.call().load()]
     )
 
 
diff --git a/lib/crewai/tests/agents/test_agent_a2a_wrapping.py b/lib/crewai/tests/agents/test_agent_a2a_wrapping.py
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/agents/test_agent_a2a_wrapping.py
@@ -0,0 +1,111 @@
+"""Test A2A wrapper is only applied when a2a is passed to Agent."""
+
+from unittest.mock import patch
+
+import pytest
+
+from crewai import Agent
+from crewai.a2a.config import A2AConfig
+
+try:
+    import a2a  # noqa: F401
+
+    A2A_SDK_INSTALLED = True
+except ImportError:
+    A2A_SDK_INSTALLED = False
+
+
+def test_agent_without_a2a_has_no_wrapper():
+    """Verify that agents without a2a don't get the wrapper applied."""
+    agent = Agent(
+        role="test role",
+        goal="test goal",
+        backstory="test backstory",
+    )
+
+    assert agent.a2a is None
+    assert callable(agent.execute_task)
+
+
+@pytest.mark.skipif(
+    True,
+    reason="Requires a2a-sdk to be installed. This test verifies wrapper is applied when a2a is set.",
+)
+def test_agent_with_a2a_has_wrapper():
+    """Verify that agents with a2a get the wrapper applied."""
+    a2a_config = A2AConfig(
+        endpoint="http://test-endpoint.com",
+    )
+
+    agent = Agent(
+        role="test role",
+        goal="test goal",
+        backstory="test backstory",
+        a2a=a2a_config,
+    )
+
+    assert agent.a2a is not None
+    assert agent.a2a.endpoint == "http://test-endpoint.com"
+    assert callable(agent.execute_task)
+
+
+@pytest.mark.skipif(not A2A_SDK_INSTALLED, reason="Requires a2a-sdk to be installed")
+def test_agent_with_a2a_creates_successfully():
+    """Verify that creating an agent with a2a succeeds and applies wrapper."""
+    a2a_config = A2AConfig(
+        endpoint="http://test-endpoint.com",
+    )
+
+    agent = Agent(
+        role="test role",
+        goal="test goal",
+        backstory="test backstory",
+        a2a=a2a_config,
+    )
+
+    assert agent.a2a is not None
+    assert agent.a2a.endpoint == "http://test-endpoint.com/"
+    assert callable(agent.execute_task)
+    assert hasattr(agent.execute_task, "__wrapped__")
+
+
+def test_multiple_agents_without_a2a():
+    """Verify that multiple agents without a2a work correctly."""
+    agent1 = Agent(
+        role="agent 1",
+        goal="test goal",
+        backstory="test backstory",
+    )
+
+    agent2 = Agent(
+        role="agent 2",
+        goal="test goal",
+        backstory="test backstory",
+    )
+
+    assert agent1.a2a is None
+    assert agent2.a2a is None
+    assert callable(agent1.execute_task)
+    assert callable(agent2.execute_task)
+
+
+@pytest.mark.skipif(not A2A_SDK_INSTALLED, reason="Requires a2a-sdk to be installed")
+def test_wrapper_is_applied_differently_per_instance():
+    """Verify that agents with and without a2a have different execute_task methods."""
+    agent_without_a2a = Agent(
+        role="agent without a2a",
+        goal="test goal",
+        backstory="test backstory",
+    )
+
+    a2a_config = A2AConfig(endpoint="http://test-endpoint.com")
+    agent_with_a2a = Agent(
+        role="agent with a2a",
+        goal="test goal",
+        backstory="test backstory",
+        a2a=a2a_config,
+    )
+
+    assert agent_without_a2a.execute_task.__func__ is not agent_with_a2a.execute_task.__func__
+    assert not hasattr(agent_without_a2a.execute_task, "__wrapped__")
+    assert hasattr(agent_with_a2a.execute_task, "__wrapped__")
diff --git a/lib/crewai/tests/agents/test_lite_agent.py b/lib/crewai/tests/agents/test_lite_agent.py
--- a/lib/crewai/tests/agents/test_lite_agent.py
+++ b/lib/crewai/tests/agents/test_lite_agent.py
@@ -103,7 +103,7 @@ def __init__(self, **kwargs):
             super().__init__(**kwargs)
 
     # Patch the LiteAgent class
-    monkeypatch.setattr("crewai.agent.LiteAgent", MockLiteAgent)
+    monkeypatch.setattr("crewai.agent.core.LiteAgent", MockLiteAgent)
 
     # Call kickoff to create the LiteAgent
     agent.kickoff("Test query")
@@ -123,8 +123,6 @@ def __init__(self, **kwargs):
     assert created_lite_agent["response_format"] is None
 
     # Test with a response_format
-    monkeypatch.setattr("crewai.agent.LiteAgent", MockLiteAgent)
-
     class TestResponse(BaseModel):
         test_field: str
 
@@ -527,6 +525,7 @@ def call(
             available_functions=None,
             from_task=None,
             from_agent=None,
+            response_model=None,
         ) -> str:
             self.call_count += 1
 
diff --git a/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[save].yaml b/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[save].yaml
--- a/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[save].yaml
+++ b/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[save].yaml
@@ -1285,4 +1285,312 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nPerform
+      a search on specific topics.\n\nExpected Output:\nA list of relevant URLs based
+      on the search query.\n\nActual Output:\nI now can give a great answer. \n\nFinal
+      Answer: Here are some relevant URLs based on your search query. Please visit
+      the following links for comprehensive information on the specified topics:\n\n1.
+      **Artificial Intelligence Ethics**\n   - https://www.aaai.org/Ethics/AIEthics.pdf\n   -
+      https://plato.stanford.edu/entries/ethics-ai/\n\n2. **Impact of 5G Technology**\n   -
+      https://www.itu.int/en/ITU-T/focusgroups/5g/Documents/FG-5G-DOC-1830.zip\n   -
+      https://www.gsma.com/5g/\n\n3. **Quantum Computing Developments**\n   - https://www.ibm.com/quantum-computing/\n   -
+      https://www.microsoft.com/en-us/quantum\n\n4. **Cybersecurity Trends 2023**\n   -
+      https://www.csoonline.com/article/3642552/cybersecurity-trends-2023.html\n   -
+      https://www.forbes.com/sites/bernardmarr/2023/01/03/top-5-cybersecurity-trends-in-2023/\n\n5.
+      **Sustainable Technology Innovations**\n   - https://www.weforum.org/agenda/2023/01/10-innovations-sustainability/\n   -
+      https://www.greenbiz.com/article/13-sustainable-tech-solutions-watch-2023\n\nFeel
+      free to explore these URLs for detailed content on each topic.\n\nPlease provide:\n-
+      Bullet points suggestions to improve future similar tasks\n- A score from 0
+      to 10 evaluating on completion, quality, and overall performance- Entities extracted
+      from the task output, if any, their type, description, and relationships"}],"model":"gpt-4.1-mini"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '1741'
+      content-type:
+      - application/json
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        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
+        AAD//wMAyfZbKYgOAAA=
+    headers:
+      CF-RAY:
+      - 996fcec5ed410df7-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:44:05 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=A3QgDjhHusi3NstcRRXwQT2i7SMfD0OcenI1BlEy_v4-1761878645-1.0.1.1-_WmHHgBT0.tfSicqDzwM4WLpV34LuUoxs1uDx7zuOfyTCxX_caKAj3anb.qP2fsys5ruIhcwg6IeTGgXGXgpsuS7jIqGPsOhKxfZw1xwNa0;
+        path=/; expires=Fri, 31-Oct-25 03:14:05 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=C2GzMTMsYw0c9cZ482nxxNogRgIpj2ICJMMTk0RCMY8-1761878645829-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '9162'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '9193'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999595'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999595'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_6cf164b9001f417ab620f7c0d5ca8e06
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nPerform
+      a search on specific topics.\n\nExpected Output:\nA list of relevant URLs based
+      on the search query.\n\nActual Output:\nI now can give a great answer. \n\nFinal
+      Answer: Here are some relevant URLs based on your search query. Please visit
+      the following links for comprehensive information on the specified topics:\n\n1.
+      **Artificial Intelligence Ethics**\n   - https://www.aaai.org/Ethics/AIEthics.pdf\n   -
+      https://plato.stanford.edu/entries/ethics-ai/\n\n2. **Impact of 5G Technology**\n   -
+      https://www.itu.int/en/ITU-T/focusgroups/5g/Documents/FG-5G-DOC-1830.zip\n   -
+      https://www.gsma.com/5g/\n\n3. **Quantum Computing Developments**\n   - https://www.ibm.com/quantum-computing/\n   -
+      https://www.microsoft.com/en-us/quantum\n\n4. **Cybersecurity Trends 2023**\n   -
+      https://www.csoonline.com/article/3642552/cybersecurity-trends-2023.html\n   -
+      https://www.forbes.com/sites/bernardmarr/2023/01/03/top-5-cybersecurity-trends-in-2023/\n\n5.
+      **Sustainable Technology Innovations**\n   - https://www.weforum.org/agenda/2023/01/10-innovations-sustainability/\n   -
+      https://www.greenbiz.com/article/13-sustainable-tech-solutions-watch-2023\n\nFeel
+      free to explore these URLs for detailed content on each topic.\n\nPlease provide:\n-
+      Bullet points suggestions to improve future similar tasks\n- A score from 0
+      to 10 evaluating on completion, quality, and overall performance- Entities extracted
+      from the task output, if any, their type, description, and relationships"}],"model":"gpt-4.1-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"$defs":{"Entity":{"properties":{"name":{"description":"The
+      name of the entity.","title":"Name","type":"string"},"type":{"description":"The
+      type of the entity.","title":"Type","type":"string"},"description":{"description":"Description
+      of the entity.","title":"Description","type":"string"},"relationships":{"description":"Relationships
+      of the entity.","items":{"type":"string"},"title":"Relationships","type":"array"}},"required":["name","type","description","relationships"],"title":"Entity","type":"object","additionalProperties":false}},"properties":{"suggestions":{"description":"Suggestions
+      to improve future similar tasks.","items":{"type":"string"},"title":"Suggestions","type":"array"},"quality":{"description":"A
+      score from 0 to 10 evaluating on completion, quality, and overall performance,
+      all taking into account the task description, expected output, and the result
+      of the task.","title":"Quality","type":"number"},"entities":{"description":"Entities
+      extracted from the task output.","items":{"$ref":"#/$defs/Entity"},"title":"Entities","type":"array"}},"required":["suggestions","quality","entities"],"title":"TaskEvaluation","type":"object","additionalProperties":false},"name":"TaskEvaluation","strict":true}},"stream":false}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '3047'
+      content-type:
+      - application/json
+      cookie:
+      - __cf_bm=A3QgDjhHusi3NstcRRXwQT2i7SMfD0OcenI1BlEy_v4-1761878645-1.0.1.1-_WmHHgBT0.tfSicqDzwM4WLpV34LuUoxs1uDx7zuOfyTCxX_caKAj3anb.qP2fsys5ruIhcwg6IeTGgXGXgpsuS7jIqGPsOhKxfZw1xwNa0;
+        _cfuvid=C2GzMTMsYw0c9cZ482nxxNogRgIpj2ICJMMTk0RCMY8-1761878645829-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//lFbBbhs3EL37K4g9a7WSbDmGboGdBm6LunWcBkhkCCNydndaLsmQQyuK
+        4X8vyJUsqUoB9WIYGr43bx6Hs/N8JkRBqpiJQrbAsnO6vP70+fcPcXJ/dwf1L/6yXsfVz5+Q3ahu
+        PnMxSAi7/Aslb1FDaTunkcmaPiw9AmNiHb+5HF+9ubq8uMyBzirUCdY4Li+G47IjQ+VkNJmWo4ty
+        fLGBt5YkhmImvpwJIcRz/puEGoXfipkYDba/dBgCNFjMXg8JUXir0y8FhECBwfSiN0FpDaPJ2p/n
+        RYhNgyEpD/Ni9mVe3JBHyXotnLdPpFBwi8KjxicwLD7e/xrEiri1kYXzqKkjA34tovGoU80iMDB2
+        aDgItqIDMgxkhNTgidcCjBK1lTEM58VgXrwzIfo+SeYGjyK6hFTAmE+/JmebzwWHkmqSgq0jGYTH
+        rxEDo+oZb43UUaEAsfSEtVAYpCeXShTWixC7Lgm2tUCQbcqaiFvUTsSAPohoFPpkmxKrFlhsDEun
+        8JtDyX2eO9+Aoe8b3VIjeL3uwT1zlpdRpgUjk4ugYEmaeN1T/Ime6rXglAW03jkAUmIItNS9AxpB
+        JSLpUeUfg41eYrLwcTAvvkZInPNidjWYF2iYmDBf5/O8MNDhvJjNi7eek2sEWtwaRq2pwaTqHbck
+        Q9bDa9effUjS80977vUsoibU6ZajWpNp8o1gogAtqHOaJORuysKbSAo1GQwiRO9tNCphYCeF9qT0
+        puQ+SgwtuU1PtswuzKpqtVoNAYCG1jdVr7t6e9v/M3SqzvjtYaeB7TDdY229GqKKFRr2hKHKekMJ
+        VM2Lx5fBvku3nQPJqTum78UDytZYbZv1qfY8JDfqGiX3BoB6SlffP4ftC2GbyFeUGjsEIW3XRbPx
+        TfBrzpPsII5DMlyhqW4fPpYPVX5bjbfRhWraVDdWxpy9+ul9OX1f3txdl+Or89HwO7kDuxJZEzpI
+        sywBj5z5I4Lh2Ilr27nI6Rpv8Am1dZn+/xiUXAhpfNjGJwP6Rx4QvGwFmdxSfZfZWnzdpJXbtKfZ
+        suxyIRt0+YqujoruSHobbJ2neIWmjGELO/Lger1EH1DGPMoePBoVxGQ0OT+1/HuUeZT0yFQ4dc76
+        NKNFdGnkheSAPMhTW589WSP4nO0kC2Sw1qS3l+tKT05qrM4vLybT6aQ6yFD2esrM3XKnj0yqrV9i
+        yEyBGEO1RG/Aqw68rxKsGo2r0XnF1pXT8ofkZDL/cWN9iCF9ISANtt2LE7fG2CfYfJlOc/c3XGVP
+        sUPf5OG0pSMMAqhDJYBF2CbMo7hHmCfy1qRWBp06k1Em2pOcXmFtfezyVIIGjYJXS8ajknZ1lIeZ
+        j3ux8YhmSd8Prmx8vsNpLFNNZbA69pQrYNmWfQ8+vjy+7H/qPdYxQNo3TNR6LwDGWO41pSXjcRN5
+        eV0rtG2ct8vwL2hRk6HQLjxCsCatEIGtK3L05UyIx7y+xIONpHDedo4XbP/GnG6zC+VVZLs27aIX
+        k+kmypZB7wLj0Zvx4AeMC4UMpMPeClRIkC2qHXa3L0FUZPcCZ3t1H+v5EXdfO5nmFPpdQEp0jGrh
+        0jdcHta8O+Yx7ZX/dezV5yy4COifSOKCCX26C4U1RL3ZUMM6MHaLmkyD3nnqN77aLS7k5Go6rq8u
+        J8XZy9k/AAAA//8DAPxRBgAACwAA
+    headers:
+      CF-RAY:
+      - 996fcf012a0a0df7-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:44:13 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '7076'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '7246'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999595'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999595'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_2d55304787e14773ba48a58c82053156
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[search].yaml b/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[search].yaml
--- a/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[search].yaml
+++ b/lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[search].yaml
@@ -1533,4 +1533,343 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nPerform
+      a search on specific topics.\n\nExpected Output:\nA list of relevant URLs based
+      on the search query.\n\nActual Output:\nI now can give a great answer  \nFinal
+      Answer: \n\n1. **Artificial Intelligence in Healthcare**\n   - URL: [https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7073215/](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7073215/)
+      - This article explores various applications of AI in healthcare, including
+      diagnostics and treatment personalization.\n\n2. **Blockchain Technology and
+      Its Impact on Supply Chain**\n   - URL: [https://www.researchgate.net/publication/341717309_Blockchain_Technology_in_Supply_Chain_Management](https://www.researchgate.net/publication/341717309_Blockchain_Technology_in_Supply_Chain_Management)
+      - This research paper discusses the potential of blockchain in enhancing supply
+      chain transparency and efficiency.\n\n3. **Cybersecurity Trends for 2023**\n   -
+      URL: [https://www.cybersecurity-insiders.com/cybersecurity-trends-2023/](https://www.cybersecurity-insiders.com/cybersecurity-trends-2023/)
+      - This resource outlines the major cybersecurity trends expected to shape the
+      industry in 2023, including emerging threats and mitigation strategies.\n\n4.
+      **The Impact of Remote Work on Productivity**\n   - URL: [https://www.mitpressjournals.org/doi/full/10.1162/99608f92.2020.12.01](https://www.mitpressjournals.org/doi/full/10.1162/99608f92.2020.12.01)
+      - This journal article provides insights into how remote work affects productivity,
+      work-life balance, and organizational dynamics.\n\n5. **Quantum Computing: A
+      Beginner''s Guide**\n   - URL: [https://www.ibm.com/quantum-computing/learn/what-is-quantum-computing/](https://www.ibm.com/quantum-computing/learn/what-is-quantum-computing/)
+      - This resource serves as an introduction to quantum computing, detailing its
+      principles and potential applications.\n\n6. **Sustainable Energy Technologies
+      for the Future**\n   - URL: [https://www.energy.gov/eere/solar/articles/sustainable-energy-technology-future](https://www.energy.gov/eere/solar/articles/sustainable-energy-technology-future)
+      - This article discusses various sustainable energy technologies that could
+      play a crucial role in future energy landscapes.\n\n7. **5G Technology and Its
+      Implications**\n   - URL: [https://www.qualcomm.com/invention/5g/what-is-5g](https://www.qualcomm.com/invention/5g/what-is-5g)
+      - This page explains what 5G technology is and explores its potential implications
+      for various sectors including telecommunications and the Internet of Things
+      (IoT). \n\nThese resources have been carefully selected to meet the specified
+      topics and provide comprehensive insights.\n\nPlease provide:\n- Bullet points
+      suggestions to improve future similar tasks\n- A score from 0 to 10 evaluating
+      on completion, quality, and overall performance- Entities extracted from the
+      task output, if any, their type, description, and relationships"}],"model":"gpt-4.1-mini"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '3168'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=XLC52GLAWCOeWn2vI379CnSGKjPa7f.qr2vSAQ_R66M-1744489610542-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        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
+        AAA=
+    headers:
+      CF-RAY:
+      - 996fce4e98d5edbb-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:43:48 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=SO9He1GVTuDOBFVy7UPgpAiqXZwuXeli0wC9daB0knQ-1761878628-1.0.1.1-jldZtxPfeAswr22lzzVxN.W_5nEflvghqpz9M59LR9olhJD78hYz4EAWr3TuFJZgs12EnzNPJXbS01lMEU5ycEqvCgqSUlH4VgvAmfcEaAA;
+        path=/; expires=Fri, 31-Oct-25 03:13:48 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=7kM8M9HCcESw20u.sW4KgamO892RwyAOg8qAz9JDbJc-1761878628218-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '10632'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '10664'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999237'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999237'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_38a6e11e8cf24680943544e359fb348b
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nPerform
+      a search on specific topics.\n\nExpected Output:\nA list of relevant URLs based
+      on the search query.\n\nActual Output:\nI now can give a great answer  \nFinal
+      Answer: \n\n1. **Artificial Intelligence in Healthcare**\n   - URL: [https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7073215/](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7073215/)
+      - This article explores various applications of AI in healthcare, including
+      diagnostics and treatment personalization.\n\n2. **Blockchain Technology and
+      Its Impact on Supply Chain**\n   - URL: [https://www.researchgate.net/publication/341717309_Blockchain_Technology_in_Supply_Chain_Management](https://www.researchgate.net/publication/341717309_Blockchain_Technology_in_Supply_Chain_Management)
+      - This research paper discusses the potential of blockchain in enhancing supply
+      chain transparency and efficiency.\n\n3. **Cybersecurity Trends for 2023**\n   -
+      URL: [https://www.cybersecurity-insiders.com/cybersecurity-trends-2023/](https://www.cybersecurity-insiders.com/cybersecurity-trends-2023/)
+      - This resource outlines the major cybersecurity trends expected to shape the
+      industry in 2023, including emerging threats and mitigation strategies.\n\n4.
+      **The Impact of Remote Work on Productivity**\n   - URL: [https://www.mitpressjournals.org/doi/full/10.1162/99608f92.2020.12.01](https://www.mitpressjournals.org/doi/full/10.1162/99608f92.2020.12.01)
+      - This journal article provides insights into how remote work affects productivity,
+      work-life balance, and organizational dynamics.\n\n5. **Quantum Computing: A
+      Beginner''s Guide**\n   - URL: [https://www.ibm.com/quantum-computing/learn/what-is-quantum-computing/](https://www.ibm.com/quantum-computing/learn/what-is-quantum-computing/)
+      - This resource serves as an introduction to quantum computing, detailing its
+      principles and potential applications.\n\n6. **Sustainable Energy Technologies
+      for the Future**\n   - URL: [https://www.energy.gov/eere/solar/articles/sustainable-energy-technology-future](https://www.energy.gov/eere/solar/articles/sustainable-energy-technology-future)
+      - This article discusses various sustainable energy technologies that could
+      play a crucial role in future energy landscapes.\n\n7. **5G Technology and Its
+      Implications**\n   - URL: [https://www.qualcomm.com/invention/5g/what-is-5g](https://www.qualcomm.com/invention/5g/what-is-5g)
+      - This page explains what 5G technology is and explores its potential implications
+      for various sectors including telecommunications and the Internet of Things
+      (IoT). \n\nThese resources have been carefully selected to meet the specified
+      topics and provide comprehensive insights.\n\nPlease provide:\n- Bullet points
+      suggestions to improve future similar tasks\n- A score from 0 to 10 evaluating
+      on completion, quality, and overall performance- Entities extracted from the
+      task output, if any, their type, description, and relationships"}],"model":"gpt-4.1-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"$defs":{"Entity":{"properties":{"name":{"description":"The
+      name of the entity.","title":"Name","type":"string"},"type":{"description":"The
+      type of the entity.","title":"Type","type":"string"},"description":{"description":"Description
+      of the entity.","title":"Description","type":"string"},"relationships":{"description":"Relationships
+      of the entity.","items":{"type":"string"},"title":"Relationships","type":"array"}},"required":["name","type","description","relationships"],"title":"Entity","type":"object","additionalProperties":false}},"properties":{"suggestions":{"description":"Suggestions
+      to improve future similar tasks.","items":{"type":"string"},"title":"Suggestions","type":"array"},"quality":{"description":"A
+      score from 0 to 10 evaluating on completion, quality, and overall performance,
+      all taking into account the task description, expected output, and the result
+      of the task.","title":"Quality","type":"number"},"entities":{"description":"Entities
+      extracted from the task output.","items":{"$ref":"#/$defs/Entity"},"title":"Entities","type":"array"}},"required":["suggestions","quality","entities"],"title":"TaskEvaluation","type":"object","additionalProperties":false},"name":"TaskEvaluation","strict":true}},"stream":false}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '4474'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=7kM8M9HCcESw20u.sW4KgamO892RwyAOg8qAz9JDbJc-1761878628218-0.0.1.1-604800000;
+        __cf_bm=SO9He1GVTuDOBFVy7UPgpAiqXZwuXeli0wC9daB0knQ-1761878628-1.0.1.1-jldZtxPfeAswr22lzzVxN.W_5nEflvghqpz9M59LR9olhJD78hYz4EAWr3TuFJZgs12EnzNPJXbS01lMEU5ycEqvCgqSUlH4VgvAmfcEaAA
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        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
+        AA==
+    headers:
+      CF-RAY:
+      - 996fce9299c8edbb-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:43:55 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '6791'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '7015'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999237'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999237'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_c2800884308c4f16a5f097a079e5b09c
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_crew_train_success.yaml b/lib/crewai/tests/cassettes/test_crew_train_success.yaml
--- a/lib/crewai/tests/cassettes/test_crew_train_success.yaml
+++ b/lib/crewai/tests/cassettes/test_crew_train_success.yaml
@@ -1896,4 +1896,787 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: '{"trace_id": "3f34b857-57cb-4019-85f5-24ea07008c41", "execution_type":
+      "crew", "user_identifier": null, "execution_context": {"crew_fingerprint": null,
+      "crew_name": "crew", "flow_name": null, "crewai_version": "1.2.1", "privacy_level":
+      "standard"}, "execution_metadata": {"expected_duration_estimate": 300, "agent_count":
+      0, "task_count": 0, "flow_method_count": 0, "execution_started_at": "2025-10-31T01:21:47.051114+00:00"},
+      "ephemeral_trace_id": "3f34b857-57cb-4019-85f5-24ea07008c41"}'
+    headers:
+      Accept:
+      - '*/*'
+      Accept-Encoding:
+      - gzip, deflate, zstd
+      Connection:
+      - keep-alive
+      Content-Length:
+      - '488'
+      Content-Type:
+      - application/json
+      User-Agent:
+      - CrewAI-CLI/1.2.1
+      X-Crewai-Organization-Id:
+      - 73c2b193-f579-422c-84c7-76a39a1da77f
+      X-Crewai-Version:
+      - 1.2.1
+    method: POST
+    uri: https://app.crewai.com/crewai_plus/api/v1/tracing/ephemeral/batches
+  response:
+    body:
+      string: '{"id":"55d9a1b4-f578-4046-9ec2-5e0ae5b5c4ac","ephemeral_trace_id":"3f34b857-57cb-4019-85f5-24ea07008c41","execution_type":"crew","crew_name":"crew","flow_name":null,"status":"running","duration_ms":null,"crewai_version":"1.2.1","total_events":0,"execution_context":{"crew_fingerprint":null,"crew_name":"crew","flow_name":null,"crewai_version":"1.2.1","privacy_level":"standard"},"created_at":"2025-10-31T01:21:47.937Z","updated_at":"2025-10-31T01:21:47.937Z","access_code":"TRACE-c44455c874","user_identifier":null}'
+    headers:
+      Connection:
+      - keep-alive
+      Content-Length:
+      - '515'
+      Content-Type:
+      - application/json; charset=utf-8
+      Date:
+      - Fri, 31 Oct 2025 01:21:47 GMT
+      cache-control:
+      - no-store
+      content-security-policy:
+      - 'default-src ''self'' *.app.crewai.com app.crewai.com; script-src ''self''
+        ''unsafe-inline'' *.app.crewai.com app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts
+        https://www.gstatic.com https://run.pstmn.io https://apis.google.com https://apis.google.com/js/api.js
+        https://accounts.google.com https://accounts.google.com/gsi/client https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css.map
+        https://*.google.com https://docs.google.com https://slides.google.com https://js.hs-scripts.com
+        https://js.sentry-cdn.com https://browser.sentry-cdn.com https://www.googletagmanager.com
+        https://js-na1.hs-scripts.com https://js.hubspot.com http://js-na1.hs-scripts.com
+        https://bat.bing.com https://cdn.amplitude.com https://cdn.segment.com https://d1d3n03t5zntha.cloudfront.net/
+        https://descriptusercontent.com https://edge.fullstory.com https://googleads.g.doubleclick.net
+        https://js.hs-analytics.net https://js.hs-banner.com https://js.hsadspixel.net
+        https://js.hscollectedforms.net https://js.usemessages.com https://snap.licdn.com
+        https://static.cloudflareinsights.com https://static.reo.dev https://www.google-analytics.com
+        https://share.descript.com/; style-src ''self'' ''unsafe-inline'' *.app.crewai.com
+        app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts; img-src ''self'' data:
+        *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com https://dashboard.tools.crewai.com
+        https://cdn.jsdelivr.net https://forms.hsforms.com https://track.hubspot.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://www.google.com
+        https://www.google.com.br; font-src ''self'' data: *.app.crewai.com app.crewai.com;
+        connect-src ''self'' *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com
+        https://connect.useparagon.com/ https://zeus.useparagon.com/* https://*.useparagon.com/*
+        https://run.pstmn.io https://connect.tools.crewai.com/ https://*.sentry.io
+        https://www.google-analytics.com https://edge.fullstory.com https://rs.fullstory.com
+        https://api.hubspot.com https://forms.hscollectedforms.net https://api.hubapi.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://google.com/pagead/form-data/16713662509
+        https://google.com/ccm/form-data/16713662509 https://www.google.com/ccm/collect
+        https://worker-actionkit.tools.crewai.com https://api.reo.dev; frame-src ''self''
+        *.app.crewai.com app.crewai.com https://connect.useparagon.com/ https://zeus.tools.crewai.com
+        https://zeus.useparagon.com/* https://connect.tools.crewai.com/ https://docs.google.com
+        https://drive.google.com https://slides.google.com https://accounts.google.com
+        https://*.google.com https://app.hubspot.com/ https://td.doubleclick.net https://www.googletagmanager.com/
+        https://www.youtube.com https://share.descript.com'
+      etag:
+      - W/"85f3e6adb7d3fa5a12f02b27ada57896"
+      expires:
+      - '0'
+      permissions-policy:
+      - camera=(), microphone=(self), geolocation=()
+      pragma:
+      - no-cache
+      referrer-policy:
+      - strict-origin-when-cross-origin
+      strict-transport-security:
+      - max-age=63072000; includeSubDomains
+      vary:
+      - Accept
+      x-content-type-options:
+      - nosniff
+      x-frame-options:
+      - SAMEORIGIN
+      x-permitted-cross-domain-policies:
+      - none
+      x-request-id:
+      - 6ec96f4d-08c8-4db0-b7b5-91974fbbd05c
+      x-runtime:
+      - '0.243555'
+      x-xss-protection:
+      - 1; mode=block
+    status:
+      code: 201
+      message: Created
+- request:
+    body: "{\"messages\":[{\"role\":\"system\",\"content\":\"I'm gonna convert this
+      raw text into valid JSON.\"},{\"role\":\"user\",\"content\":\"Assess the quality
+      of the training data based on the llm output, human feedback , and llm output
+      improved result.\\n\\nIteration: 0\\nInitial Output:\\n- **The Evolution of
+      AI Agents in Customer Service**\\n  The landscape of customer service has radically
+      transformed with the advent of AI agents. This article could delve into how
+      businesses are employing AI to enhance customer experiences, reduce wait times,
+      and streamline operations. Highlighting real-world case studies from leading
+      companies, it would explore the measures taken to train these AI agents, the
+      challenges of human emotional intelligence versus AI, and the future implications
+      of AI agents in understanding and predicting customer needs. This combination
+      would provide a comprehensive look at the efficiencies gained, while also addressing
+      ethical considerations in AI communication.\\n\\n- **AI Agents as Companions:
+      The Future of Personal Relationships**\\n  As technology blurs the lines between
+      human and machine interaction, the concept of AI agents as companions is becoming
+      increasingly popular. This article could explore the psychological and social
+      implications of forming bonds with AI, looking at current AI companion projects
+      such as virtual pets and virtual therapists. It would question if these AI relationships
+      can indeed fulfill emotional needs, and what it means for human connection in
+      an increasingly digital world. This exploration would not only gather diverse
+      viewpoints but also touch upon ethical considerations surrounding companionship
+      and loneliness.\\n\\n- **AI Agents in Creative Arts: Redefining Creativity**\\n
+      \ The infusion of AI into creative arts poses unique questions about authorship
+      and originality. This topic could lead to a compelling article that examines
+      how AI agents are being used to create paintings, compose music, and write literature.
+      By analyzing specific tools such as OpenAI\u2019s Muse and Google\u2019s DeepDream,
+      the article would aim to untangle the perceived boundaries of creativity, discussing
+      whether AI can ever genuinely create or merely mimic human artists. This perspective
+      would bring readers into the fascinating intersection of technology and art,
+      raising questions about the future of creative expression.\\n\\n- **Ethical
+      Considerations of AI Agents in Decision Making**\\n  With AI increasingly taking
+      on decision-making roles in various sectors\u2014from finance to healthcare
+      and even law\u2014it\u2019s critical to scrutinize the ethical ramifications
+      of these technologies. An article focused on this topic could explore how AI
+      agents analyze vast datasets to inform decisions, the potential biases encoded
+      in their algorithms, and the accountability measures necessary to monitor their
+      outputs. It would invite a discussion on what role human oversight should play,
+      making the case for a balanced integration of AI agents that respects both efficiency
+      and ethical standards.\\n\\n- **The Financial Impacts of AI Agents on Startups**\\n
+      \ Startups are typically characterized by limited resources and the need for
+      agile approaches to market challenges. This article could investigate how AI
+      agents are reshaping financial strategies in startups, from automating mundane
+      tasks to offering insights through data analysis. By highlighting successful
+      startup case studies and quantifying improvements brought about by integrating
+      AI agents, readers would grasp the potential cost savings and increased efficiency
+      that AI can offer. It would further explore how these startups leverage their
+      AI capabilities for competitive advantages, marking a crucial study for entrepreneurs
+      and investors alike.\\n\\nEach idea presents an opportunity to deeply analyze
+      the impacts of AI agents across various facets of modern life, emphasizing not
+      only their technological advancements but also the accompanying ethical and
+      social implications.\\n\\nHuman Feedback:\\nGreat work!\\n\\nImproved Output:\\n-
+      **The Evolution of AI Agents in Customer Service**\\n  The landscape of customer
+      service has radically transformed with the advent of AI agents. This article
+      could delve into how businesses are employing AI to enhance customer experiences,
+      reduce wait times, and streamline operations. By featuring in-depth case studies
+      from leading companies such as Amazon and Zappos, it would explore the measures
+      taken to train these AI agents while addressing the challenges of human emotional
+      intelligence versus AI. The article would further investigate the future implications
+      of AI agents in understanding and predicting customer needs, ensuring a comprehensive
+      look at the efficiencies gained, and addressing the ethical considerations surrounding
+      AI communication.\\n\\n- **AI Agents as Companions: The Future of Personal Relationships**\\n
+      \ As technology blurs the lines between human and machine interaction, the concept
+      of AI agents as companions is becoming increasingly popular. This article could
+      explore the psychological and social implications of forming bonds with AI,
+      spotlighting current AI companion projects like Replika and virtual pets such
+      as Aibo. It would examine whether these AI relationships can genuinely fulfill
+      emotional needs and consider what this trend means for human connection in an
+      increasingly digital world. Through interviews with users and specialists, the
+      article would offer diverse viewpoints and address the ethical considerations
+      of companionship and loneliness, ultimately provoking thought on our future
+      interactions with technology.\\n\\n- **AI Agents in Creative Arts: Redefining
+      Creativity**\\n  The infusion of AI into creative arts poses unique questions
+      about authorship and originality. This compelling article could investigate
+      how AI agents are actively creating paintings, composing music, and even writing
+      prose, utilizing tools such as OpenAI\u2019s Muse and Google\u2019s DeepDream.
+      It would challenge readers to consider whether AI can genuinely create or merely
+      mimic human artistry, delving into the fascinating intersection of technology
+      and art. The article would include perspectives from artists collaborating with
+      AI, offering insights on the evolving landscape of creativity and raising important
+      questions about the future of artistic expression in an AI-enhanced world.\\n\\n-
+      **Ethical Considerations of AI Agents in Decision Making**\\n  With AI increasingly
+      taking on decision-making roles in various sectors\u2014from finance and healthcare
+      to law\u2014scrutinizing the ethical ramifications of these technologies is
+      imperative. This investigative article could explore how AI agents analyze vast
+      datasets to inform crucial decisions while uncovering potential biases embedded
+      in their algorithms. It would articulate necessary accountability measures for
+      monitoring AI outputs and invite thoughtful discussion on the importance of
+      human oversight. By spotlighting thought leaders in ethics and technology, the
+      article would ensure a balanced perspective on integrating AI agents that respects
+      both efficiency and ethical standards.\\n\\n- **The Financial Impacts of AI
+      Agents on Startups**\\n  Startups, characterized by limited resources and the
+      need for agile strategies, are leveraging AI agents to reshape financial decision-making.
+      This article could investigate the ways in which startups are harnessing AI
+      to automate administrative tasks, gain insights through predictive analytics,
+      and improve customer engagement. By presenting in-depth case studies, the article
+      would quantify the improvements brought about by integrating AI agents, demonstrating
+      the potential cost savings and increased efficiency they offer. Furthermore,
+      the article could explore how startups leverage their AI capabilities for competitive
+      advantages, ultimately serving as a crucial resource for entrepreneurs and investors
+      looking to navigate the evolving business landscape.\\n\\nThese ideas not only
+      highlight the transformative impact of AI agents across various domains but
+      also address the underlying ethical, social, and financial dynamics that are
+      essential for a thorough understanding of their role in society today.\\n\\n------------------------------------------------\\n\\nIteration:
+      1\\nInitial Output:\\n- **The Rise of AI Agents in Remote Work Environments**
+      \ \\nIn the wake of the pandemic, remote work has become a part of our daily
+      lives. AI agents are stepping into this new workspace, facilitating communication,
+      task management, and team collaboration like never before. By exploring the
+      impact of AI agents in virtual settings, the article could delve into how these
+      intelligent systems optimize productivity, reduce operational costs, and enhance
+      employee satisfaction. The journey of these agents\u2014from simple chatbots
+      to sophisticated virtual assistants\u2014presents a fascinating evolution that
+      reshapes not just how we work but also how we connect.\\n\\n- **Ethical Implications
+      of AI Decision-Making**  \\nAs AI systems gain prominence in decision-making
+      processes across various sectors\u2014from healthcare to finance\u2014the ethical
+      implications become more pressing. An insightful article could dissect the moral
+      dilemmas posed by AI, such as biases embedded in algorithms, data privacy concerns,
+      and the accountability of AI's actions. By interrogating the complexities of
+      trust in AI systems, the piece could highlight the critical need for transparent
+      frameworks and governance, ensuring that AI serves humanity fairly and justly
+      in an increasingly automated world.\\n\\n- **AI Agents as Creative Collaborators**
+      \ \\nAI's foray into creative domains is revolutionizing fields such as art,
+      music, and writing. An engaging article could showcase how AI agents function
+      alongside human creators, pushing the boundaries of creativity and innovation.
+      This exploration could highlight notable collaborations between humans and AI,
+      celebrating the intriguing ways in which technology enhances artistic expression.
+      By illustrating the symbiotic relationship between human intuition and AI's
+      analytical prowess, the article could underscore that creativity is no longer
+      solely a human domain but a collective endeavor involving intelligent machines.\\n\\n-
+      **Personalized Learning Experiences through AI Agents**  \\nEducation is undergoing
+      a transformation with the integration of AI agents into personalized learning
+      environments. An article could examine how these agents tailor educational content
+      to individual student's needs, moving away from one-size-fits-all approaches
+      toward truly customized learning experiences. By interviewing educators and
+      students, the piece can illustrate the profound impact of AI on student engagement,
+      academic performance, and emotional support, making a strong case for the necessity
+      of AI-driven methods in modern education.\\n\\n- **The Future of AI in Mental
+      Health Support**  \\nAs mental health becomes an increasingly crucial area of
+      focus, AI agents are emerging as supplementary tools for psychological support.
+      An article could explore the role of AI in providing real-time assistance, stigma
+      reduction, and accessibility to mental health resources. By sharing success
+      stories and evidence from trials, the piece can encapsulate the potential for
+      AI agents to act as companions that offer kindness and empathy, alongside professional
+      support. This discussion may ultimately lead to a greater appreciation of AI's
+      capacity to enhance mental well-being in an era where mental health challenges
+      are more prevalent than ever.\\n\\nNotes: Each of these ideas addresses a timely
+      and relevant intersection between technology and human experience, making them
+      compelling subjects for in-depth articles. The potential for engaging readers
+      with real-world applications, ethical considerations, and innovative collaborations
+      ensures that these topics will resonate widely and inspire thoughtful discussion.\\n\\nHuman
+      Feedback:\\nGreat work!\\n\\nImproved Output:\\n- **The Rise of AI Agents in
+      Remote Work Environments**  \\nIn the wake of the pandemic, remote work has
+      become a staple in our daily routines, reshaping how businesses operate globally.
+      AI agents are uniquely positioned to enhance this dynamic, stepping into virtual
+      offices to facilitate seamless communication, task management, and collaborative
+      projects. An article exploring the impact of AI agents in remote settings could
+      investigate how these intelligent assistants optimize productivity, reduce operational
+      costs, and improve employee morale by mitigating the isolation often felt in
+      remote work. The journey of AI\u2014from basic scheduling tools to multifunctional
+      virtual colleagues\u2014offers a captivating narrative on technology's role
+      in redefining our professional landscape and fostering human connections in
+      digital spaces.\\n\\n- **Ethical Implications of AI Decision-Making**  \\nAs
+      AI systems increasingly influence critical decision-making in various sectors
+      such as healthcare, finance, and criminal justice, the ethical implications
+      become a hotbed for discussion. A thorough investigation into the moral dilemmas
+      surrounding AI could scrutinize issues such as system biases, data privacy,
+      and the ambiguity of accountability for AI-driven outcomes. This article could
+      engage with thought leaders and ethicists to illuminate the pressing need for
+      ethical frameworks and governance models that ensure AI technologies promote
+      equity and are designed to serve human interests, fostering a society where
+      trust in AI can flourish.\\n\\n- **AI Agents as Creative Collaborators**  \\nThe
+      canvas of creativity is expanding with the emergence of AI agents as collaborators
+      in artistic domains like visual arts, music production, and literary composition.
+      An engaging article could celebrate the symbiotic relationship between human
+      creators and AI, illustrating how these intelligent systems are not mere tools
+      but creative partners that inspire innovation. By profiling groundbreaking collaborations
+      where AI and human artists co-create, this piece would delve into the possibilities
+      that arise when technology enhances human expression, evolving the narrative
+      around creativity as a shared endeavor rather than a solitary pursuit.\\n\\n-
+      **Personalized Learning Experiences through AI Agents**  \\nEducation is at
+      a transformational crossroads, with AI agents revolutionizing how students learn
+      through personalized educational experiences. A compelling article could explore
+      how these intelligent systems adapt learning materials to meet each student's
+      unique needs, thereby moving away from traditional, uniform teaching methods.
+      Interviews with educators and students could reveal powerful testimonials that
+      attest to the positive effects of AI-driven personalized learning, including
+      improved engagement and academic success, establishing a strong argument for
+      the integration of intelligent technologies in classrooms everywhere.\\n\\n-
+      **The Future of AI in Mental Health Support**  \\nAs society increasingly acknowledges
+      mental health issues, AI agents are emerging as vital tools in providing mental
+      health support and resources. An insightful article could examine the potential
+      of AI as a supplemental resource for individuals seeking emotional assistance,
+      highlighting innovations in real-time supportive interactions and stigma reduction.
+      By showcasing case studies of successful AI applications in therapy, the piece
+      would underscore the transformative role these technologies can play in making
+      mental health care accessible and efficient, positioning AI not only as a technological
+      advancement but as a crucial ally in promoting overall well-being in modern
+      life.\\n\\nNotes: Each idea serves as a portal into crucial conversations about
+      technology's role in human experiences, categorized within a contemporary context.
+      The integration of personal stories, expert interviews, and ethical considerations
+      enriches these topics, ensuring they resonate widely, inspire curiosity, and
+      engage readers in meaningful dialogue. This comprehensive approach will enhance
+      the overall quality and relevance of the articles while appealing to a diverse
+      audience.\\n\\n------------------------------------------------\\n\\nPlease
+      provide:\\n- Provide a list of clear, actionable instructions derived from the
+      Human Feedbacks to enhance the Agent's performance. Analyze the differences
+      between Initial Outputs and Improved Outputs to generate specific action items
+      for future tasks. Ensure all key and specificpoints from the human feedback
+      are incorporated into these instructions.\\n- A score from 0 to 10 evaluating
+      on completion, quality, and overall performance from the improved output to
+      the initial output based on the human feedback\\n\"}],\"model\":\"gpt-4.1-mini\"}"
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '16697'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=m.ZI0jUJJ4xpeJ9MnVSjtXyq990VBTzugjakItyO6Cs-1761055572454-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//dFZNbxs3EL37Vwz2vApkR4lS34w2hxRNkaItgrQOjBE5uzs1l8OQs7LV
+        wP+9GK5kyW5yEbAccua9N1/6egbQsG8uoXEDqhtTWPz48dM6/vZn/PD2l5/i+o+/fv2y6q/Gj5v3
+        y0/vf25aeyGbf8jp4dULJ2MKpCxxNrtMqGRez9evz9+sX66X62oYxVOwZ33SxerF+WLkyIuL5cWr
+        xXK1OF/tnw/CjkpzCX+fAQB8rb8GNHq6by5h2R5ORioFe2ouHy8BNFmCnTRYChfFqE17NDqJSrFi
+        /3odAa6bK2fIcRPoXSyap/pZri28XbArb+OA0RGURI47dqw72OyAowuT59iDk+gyKQHdo2lRWiiT
+        GwALmDgYdxBxtOOUxbQ7fEp+dAoqEkoLKtBnmaIHHQgwK7tAwJ6wwCiZoOM8BosOmTAs7iQHD5XX
+        vZYX1017gP0uOslJMiqB5y3lQpAoW0DlrYU/MuColLdMdwXuWAeg+0RZSwtToTwD1UGmflAIhL6e
+        qQB6D56SDoDRg8vkecPB9FGp+Pd6n8K68j5TKUA6sMNgVwp7yliFBxcIc9hVhxxnyp4UObQwcD8E
+        7gc1yHGypJRHpTeMpQV0TqaoOMMwwXmLbtdWf4aoiGMMwGNCpyAdXL0DJTdECdIzPVHw7X06PIuY
+        DeGWjNmsG0EmR1HB05aCpJGiljlOpugL6IAKgePtMcBulneYRoyzyEzR0WkqaJRakaG62sP1PFIs
+        JtApvj8LAcUee459C1vesoeAsZ+wp/m1St4phWCOKwj+MlExDiPeGpfErkCmgGotMKdRxrR/0kkG
+        hE0W9ICTr1hPAXzIsmVPc9JMpxGVHXQZxxrRBCisEyoVIHTDHLGKwHF2TLmSJMXQnmTC2adkICdR
+        RnaPJd6Cp1GsV7HWQaZA29qfVXoeKXCk8rwVasKSWDWaoG7AECj21gaeA40jzmVuYbJYt/AsVCdF
+        Ke/LzYPn4qZSUwEZdSDjjREMj5VmJ/kOs7VFcZmTPs/ZlfcQxfSw5p/GEXMNZFJl4thJdlRLLk05
+        SZlpYUqEwcr1ZCqUFiiWKc9S0w5s3HmQSa0f9v26SFm2cmt3DsnNNFgxbZ+k8j1yVORo+cYwc1WJ
+        dEDmpI/8LxXYiA4VxYYidbwv+cAj676F56bClAK7+ajdq1iHZWatjW8lYLieV/Q8hadMvoUkgctA
+        3gZn2WMpo4gOBTRjLDyHnKnFSE7LfljuiyjsQIdsUpguVVemWsUW83M7b4HfnWSyof/DdXw4XRiZ
+        uqmgba04hXBiwBhlT9h2xee95eFxOQXpU5ZNefa06ThyGW4yYZFoi6iopKZaH84MkS3B6clea1KW
+        MemNyi3VcBfr1Xp22By374n59cGqohiOhpfL81X7DZc384QtJ5u0cegG8idOl6s3jyRsGMjRtjw7
+        4f5/SN9yP/Pn2J94+a77o8E5Skr+JtmucU9pH69lsi37vWuPWlfATbHN5+hGmbLlw1OHU5j/NjRl
+        V5TGm45jTzllnv87dOlm5S7evDrv3ry+aM4ezv4DAAD//wMAYqeVu0oJAAA=
+    headers:
+      CF-RAY:
+      - 996f566c0d47eda4-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 01:21:50 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=hk.dUrCne4r20h6mq0lNOA1fyN8qNNN2wDRfIxVmRrg-1761873710-1.0.1.1-DYHNFwh3pzCCnEiUAjr8eQb_Le1gJp6eIBCaTHjkXuGf6lL2exJ6dig0Rv.r1XAEkni.IO8K2OiJiY9S1Pd29Hf1NsRPKkYXAYc8brdr5Zs;
+        path=/; expires=Fri, 31-Oct-25 01:51:50 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=_ywFekSfflLNT4n4CAra7U6FQ81CokpzhqfwrjWPQmA-1761873710747-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '3361'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '3376'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149995870'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149995870'
+      x-ratelimit-reset-project-tokens:
+      - 1ms
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 1ms
+      x-request-id:
+      - req_3c80ffd7d4584d2abbfecd157a8d97bf
+    status:
+      code: 200
+      message: OK
+- request:
+    body: "{\"messages\":[{\"role\":\"system\",\"content\":\"I'm gonna convert this
+      raw text into valid JSON.\"},{\"role\":\"user\",\"content\":\"Assess the quality
+      of the training data based on the llm output, human feedback , and llm output
+      improved result.\\n\\nIteration: 0\\nInitial Output:\\n- **The Evolution of
+      AI Agents in Customer Service**\\n  The landscape of customer service has radically
+      transformed with the advent of AI agents. This article could delve into how
+      businesses are employing AI to enhance customer experiences, reduce wait times,
+      and streamline operations. Highlighting real-world case studies from leading
+      companies, it would explore the measures taken to train these AI agents, the
+      challenges of human emotional intelligence versus AI, and the future implications
+      of AI agents in understanding and predicting customer needs. This combination
+      would provide a comprehensive look at the efficiencies gained, while also addressing
+      ethical considerations in AI communication.\\n\\n- **AI Agents as Companions:
+      The Future of Personal Relationships**\\n  As technology blurs the lines between
+      human and machine interaction, the concept of AI agents as companions is becoming
+      increasingly popular. This article could explore the psychological and social
+      implications of forming bonds with AI, looking at current AI companion projects
+      such as virtual pets and virtual therapists. It would question if these AI relationships
+      can indeed fulfill emotional needs, and what it means for human connection in
+      an increasingly digital world. This exploration would not only gather diverse
+      viewpoints but also touch upon ethical considerations surrounding companionship
+      and loneliness.\\n\\n- **AI Agents in Creative Arts: Redefining Creativity**\\n
+      \ The infusion of AI into creative arts poses unique questions about authorship
+      and originality. This topic could lead to a compelling article that examines
+      how AI agents are being used to create paintings, compose music, and write literature.
+      By analyzing specific tools such as OpenAI\u2019s Muse and Google\u2019s DeepDream,
+      the article would aim to untangle the perceived boundaries of creativity, discussing
+      whether AI can ever genuinely create or merely mimic human artists. This perspective
+      would bring readers into the fascinating intersection of technology and art,
+      raising questions about the future of creative expression.\\n\\n- **Ethical
+      Considerations of AI Agents in Decision Making**\\n  With AI increasingly taking
+      on decision-making roles in various sectors\u2014from finance to healthcare
+      and even law\u2014it\u2019s critical to scrutinize the ethical ramifications
+      of these technologies. An article focused on this topic could explore how AI
+      agents analyze vast datasets to inform decisions, the potential biases encoded
+      in their algorithms, and the accountability measures necessary to monitor their
+      outputs. It would invite a discussion on what role human oversight should play,
+      making the case for a balanced integration of AI agents that respects both efficiency
+      and ethical standards.\\n\\n- **The Financial Impacts of AI Agents on Startups**\\n
+      \ Startups are typically characterized by limited resources and the need for
+      agile approaches to market challenges. This article could investigate how AI
+      agents are reshaping financial strategies in startups, from automating mundane
+      tasks to offering insights through data analysis. By highlighting successful
+      startup case studies and quantifying improvements brought about by integrating
+      AI agents, readers would grasp the potential cost savings and increased efficiency
+      that AI can offer. It would further explore how these startups leverage their
+      AI capabilities for competitive advantages, marking a crucial study for entrepreneurs
+      and investors alike.\\n\\nEach idea presents an opportunity to deeply analyze
+      the impacts of AI agents across various facets of modern life, emphasizing not
+      only their technological advancements but also the accompanying ethical and
+      social implications.\\n\\nHuman Feedback:\\nGreat work!\\n\\nImproved Output:\\n-
+      **The Evolution of AI Agents in Customer Service**\\n  The landscape of customer
+      service has radically transformed with the advent of AI agents. This article
+      could delve into how businesses are employing AI to enhance customer experiences,
+      reduce wait times, and streamline operations. By featuring in-depth case studies
+      from leading companies such as Amazon and Zappos, it would explore the measures
+      taken to train these AI agents while addressing the challenges of human emotional
+      intelligence versus AI. The article would further investigate the future implications
+      of AI agents in understanding and predicting customer needs, ensuring a comprehensive
+      look at the efficiencies gained, and addressing the ethical considerations surrounding
+      AI communication.\\n\\n- **AI Agents as Companions: The Future of Personal Relationships**\\n
+      \ As technology blurs the lines between human and machine interaction, the concept
+      of AI agents as companions is becoming increasingly popular. This article could
+      explore the psychological and social implications of forming bonds with AI,
+      spotlighting current AI companion projects like Replika and virtual pets such
+      as Aibo. It would examine whether these AI relationships can genuinely fulfill
+      emotional needs and consider what this trend means for human connection in an
+      increasingly digital world. Through interviews with users and specialists, the
+      article would offer diverse viewpoints and address the ethical considerations
+      of companionship and loneliness, ultimately provoking thought on our future
+      interactions with technology.\\n\\n- **AI Agents in Creative Arts: Redefining
+      Creativity**\\n  The infusion of AI into creative arts poses unique questions
+      about authorship and originality. This compelling article could investigate
+      how AI agents are actively creating paintings, composing music, and even writing
+      prose, utilizing tools such as OpenAI\u2019s Muse and Google\u2019s DeepDream.
+      It would challenge readers to consider whether AI can genuinely create or merely
+      mimic human artistry, delving into the fascinating intersection of technology
+      and art. The article would include perspectives from artists collaborating with
+      AI, offering insights on the evolving landscape of creativity and raising important
+      questions about the future of artistic expression in an AI-enhanced world.\\n\\n-
+      **Ethical Considerations of AI Agents in Decision Making**\\n  With AI increasingly
+      taking on decision-making roles in various sectors\u2014from finance and healthcare
+      to law\u2014scrutinizing the ethical ramifications of these technologies is
+      imperative. This investigative article could explore how AI agents analyze vast
+      datasets to inform crucial decisions while uncovering potential biases embedded
+      in their algorithms. It would articulate necessary accountability measures for
+      monitoring AI outputs and invite thoughtful discussion on the importance of
+      human oversight. By spotlighting thought leaders in ethics and technology, the
+      article would ensure a balanced perspective on integrating AI agents that respects
+      both efficiency and ethical standards.\\n\\n- **The Financial Impacts of AI
+      Agents on Startups**\\n  Startups, characterized by limited resources and the
+      need for agile strategies, are leveraging AI agents to reshape financial decision-making.
+      This article could investigate the ways in which startups are harnessing AI
+      to automate administrative tasks, gain insights through predictive analytics,
+      and improve customer engagement. By presenting in-depth case studies, the article
+      would quantify the improvements brought about by integrating AI agents, demonstrating
+      the potential cost savings and increased efficiency they offer. Furthermore,
+      the article could explore how startups leverage their AI capabilities for competitive
+      advantages, ultimately serving as a crucial resource for entrepreneurs and investors
+      looking to navigate the evolving business landscape.\\n\\nThese ideas not only
+      highlight the transformative impact of AI agents across various domains but
+      also address the underlying ethical, social, and financial dynamics that are
+      essential for a thorough understanding of their role in society today.\\n\\n------------------------------------------------\\n\\nIteration:
+      1\\nInitial Output:\\n- **The Rise of AI Agents in Remote Work Environments**
+      \ \\nIn the wake of the pandemic, remote work has become a part of our daily
+      lives. AI agents are stepping into this new workspace, facilitating communication,
+      task management, and team collaboration like never before. By exploring the
+      impact of AI agents in virtual settings, the article could delve into how these
+      intelligent systems optimize productivity, reduce operational costs, and enhance
+      employee satisfaction. The journey of these agents\u2014from simple chatbots
+      to sophisticated virtual assistants\u2014presents a fascinating evolution that
+      reshapes not just how we work but also how we connect.\\n\\n- **Ethical Implications
+      of AI Decision-Making**  \\nAs AI systems gain prominence in decision-making
+      processes across various sectors\u2014from healthcare to finance\u2014the ethical
+      implications become more pressing. An insightful article could dissect the moral
+      dilemmas posed by AI, such as biases embedded in algorithms, data privacy concerns,
+      and the accountability of AI's actions. By interrogating the complexities of
+      trust in AI systems, the piece could highlight the critical need for transparent
+      frameworks and governance, ensuring that AI serves humanity fairly and justly
+      in an increasingly automated world.\\n\\n- **AI Agents as Creative Collaborators**
+      \ \\nAI's foray into creative domains is revolutionizing fields such as art,
+      music, and writing. An engaging article could showcase how AI agents function
+      alongside human creators, pushing the boundaries of creativity and innovation.
+      This exploration could highlight notable collaborations between humans and AI,
+      celebrating the intriguing ways in which technology enhances artistic expression.
+      By illustrating the symbiotic relationship between human intuition and AI's
+      analytical prowess, the article could underscore that creativity is no longer
+      solely a human domain but a collective endeavor involving intelligent machines.\\n\\n-
+      **Personalized Learning Experiences through AI Agents**  \\nEducation is undergoing
+      a transformation with the integration of AI agents into personalized learning
+      environments. An article could examine how these agents tailor educational content
+      to individual student's needs, moving away from one-size-fits-all approaches
+      toward truly customized learning experiences. By interviewing educators and
+      students, the piece can illustrate the profound impact of AI on student engagement,
+      academic performance, and emotional support, making a strong case for the necessity
+      of AI-driven methods in modern education.\\n\\n- **The Future of AI in Mental
+      Health Support**  \\nAs mental health becomes an increasingly crucial area of
+      focus, AI agents are emerging as supplementary tools for psychological support.
+      An article could explore the role of AI in providing real-time assistance, stigma
+      reduction, and accessibility to mental health resources. By sharing success
+      stories and evidence from trials, the piece can encapsulate the potential for
+      AI agents to act as companions that offer kindness and empathy, alongside professional
+      support. This discussion may ultimately lead to a greater appreciation of AI's
+      capacity to enhance mental well-being in an era where mental health challenges
+      are more prevalent than ever.\\n\\nNotes: Each of these ideas addresses a timely
+      and relevant intersection between technology and human experience, making them
+      compelling subjects for in-depth articles. The potential for engaging readers
+      with real-world applications, ethical considerations, and innovative collaborations
+      ensures that these topics will resonate widely and inspire thoughtful discussion.\\n\\nHuman
+      Feedback:\\nGreat work!\\n\\nImproved Output:\\n- **The Rise of AI Agents in
+      Remote Work Environments**  \\nIn the wake of the pandemic, remote work has
+      become a staple in our daily routines, reshaping how businesses operate globally.
+      AI agents are uniquely positioned to enhance this dynamic, stepping into virtual
+      offices to facilitate seamless communication, task management, and collaborative
+      projects. An article exploring the impact of AI agents in remote settings could
+      investigate how these intelligent assistants optimize productivity, reduce operational
+      costs, and improve employee morale by mitigating the isolation often felt in
+      remote work. The journey of AI\u2014from basic scheduling tools to multifunctional
+      virtual colleagues\u2014offers a captivating narrative on technology's role
+      in redefining our professional landscape and fostering human connections in
+      digital spaces.\\n\\n- **Ethical Implications of AI Decision-Making**  \\nAs
+      AI systems increasingly influence critical decision-making in various sectors
+      such as healthcare, finance, and criminal justice, the ethical implications
+      become a hotbed for discussion. A thorough investigation into the moral dilemmas
+      surrounding AI could scrutinize issues such as system biases, data privacy,
+      and the ambiguity of accountability for AI-driven outcomes. This article could
+      engage with thought leaders and ethicists to illuminate the pressing need for
+      ethical frameworks and governance models that ensure AI technologies promote
+      equity and are designed to serve human interests, fostering a society where
+      trust in AI can flourish.\\n\\n- **AI Agents as Creative Collaborators**  \\nThe
+      canvas of creativity is expanding with the emergence of AI agents as collaborators
+      in artistic domains like visual arts, music production, and literary composition.
+      An engaging article could celebrate the symbiotic relationship between human
+      creators and AI, illustrating how these intelligent systems are not mere tools
+      but creative partners that inspire innovation. By profiling groundbreaking collaborations
+      where AI and human artists co-create, this piece would delve into the possibilities
+      that arise when technology enhances human expression, evolving the narrative
+      around creativity as a shared endeavor rather than a solitary pursuit.\\n\\n-
+      **Personalized Learning Experiences through AI Agents**  \\nEducation is at
+      a transformational crossroads, with AI agents revolutionizing how students learn
+      through personalized educational experiences. A compelling article could explore
+      how these intelligent systems adapt learning materials to meet each student's
+      unique needs, thereby moving away from traditional, uniform teaching methods.
+      Interviews with educators and students could reveal powerful testimonials that
+      attest to the positive effects of AI-driven personalized learning, including
+      improved engagement and academic success, establishing a strong argument for
+      the integration of intelligent technologies in classrooms everywhere.\\n\\n-
+      **The Future of AI in Mental Health Support**  \\nAs society increasingly acknowledges
+      mental health issues, AI agents are emerging as vital tools in providing mental
+      health support and resources. An insightful article could examine the potential
+      of AI as a supplemental resource for individuals seeking emotional assistance,
+      highlighting innovations in real-time supportive interactions and stigma reduction.
+      By showcasing case studies of successful AI applications in therapy, the piece
+      would underscore the transformative role these technologies can play in making
+      mental health care accessible and efficient, positioning AI not only as a technological
+      advancement but as a crucial ally in promoting overall well-being in modern
+      life.\\n\\nNotes: Each idea serves as a portal into crucial conversations about
+      technology's role in human experiences, categorized within a contemporary context.
+      The integration of personal stories, expert interviews, and ethical considerations
+      enriches these topics, ensuring they resonate widely, inspire curiosity, and
+      engage readers in meaningful dialogue. This comprehensive approach will enhance
+      the overall quality and relevance of the articles while appealing to a diverse
+      audience.\\n\\n------------------------------------------------\\n\\nPlease
+      provide:\\n- Provide a list of clear, actionable instructions derived from the
+      Human Feedbacks to enhance the Agent's performance. Analyze the differences
+      between Initial Outputs and Improved Outputs to generate specific action items
+      for future tasks. Ensure all key and specificpoints from the human feedback
+      are incorporated into these instructions.\\n- A score from 0 to 10 evaluating
+      on completion, quality, and overall performance from the improved output to
+      the initial output based on the human feedback\\n\"}],\"model\":\"gpt-4.1-mini\",\"response_format\":{\"type\":\"json_schema\",\"json_schema\":{\"schema\":{\"properties\":{\"suggestions\":{\"description\":\"List
+      of clear, actionable instructions derived from the Human Feedbacks to enhance
+      the Agent's performance. Analyze the differences between Initial Outputs and
+      Improved Outputs to generate specific action items for future tasks. Ensure
+      all key and specific points from the human feedback are incorporated into these
+      instructions.\",\"items\":{\"type\":\"string\"},\"title\":\"Suggestions\",\"type\":\"array\"},\"quality\":{\"description\":\"A
+      score from 0 to 10 evaluating on completion, quality, and overall performance
+      from the improved output to the initial output based on the human feedback.\",\"title\":\"Quality\",\"type\":\"number\"},\"final_summary\":{\"description\":\"A
+      step by step action items to improve the next Agent based on the human-feedback
+      and improved output.\",\"title\":\"Final Summary\",\"type\":\"string\"}},\"required\":[\"suggestions\",\"quality\",\"final_summary\"],\"title\":\"TrainingTaskEvaluation\",\"type\":\"object\",\"additionalProperties\":false},\"name\":\"TrainingTaskEvaluation\",\"strict\":true}},\"stream\":false}"
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '17792'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=_ywFekSfflLNT4n4CAra7U6FQ81CokpzhqfwrjWPQmA-1761873710747-0.0.1.1-604800000;
+        __cf_bm=hk.dUrCne4r20h6mq0lNOA1fyN8qNNN2wDRfIxVmRrg-1761873710-1.0.1.1-DYHNFwh3pzCCnEiUAjr8eQb_Le1gJp6eIBCaTHjkXuGf6lL2exJ6dig0Rv.r1XAEkni.IO8K2OiJiY9S1Pd29Hf1NsRPKkYXAYc8brdr5Zs
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//nFZNb9tGEL37Vwx46YUSLNmJXd+CIgFyKAIUDYIiMoTR7pCcZrm72VnK
+        VgP/92KWlEQnDlD0Ypmcna83783y2wVAxba6g8p0mE0f3eK3T3/dJGc+pBV/5NSu3339Y/X+9092
+        f9W8G6paPcLubzL56LU0oY+OMgc/mk0izKRRVzevV7c3VzerVTH0wZJTtzbmxfVytejZ82J9uX61
+        uLxerK4n9y6wIanu4PMFAMC38lcL9ZYeqzu4rI9vehLBlqq70yGAKgWnbyoUYcnoc1WfjSb4TL7U
+        /m1TydC2JFq5bKq7z5vqvTdusAQSyXDDBugRtTkB9BYSoVs8hOQsGBQCyYNlEsgByHfoDUHuCEwi
+        yzt2nA/FzVLMHYSmGDFlNo6ALaEsN1VdkoYUQ8JM0JMv5ehxHzLuHIHii55JaogpKPRSQ0iQQ3AC
+        iRzt0edSBZoOcohs9CmmsGer/t4kyuWfTI95zPrGWrC8pyQEe6aHGNhnARlMByjAPlPS9wIPnDug
+        x0hJEw9CacrfhaHtMjhCS2mCIbGW0BF4TAkz76lg4MhbwCF3IXE+nCpIJAKUOzboapBgWH/Vgfqg
+        QKDTqoUtaTAFhh6jY8PZHTRhosaRyYCwQ6cTsMVbIUvUkZexAHQH4Qnut7NRWRKTOI6RdwfgMn/2
+        LXCvaaacTUjQDHlI6rEnF6LOaSSFholBScXo1A1NhuBLM3Rs9aMQ9CERkG+x1fjquuc9W3Do2wFb
+        LQgz2IQPUoKmAqsOYj7YXwT8oPWP2bmPIWV9PnGpENiHTKJDkqHvMRWWaviJAgM6/ofGsEJZ2VYI
+        CewhU+oL/yZmmXGC5x6nwkorpEAcUx8xyihfpIYmmEEUCnK4U3oXXD2XIGHIjj3J2F/BxlJGdtME
+        xybtSS8xhRgE3URHpRklmOQ8QuGF2y7rlO/rTfVVe8yHTXV3W2+qhj267QiGvttUfwYFL4U9Hct+
+        02qoMOQ4KNHJS2mmo5EWwsErLD/uhqNm/q9Q2xSGiUmWxQxSUrF/tnDGwckS3gytgj4NrKBx1HGk
+        pNWp6o50njbLCP1J0iHB16FQpEmhHzU9ym6UuVbFujV0zb24z5bw9ixE/G9KxlKczHfTUbX1d5Kd
+        BruEo1rPKgmwe0lMJynvyxmDsQz1rCJKJHkJzxVSRNFx2znlzneUR13v+nCm+lkGS/iwp4TOzYle
+        1t+c5vMhHemtGwz9uFrqZ4tmBOyBnFsUSpCdr+YdCllN0w09emiI7A7Nl+WmeppfcYmaQVDvWT84
+        NzOg1xulJNLL9X6yPJ2uUxfamMJOvnNV8bB0W2VD8Hp1Sg6xKtanC4D7cm0Pz27iKqbQx7zN4QuV
+        dOtf1zdjwOr8vTAz376erDlkdGfD1Xp1Vb8QcjvCKbO7vzJoOrKzoJfXt6cmdJjhbLu8mPX+Y0kv
+        hR/7Z9/Oovw0/NlgDMVMdhtVRuZ52+djiXRf/OzYCetScCWqY0PbzJR0HpYaHNz4oVPJQTL124Z9
+        SykmHr92mri9NuvbV6vm9vW6uni6+BcAAP//AwBX4Bvy/AkAAA==
+    headers:
+      CF-RAY:
+      - 996f56845b23eda4-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 01:21:54 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '3815'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '3846'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149995870'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149995867'
+      x-ratelimit-reset-project-tokens:
+      - 1ms
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 1ms
+      x-request-id:
+      - req_9a753d9290c642af94be4e13bec9b6d8
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_json_property_without_output_json.yaml b/lib/crewai/tests/cassettes/test_json_property_without_output_json.yaml
--- a/lib/crewai/tests/cassettes/test_json_property_without_output_json.yaml
+++ b/lib/crewai/tests/cassettes/test_json_property_without_output_json.yaml
@@ -1,35 +1,137 @@
 interactions:
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Scorer. You''re an
-      expert scorer, specialized in scoring titles.\nYour personal goal is: Score
-      the title\nTo give my best complete final answer to the task use the exact following
+    body: '{"trace_id": "4ced1ade-0d34-4d28-a47d-61011b1f3582", "execution_type":
+      "crew", "user_identifier": null, "execution_context": {"crew_fingerprint": null,
+      "crew_name": "crew", "flow_name": null, "crewai_version": "1.2.1", "privacy_level":
+      "standard"}, "execution_metadata": {"expected_duration_estimate": 300, "agent_count":
+      0, "task_count": 0, "flow_method_count": 0, "execution_started_at": "2025-10-31T07:25:08.937105+00:00"},
+      "ephemeral_trace_id": "4ced1ade-0d34-4d28-a47d-61011b1f3582"}'
+    headers:
+      Accept:
+      - '*/*'
+      Accept-Encoding:
+      - gzip, deflate, zstd
+      Connection:
+      - keep-alive
+      Content-Length:
+      - '488'
+      Content-Type:
+      - application/json
+      User-Agent:
+      - CrewAI-CLI/1.2.1
+      X-Crewai-Organization-Id:
+      - 73c2b193-f579-422c-84c7-76a39a1da77f
+      X-Crewai-Version:
+      - 1.2.1
+    method: POST
+    uri: https://app.crewai.com/crewai_plus/api/v1/tracing/ephemeral/batches
+  response:
+    body:
+      string: '{"id":"8657c7bd-19a7-4873-b561-7cfc910b1b81","ephemeral_trace_id":"4ced1ade-0d34-4d28-a47d-61011b1f3582","execution_type":"crew","crew_name":"crew","flow_name":null,"status":"running","duration_ms":null,"crewai_version":"1.2.1","total_events":0,"execution_context":{"crew_fingerprint":null,"crew_name":"crew","flow_name":null,"crewai_version":"1.2.1","privacy_level":"standard"},"created_at":"2025-10-31T07:25:09.569Z","updated_at":"2025-10-31T07:25:09.569Z","access_code":"TRACE-7f02e40cd9","user_identifier":null}'
+    headers:
+      Connection:
+      - keep-alive
+      Content-Length:
+      - '515'
+      Content-Type:
+      - application/json; charset=utf-8
+      Date:
+      - Fri, 31 Oct 2025 07:25:09 GMT
+      cache-control:
+      - no-store
+      content-security-policy:
+      - 'default-src ''self'' *.app.crewai.com app.crewai.com; script-src ''self''
+        ''unsafe-inline'' *.app.crewai.com app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts
+        https://www.gstatic.com https://run.pstmn.io https://apis.google.com https://apis.google.com/js/api.js
+        https://accounts.google.com https://accounts.google.com/gsi/client https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css.map
+        https://*.google.com https://docs.google.com https://slides.google.com https://js.hs-scripts.com
+        https://js.sentry-cdn.com https://browser.sentry-cdn.com https://www.googletagmanager.com
+        https://js-na1.hs-scripts.com https://js.hubspot.com http://js-na1.hs-scripts.com
+        https://bat.bing.com https://cdn.amplitude.com https://cdn.segment.com https://d1d3n03t5zntha.cloudfront.net/
+        https://descriptusercontent.com https://edge.fullstory.com https://googleads.g.doubleclick.net
+        https://js.hs-analytics.net https://js.hs-banner.com https://js.hsadspixel.net
+        https://js.hscollectedforms.net https://js.usemessages.com https://snap.licdn.com
+        https://static.cloudflareinsights.com https://static.reo.dev https://www.google-analytics.com
+        https://share.descript.com/; style-src ''self'' ''unsafe-inline'' *.app.crewai.com
+        app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts; img-src ''self'' data:
+        *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com https://dashboard.tools.crewai.com
+        https://cdn.jsdelivr.net https://forms.hsforms.com https://track.hubspot.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://www.google.com
+        https://www.google.com.br; font-src ''self'' data: *.app.crewai.com app.crewai.com;
+        connect-src ''self'' *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com
+        https://connect.useparagon.com/ https://zeus.useparagon.com/* https://*.useparagon.com/*
+        https://run.pstmn.io https://connect.tools.crewai.com/ https://*.sentry.io
+        https://www.google-analytics.com https://edge.fullstory.com https://rs.fullstory.com
+        https://api.hubspot.com https://forms.hscollectedforms.net https://api.hubapi.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://google.com/pagead/form-data/16713662509
+        https://google.com/ccm/form-data/16713662509 https://www.google.com/ccm/collect
+        https://worker-actionkit.tools.crewai.com https://api.reo.dev; frame-src ''self''
+        *.app.crewai.com app.crewai.com https://connect.useparagon.com/ https://zeus.tools.crewai.com
+        https://zeus.useparagon.com/* https://connect.tools.crewai.com/ https://docs.google.com
+        https://drive.google.com https://slides.google.com https://accounts.google.com
+        https://*.google.com https://app.hubspot.com/ https://td.doubleclick.net https://www.googletagmanager.com/
+        https://www.youtube.com https://share.descript.com'
+      etag:
+      - W/"684f9dff2cfefa325ac69ea38dba2309"
+      expires:
+      - '0'
+      permissions-policy:
+      - camera=(), microphone=(self), geolocation=()
+      pragma:
+      - no-cache
+      referrer-policy:
+      - strict-origin-when-cross-origin
+      strict-transport-security:
+      - max-age=63072000; includeSubDomains
+      vary:
+      - Accept
+      x-content-type-options:
+      - nosniff
+      x-frame-options:
+      - SAMEORIGIN
+      x-permitted-cross-domain-policies:
+      - none
+      x-request-id:
+      - 630cda16-c991-4ed0-b534-16c03eb2ffca
+      x-runtime:
+      - '0.072382'
+      x-xss-protection:
+      - 1; mode=block
+    status:
+      code: 201
+      message: Created
+- request:
+    body: '{"messages":[{"role":"system","content":"You are Scorer. You''re an expert
+      scorer, specialized in scoring titles.\nYour personal goal is: Score the title\nTo
+      give my best complete final answer to the task respond using the exact following
       format:\n\nThought: I now can give a great answer\nFinal Answer: Your final
       answer must be the great and the most complete as possible, it must be outcome
-      described.\n\nI MUST use these formats, my job depends on it!"}, {"role": "user",
-      "content": "\nCurrent Task: Give me an integer score between 1-5 for the following
-      title: ''The impact of AI in the future of work''\n\nThis is the expect criteria
-      for your final answer: The score of the title.\nyou MUST return the actual complete
-      content as the final answer, not a summary.\n\nBegin! This is VERY important
-      to you, use the tools available and give your best Final Answer, your job depends
-      on it!\n\nThought:"}], "model": "gpt-4o"}'
+      described.\n\nI MUST use these formats, my job depends on it!"},{"role":"user","content":"\nCurrent
+      Task: Give me an integer score between 1-5 for the following title: ''The impact
+      of AI in the future of work''\n\nThis is the expected criteria for your final
+      answer: The score of the title.\nyou MUST return the actual complete content
+      as the final answer, not a summary.\nEnsure your final answer contains only
+      the content in the following format: {\n  \"properties\": {\n    \"score\":
+      {\n      \"title\": \"Score\",\n      \"type\": \"integer\"\n    }\n  },\n  \"required\":
+      [\n    \"score\"\n  ],\n  \"title\": \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\":
+      false\n}\n\nEnsure the final output does not include any code block markers
+      like ```json or ```python.\n\nBegin! This is VERY important to you, use the
+      tools available and give your best Final Answer, your job depends on it!\n\nThought:"}],"model":"gpt-4.1-mini"}'
     headers:
       accept:
       - application/json
       accept-encoding:
-      - gzip, deflate
+      - gzip, deflate, zstd
       connection:
       - keep-alive
       content-length:
-      - '915'
+      - '1340'
       content-type:
       - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.47.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
@@ -39,169 +141,373 @@ interactions:
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.11.7
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
-    content: "{\n  \"id\": \"chatcmpl-AB7g417Go7DkGG2YvjkT783QSBFRT\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214484,\n  \"model\": \"gpt-4o-2024-05-13\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": \"I now can give a great answer\\nFinal
-      Answer: 4\",\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      186,\n    \"completion_tokens\": 13,\n    \"total_tokens\": 199,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": \"fp_52a7f40b0b\"\n}\n"
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jFLBbpwwEL3zFaM5LxFQSHa55pReWkXRVlWJkGMP4AZs1zZJq9X+e2XY
+        LGzaSr34MG/e83szc4gAUAosAXnHPB9MH99+Eer++f7z14c9FR+b/acbdptysW9+3AmBm8DQT9+J
+        +zfWFdeD6clLrWaYW2Kegmp6c51ud0WR7CZg0IL6QGuNj/OrNB6kknGWZEWc5HGan+idlpwclvAt
+        AgA4TG8wqgT9xBKSzVtlIOdYS1iemwDQ6j5UkDknnWfK42YBuVae1OT9odNj2/kS7kDpV+BMQStf
+        CBi0IQAw5V7JVupQKYAKHdeWKiwhr9RxLWmpGR0LudTY9yuAKaU9C3OZwjyekOPZfq9bY/WTe0fF
+        RirputoSc1oFq85rgxN6jAAepzGNF8nRWD0YX3v9TNN32Tad9XBZz4KmuxPotWf9Uv+QnIZ7qVcL
+        8kz2bjVo5Ix3JBbqshU2CqlXQLRK/aebv2nPyaVq/0d+ATgn40nUxpKQ/DLx0mYpXO+/2s5Tngyj
+        I/siOdVekg2bENSwsZ9PCt0v52moG6lassbK+a4aU+c82xZps73OMDpGvwEAAP//AwDHX8XpZgMA
+        AA==
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
       CF-RAY:
-      - 8c85fa001c351cf3-GRU
+      - 99716ab4788dea35-FCO
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Tue, 24 Sep 2024 21:48:05 GMT
+      - Fri, 31 Oct 2025 07:25:10 GMT
       Server:
       - cloudflare
+      Set-Cookie:
+      - __cf_bm=S.q8_0ONHDHBHNOJdMZHwJDue9lKhWQHpKuP2lsspx4-1761895510-1.0.1.1-QUDxMm9SVfRT2R188bLcvxUd6SXIBmZgnz3D35UF95nNg8zX5Gzdg2OmU.uo29rqaGatjupcLPNMyhfOqeoyhNQ28Zz1ESSQLq0y70x3IvM;
+        path=/; expires=Fri, 31-Oct-25 07:55:10 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=TvP4GePeQO8E5c_xWNGzJb84f940MFRG_lZ_0hWAc5M-1761895510432-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
       Transfer-Encoding:
       - chunked
       X-Content-Type-Options:
       - nosniff
       access-control-expose-headers:
       - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '187'
+      - '569'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
+      x-envoy-upstream-service-time:
+      - '587'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
       x-ratelimit-limit-requests:
-      - '10000'
+      - '30000'
       x-ratelimit-limit-tokens:
-      - '30000000'
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999700'
       x-ratelimit-remaining-requests:
-      - '9999'
+      - '29999'
       x-ratelimit-remaining-tokens:
-      - '29999781'
+      - '149999700'
+      x-ratelimit-reset-project-tokens:
+      - 0s
       x-ratelimit-reset-requests:
-      - 6ms
+      - 2ms
       x-ratelimit-reset-tokens:
       - 0s
       x-request-id:
-      - req_d5f223e0442a0df22717b3acabffaea0
-    http_version: HTTP/1.1
-    status_code: 200
+      - req_393e029e99d54ab0b4e7c69c5cba099f
+    status:
+      code: 200
+      message: OK
 - request:
-    body: '{"messages": [{"role": "user", "content": "4"}, {"role": "system", "content":
-      "I''m gonna convert this raw text into valid JSON.\n\nThe json should have the
-      following structure, with the following keys:\n{\n    score: int\n}"}], "model":
-      "gpt-4o", "tool_choice": {"type": "function", "function": {"name": "ScoreOutput"}},
-      "tools": [{"type": "function", "function": {"name": "ScoreOutput", "description":
-      "Correctly extracted `ScoreOutput` with all the required parameters with correct
-      types", "parameters": {"properties": {"score": {"title": "Score", "type": "integer"}},
-      "required": ["score"], "type": "object"}}}]}'
+    body: '{"events": [{"event_id": "ea607d3f-c9ff-4aa8-babb-a84eb6d16663", "timestamp":
+      "2025-10-31T07:25:08.935640+00:00", "type": "crew_kickoff_started", "event_data":
+      {"timestamp": "2025-10-31T07:25:08.935640+00:00", "type": "crew_kickoff_started",
+      "source_fingerprint": null, "source_type": null, "fingerprint_metadata": null,
+      "task_id": null, "task_name": null, "agent_id": null, "agent_role": null, "crew_name":
+      "crew", "crew": null, "inputs": null}}, {"event_id": "8e792d78-fe9c-4601-a7b4-7b105fa8fb40",
+      "timestamp": "2025-10-31T07:25:08.937816+00:00", "type": "task_started", "event_data":
+      {"task_description": "Give me an integer score between 1-5 for the following
+      title: ''The impact of AI in the future of work''", "expected_output": "The
+      score of the title.", "task_name": "Give me an integer score between 1-5 for
+      the following title: ''The impact of AI in the future of work''", "context":
+      "", "agent_role": "Scorer", "task_id": "677cf2dd-96a9-4eac-9140-0ecaba9609f7"}},
+      {"event_id": "a2fcdfee-a395-4dc8-99b8-ba3d8d843a70", "timestamp": "2025-10-31T07:25:08.938816+00:00",
+      "type": "agent_execution_started", "event_data": {"agent_role": "Scorer", "agent_goal":
+      "Score the title", "agent_backstory": "You''re an expert scorer, specialized
+      in scoring titles."}}, {"event_id": "b0ba7582-6ea0-4b66-a64a-0a1e38d57502",
+      "timestamp": "2025-10-31T07:25:08.938996+00:00", "type": "llm_call_started",
+      "event_data": {"timestamp": "2025-10-31T07:25:08.938996+00:00", "type": "llm_call_started",
+      "source_fingerprint": null, "source_type": null, "fingerprint_metadata": null,
+      "task_id": "677cf2dd-96a9-4eac-9140-0ecaba9609f7", "task_name": "Give me an
+      integer score between 1-5 for the following title: ''The impact of AI in the
+      future of work''", "agent_id": "8d6e3481-36fa-4fca-9665-977e6d76a969", "agent_role":
+      "Scorer", "from_task": null, "from_agent": null, "model": "gpt-4.1-mini", "messages":
+      [{"role": "system", "content": "You are Scorer. You''re an expert scorer, specialized
+      in scoring titles.\nYour personal goal is: Score the title\nTo give my best
+      complete final answer to the task respond using the exact following format:\n\nThought:
+      I now can give a great answer\nFinal Answer: Your final answer must be the great
+      and the most complete as possible, it must be outcome described.\n\nI MUST use
+      these formats, my job depends on it!"}, {"role": "user", "content": "\nCurrent
+      Task: Give me an integer score between 1-5 for the following title: ''The impact
+      of AI in the future of work''\n\nThis is the expected criteria for your final
+      answer: The score of the title.\nyou MUST return the actual complete content
+      as the final answer, not a summary.\nEnsure your final answer contains only
+      the content in the following format: {\n  \"properties\": {\n    \"score\":
+      {\n      \"title\": \"Score\",\n      \"type\": \"integer\"\n    }\n  },\n  \"required\":
+      [\n    \"score\"\n  ],\n  \"title\": \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\":
+      false\n}\n\nEnsure the final output does not include any code block markers
+      like ```json or ```python.\n\nBegin! This is VERY important to you, use the
+      tools available and give your best Final Answer, your job depends on it!\n\nThought:"}],
+      "tools": null, "callbacks": ["<crewai.utilities.token_counter_callback.TokenCalcHandler
+      object at 0x11da36000>"], "available_functions": null}}, {"event_id": "ab6b168b-d954-494f-ae58-d9ef7a1941dc",
+      "timestamp": "2025-10-31T07:25:10.466669+00:00", "type": "llm_call_completed",
+      "event_data": {"timestamp": "2025-10-31T07:25:10.466669+00:00", "type": "llm_call_completed",
+      "source_fingerprint": null, "source_type": null, "fingerprint_metadata": null,
+      "task_id": "677cf2dd-96a9-4eac-9140-0ecaba9609f7", "task_name": "Give me an
+      integer score between 1-5 for the following title: ''The impact of AI in the
+      future of work''", "agent_id": "8d6e3481-36fa-4fca-9665-977e6d76a969", "agent_role":
+      "Scorer", "from_task": null, "from_agent": null, "messages": [{"role": "system",
+      "content": "You are Scorer. You''re an expert scorer, specialized in scoring
+      titles.\nYour personal goal is: Score the title\nTo give my best complete final
+      answer to the task respond using the exact following format:\n\nThought: I now
+      can give a great answer\nFinal Answer: Your final answer must be the great and
+      the most complete as possible, it must be outcome described.\n\nI MUST use these
+      formats, my job depends on it!"}, {"role": "user", "content": "\nCurrent Task:
+      Give me an integer score between 1-5 for the following title: ''The impact of
+      AI in the future of work''\n\nThis is the expected criteria for your final answer:
+      The score of the title.\nyou MUST return the actual complete content as the
+      final answer, not a summary.\nEnsure your final answer contains only the content
+      in the following format: {\n  \"properties\": {\n    \"score\": {\n      \"title\":
+      \"Score\",\n      \"type\": \"integer\"\n    }\n  },\n  \"required\": [\n    \"score\"\n  ],\n  \"title\":
+      \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\": false\n}\n\nEnsure
+      the final output does not include any code block markers like ```json or ```python.\n\nBegin!
+      This is VERY important to you, use the tools available and give your best Final
+      Answer, your job depends on it!\n\nThought:"}], "response": "Thought: I now
+      can give a great answer\n{\n  \"score\": 4\n}", "call_type": "<LLMCallType.LLM_CALL:
+      ''llm_call''>", "model": "gpt-4.1-mini"}}, {"event_id": "0b8a17b6-e7d2-464d-a969-56dd705a40ef",
+      "timestamp": "2025-10-31T07:25:10.466933+00:00", "type": "agent_execution_completed",
+      "event_data": {"agent_role": "Scorer", "agent_goal": "Score the title", "agent_backstory":
+      "You''re an expert scorer, specialized in scoring titles."}}, {"event_id": "b835b8e7-992b-4364-9ff8-25c81203ef77",
+      "timestamp": "2025-10-31T07:25:10.467175+00:00", "type": "task_completed", "event_data":
+      {"task_description": "Give me an integer score between 1-5 for the following
+      title: ''The impact of AI in the future of work''", "task_name": "Give me an
+      integer score between 1-5 for the following title: ''The impact of AI in the
+      future of work''", "task_id": "677cf2dd-96a9-4eac-9140-0ecaba9609f7", "output_raw":
+      "Thought: I now can give a great answer\n{\n  \"score\": 4\n}", "output_format":
+      "OutputFormat.PYDANTIC", "agent_role": "Scorer"}}, {"event_id": "a9973b74-9ca6-46c3-b219-0b11ffa9e210",
+      "timestamp": "2025-10-31T07:25:10.469421+00:00", "type": "crew_kickoff_completed",
+      "event_data": {"timestamp": "2025-10-31T07:25:10.469421+00:00", "type": "crew_kickoff_completed",
+      "source_fingerprint": null, "source_type": null, "fingerprint_metadata": null,
+      "task_id": null, "task_name": null, "agent_id": null, "agent_role": null, "crew_name":
+      "crew", "crew": null, "output": {"description": "Give me an integer score between
+      1-5 for the following title: ''The impact of AI in the future of work''", "name":
+      "Give me an integer score between 1-5 for the following title: ''The impact
+      of AI in the future of work''", "expected_output": "The score of the title.",
+      "summary": "Give me an integer score between 1-5 for the following...", "raw":
+      "Thought: I now can give a great answer\n{\n  \"score\": 4\n}", "pydantic":
+      {}, "json_dict": null, "agent": "Scorer", "output_format": "pydantic"}, "total_tokens":
+      300}}], "batch_metadata": {"events_count": 8, "batch_sequence": 1, "is_final_batch":
+      false}}'
     headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
+      Accept:
+      - '*/*'
+      Accept-Encoding:
+      - gzip, deflate, zstd
+      Connection:
       - keep-alive
-      content-length:
-      - '615'
-      content-type:
+      Content-Length:
+      - '7336'
+      Content-Type:
       - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
+      User-Agent:
+      - CrewAI-CLI/1.2.1
+      X-Crewai-Organization-Id:
+      - 73c2b193-f579-422c-84c7-76a39a1da77f
+      X-Crewai-Version:
+      - 1.2.1
     method: POST
-    uri: https://api.openai.com/v1/chat/completions
+    uri: https://app.crewai.com/crewai_plus/api/v1/tracing/ephemeral/batches/4ced1ade-0d34-4d28-a47d-61011b1f3582/events
   response:
-    content: "{\n  \"id\": \"chatcmpl-AB7g5CniMQJ0VGcH8UKTUvm5YmLv8\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214485,\n  \"model\": \"gpt-4o-2024-05-13\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": null,\n        \"tool_calls\": [\n          {\n
-      \           \"id\": \"call_a5sTjq3Ebf2ePCGDCPDYn6ob\",\n            \"type\":
-      \"function\",\n            \"function\": {\n              \"name\": \"ScoreOutput\",\n
-      \             \"arguments\": \"{\\\"score\\\":4}\"\n            }\n          }\n
-      \       ],\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      100,\n    \"completion_tokens\": 5,\n    \"total_tokens\": 105,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": \"fp_e375328146\"\n}\n"
+    body:
+      string: '{"events_created":8,"ephemeral_trace_batch_id":"8657c7bd-19a7-4873-b561-7cfc910b1b81"}'
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85fa03d9621cf3-GRU
       Connection:
       - keep-alive
-      Content-Encoding:
-      - gzip
+      Content-Length:
+      - '86'
       Content-Type:
-      - application/json
+      - application/json; charset=utf-8
       Date:
-      - Tue, 24 Sep 2024 21:48:05 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
+      - Fri, 31 Oct 2025 07:25:11 GMT
+      cache-control:
+      - no-store
+      content-security-policy:
+      - 'default-src ''self'' *.app.crewai.com app.crewai.com; script-src ''self''
+        ''unsafe-inline'' *.app.crewai.com app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts
+        https://www.gstatic.com https://run.pstmn.io https://apis.google.com https://apis.google.com/js/api.js
+        https://accounts.google.com https://accounts.google.com/gsi/client https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css.map
+        https://*.google.com https://docs.google.com https://slides.google.com https://js.hs-scripts.com
+        https://js.sentry-cdn.com https://browser.sentry-cdn.com https://www.googletagmanager.com
+        https://js-na1.hs-scripts.com https://js.hubspot.com http://js-na1.hs-scripts.com
+        https://bat.bing.com https://cdn.amplitude.com https://cdn.segment.com https://d1d3n03t5zntha.cloudfront.net/
+        https://descriptusercontent.com https://edge.fullstory.com https://googleads.g.doubleclick.net
+        https://js.hs-analytics.net https://js.hs-banner.com https://js.hsadspixel.net
+        https://js.hscollectedforms.net https://js.usemessages.com https://snap.licdn.com
+        https://static.cloudflareinsights.com https://static.reo.dev https://www.google-analytics.com
+        https://share.descript.com/; style-src ''self'' ''unsafe-inline'' *.app.crewai.com
+        app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts; img-src ''self'' data:
+        *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com https://dashboard.tools.crewai.com
+        https://cdn.jsdelivr.net https://forms.hsforms.com https://track.hubspot.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://www.google.com
+        https://www.google.com.br; font-src ''self'' data: *.app.crewai.com app.crewai.com;
+        connect-src ''self'' *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com
+        https://connect.useparagon.com/ https://zeus.useparagon.com/* https://*.useparagon.com/*
+        https://run.pstmn.io https://connect.tools.crewai.com/ https://*.sentry.io
+        https://www.google-analytics.com https://edge.fullstory.com https://rs.fullstory.com
+        https://api.hubspot.com https://forms.hscollectedforms.net https://api.hubapi.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://google.com/pagead/form-data/16713662509
+        https://google.com/ccm/form-data/16713662509 https://www.google.com/ccm/collect
+        https://worker-actionkit.tools.crewai.com https://api.reo.dev; frame-src ''self''
+        *.app.crewai.com app.crewai.com https://connect.useparagon.com/ https://zeus.tools.crewai.com
+        https://zeus.useparagon.com/* https://connect.tools.crewai.com/ https://docs.google.com
+        https://drive.google.com https://slides.google.com https://accounts.google.com
+        https://*.google.com https://app.hubspot.com/ https://td.doubleclick.net https://www.googletagmanager.com/
+        https://www.youtube.com https://share.descript.com'
+      etag:
+      - W/"be223998b84365d3a863f942c880adfb"
+      expires:
+      - '0'
+      permissions-policy:
+      - camera=(), microphone=(self), geolocation=()
+      pragma:
+      - no-cache
+      referrer-policy:
+      - strict-origin-when-cross-origin
+      strict-transport-security:
+      - max-age=63072000; includeSubDomains
+      vary:
+      - Accept
+      x-content-type-options:
       - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '137'
-      openai-version:
-      - '2020-10-01'
+      x-frame-options:
+      - SAMEORIGIN
+      x-permitted-cross-domain-policies:
+      - none
+      x-request-id:
+      - 9c19d6df-9190-4764-afed-f3444939d2e4
+      x-runtime:
+      - '0.123911'
+      x-xss-protection:
+      - 1; mode=block
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"status": "completed", "duration_ms": 2305, "final_event_count": 8}'
+    headers:
+      Accept:
+      - '*/*'
+      Accept-Encoding:
+      - gzip, deflate, zstd
+      Connection:
+      - keep-alive
+      Content-Length:
+      - '68'
+      Content-Type:
+      - application/json
+      User-Agent:
+      - CrewAI-CLI/1.2.1
+      X-Crewai-Organization-Id:
+      - 73c2b193-f579-422c-84c7-76a39a1da77f
+      X-Crewai-Version:
+      - 1.2.1
+    method: PATCH
+    uri: https://app.crewai.com/crewai_plus/api/v1/tracing/ephemeral/batches/4ced1ade-0d34-4d28-a47d-61011b1f3582/finalize
+  response:
+    body:
+      string: '{"id":"8657c7bd-19a7-4873-b561-7cfc910b1b81","ephemeral_trace_id":"4ced1ade-0d34-4d28-a47d-61011b1f3582","execution_type":"crew","crew_name":"crew","flow_name":null,"status":"completed","duration_ms":2305,"crewai_version":"1.2.1","total_events":8,"execution_context":{"crew_name":"crew","flow_name":null,"privacy_level":"standard","crewai_version":"1.2.1","crew_fingerprint":null},"created_at":"2025-10-31T07:25:09.569Z","updated_at":"2025-10-31T07:25:11.837Z","access_code":"TRACE-7f02e40cd9","user_identifier":null}'
+    headers:
+      Connection:
+      - keep-alive
+      Content-Length:
+      - '517'
+      Content-Type:
+      - application/json; charset=utf-8
+      Date:
+      - Fri, 31 Oct 2025 07:25:11 GMT
+      cache-control:
+      - no-store
+      content-security-policy:
+      - 'default-src ''self'' *.app.crewai.com app.crewai.com; script-src ''self''
+        ''unsafe-inline'' *.app.crewai.com app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts
+        https://www.gstatic.com https://run.pstmn.io https://apis.google.com https://apis.google.com/js/api.js
+        https://accounts.google.com https://accounts.google.com/gsi/client https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css.map
+        https://*.google.com https://docs.google.com https://slides.google.com https://js.hs-scripts.com
+        https://js.sentry-cdn.com https://browser.sentry-cdn.com https://www.googletagmanager.com
+        https://js-na1.hs-scripts.com https://js.hubspot.com http://js-na1.hs-scripts.com
+        https://bat.bing.com https://cdn.amplitude.com https://cdn.segment.com https://d1d3n03t5zntha.cloudfront.net/
+        https://descriptusercontent.com https://edge.fullstory.com https://googleads.g.doubleclick.net
+        https://js.hs-analytics.net https://js.hs-banner.com https://js.hsadspixel.net
+        https://js.hscollectedforms.net https://js.usemessages.com https://snap.licdn.com
+        https://static.cloudflareinsights.com https://static.reo.dev https://www.google-analytics.com
+        https://share.descript.com/; style-src ''self'' ''unsafe-inline'' *.app.crewai.com
+        app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts; img-src ''self'' data:
+        *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com https://dashboard.tools.crewai.com
+        https://cdn.jsdelivr.net https://forms.hsforms.com https://track.hubspot.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://www.google.com
+        https://www.google.com.br; font-src ''self'' data: *.app.crewai.com app.crewai.com;
+        connect-src ''self'' *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com
+        https://connect.useparagon.com/ https://zeus.useparagon.com/* https://*.useparagon.com/*
+        https://run.pstmn.io https://connect.tools.crewai.com/ https://*.sentry.io
+        https://www.google-analytics.com https://edge.fullstory.com https://rs.fullstory.com
+        https://api.hubspot.com https://forms.hscollectedforms.net https://api.hubapi.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://google.com/pagead/form-data/16713662509
+        https://google.com/ccm/form-data/16713662509 https://www.google.com/ccm/collect
+        https://worker-actionkit.tools.crewai.com https://api.reo.dev; frame-src ''self''
+        *.app.crewai.com app.crewai.com https://connect.useparagon.com/ https://zeus.tools.crewai.com
+        https://zeus.useparagon.com/* https://connect.tools.crewai.com/ https://docs.google.com
+        https://drive.google.com https://slides.google.com https://accounts.google.com
+        https://*.google.com https://app.hubspot.com/ https://td.doubleclick.net https://www.googletagmanager.com/
+        https://www.youtube.com https://share.descript.com'
+      etag:
+      - W/"bff97e21bd1971750dcfdb102fba9dcd"
+      expires:
+      - '0'
+      permissions-policy:
+      - camera=(), microphone=(self), geolocation=()
+      pragma:
+      - no-cache
+      referrer-policy:
+      - strict-origin-when-cross-origin
       strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '30000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '29999947'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 0s
+      - max-age=63072000; includeSubDomains
+      vary:
+      - Accept
+      x-content-type-options:
+      - nosniff
+      x-frame-options:
+      - SAMEORIGIN
+      x-permitted-cross-domain-policies:
+      - none
       x-request-id:
-      - req_f4a8f8fa4736d7f903e91433ec9ff69a
-    http_version: HTTP/1.1
-    status_code: 200
+      - 2b6cd38d-78fa-4676-94ff-80e3bcf48a03
+      x-runtime:
+      - '0.064858'
+      x-xss-protection:
+      - 1; mode=block
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_long_term_memory_with_memory_flag.yaml b/lib/crewai/tests/cassettes/test_long_term_memory_with_memory_flag.yaml
--- a/lib/crewai/tests/cassettes/test_long_term_memory_with_memory_flag.yaml
+++ b/lib/crewai/tests/cassettes/test_long_term_memory_with_memory_flag.yaml
@@ -1649,4 +1649,784 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: "{\"messages\":[{\"role\":\"system\",\"content\":\"Convert all responses
+      into valid JSON output.\"},{\"role\":\"user\",\"content\":\"Assess the quality
+      of the task completed based on the description, expected output, and actual
+      results.\\n\\nTask Description:\\nResearch a topic to teach a kid aged 6 about
+      math.\\n\\nExpected Output:\\nA topic, explanation, angle, and examples.\\n\\nActual
+      Output:\\nI now can give a great answer  \\nFinal Answer: \\n\\n**Topic: Introduction
+      to Basic Addition**\\n\\n**Explanation:**\\nBasic addition is about combining
+      two or more groups of things together to find out how many there are in total.
+      It's one of the most fundamental concepts in math and is a building block for
+      all other math skills. Teaching addition to a 6-year-old involves using simple
+      numbers and relatable examples that help them visualize and understand the concept
+      of adding together.\\n\\n**Angle:**\\nTo make the concept of addition fun and
+      engaging, we can use everyday objects that a child is familiar with, such as
+      toys, fruits, or drawing items. Incorporating visuals and interactive elements
+      will keep their attention and help reinforce the idea of combining numbers.\\n\\n**Examples:**\\n\\n1.
+      **Using Objects:**\\n   - **Scenario:** Let\u2019s say you have 2 apples and
+      your friend gives you 3 more apples.\\n   - **Visual**: Arrange the apples in
+      front of the child.\\n   - **Question:** \\\"How many apples do you have now?\\\"\\n
+      \  - **Calculation:** 2 apples (your apples) + 3 apples (friend's apples) =
+      5 apples.  \\n   - **Conclusion:** \\\"You now have 5 apples!\\\"\\n\\n2. **Drawing
+      Pictures:**\\n   - **Scenario:** Draw 4 stars on one side of the paper and 2
+      stars on the other side.\\n   - **Activity:** Ask the child to count the stars
+      in the first group and then the second group.\\n   - **Question:** \\\"If we
+      put them together, how many stars do we have?\\\"\\n   - **Calculation:** 4
+      stars + 2 stars = 6 stars.  \\n   - **Conclusion:** \\\"You drew 6 stars all
+      together!\\\"\\n\\n3. **Story Problems:**\\n   - **Scenario:** \\\"You have
+      5 toy cars, and you buy 3 more from the store. How many cars do you have?\\\"\\n
+      \  - **Interaction:** Create a fun story around the toy cars (perhaps the cars
+      are going on an adventure).\\n   - **Calculation:** 5 toy cars + 3 toy cars
+      = 8 toy cars.  \\n   - **Conclusion:** \\\"You now have a total of 8 toy cars
+      for your adventure!\\\"\\n\\n4. **Games:**\\n   - **Activity:** Play a simple
+      game where you roll a pair of dice. Each die shows a number.\\n   - **Task:**
+      Ask the child to add the numbers on the dice together.\\n   - **Example:** If
+      one die shows 2 and the other shows 4, the child will say \u201C2 + 4 = 6!\u201D\\n
+      \  - **Conclusion:** \u201CWhoever gets the highest number wins a point!\u201D\\n\\nIn
+      summary, when teaching a 6-year-old about basic addition, it is essential to
+      use simple numbers, real-life examples, visual aids, and engaging activities.
+      This ensures the child can grasp the concept while having a fun learning experience.
+      Making math relatable to their world helps build a strong foundation for their
+      future learning!\\n\\nPlease provide:\\n- Bullet points suggestions to improve
+      future similar tasks\\n- A score from 0 to 10 evaluating on completion, quality,
+      and overall performance- Entities extracted from the task output, if any, their
+      type, description, and relationships\"}],\"model\":\"gpt-4.1-mini\"}"
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '3303'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=Q23zZGhbuNaTNh.RPoM_1O4jWXLFM.KtSgSytn2NO.Q-1744492727869-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//xFZLbxw3DL77VxBz6WXXyG4c2/EtiYM0QNMGtYMCzQY2LXFmFGukichZ
+        exD4vxeU9uU2TQLEaPewGIgi+fHjQ/y8B1A5W51AZVoU0/V++uKPP1+l+nyWfh+fzz+dHp3XMrzs
+        T2e//vz6zS/VRDXi1UcystbaN7HrPYmLoYhNIhRSq7Ojw9nx0fFs9jgLumjJq1rTy/RgfzbtXHDT
+        +aP5k+mjg+nsYKXeRmeIqxN4vwcA8Dn/K9Bg6bY6gUeT9UlHzNhQdbK5BFCl6PWkQmbHgkGqyVZo
+        YhAKGfvl5eVHjmERPi8CwKKiJfoBNYyFGtRDPWYTE+nJ08n6yMSuoyCsp4vqvCUQ5Gu4QYYVF2Tz
+        V6KWArsl+REwWMC+T7FPDkVP6pgA4XA6EqZp9BZwsI6CoX1Qm3GQfhBwwfjBEgOC8YQJJPbOTIBu
+        e48h450AhQYbFxrA0HiaZGdh6CjFgSGRpyUGAbpFRceA3jWBLNw4aUFaUmNkFHVxWgB4DM2ADYFj
+        YKea2W4ij4JXazcuCCU04pYEHUkbLQMmAh6ahljITuCmdabNh3RryHsKkoMXQtMq6jEOoQHTOm8T
+        hX1440JM4Lo+xSVlqsHEwVu4IujQErgAJgbjmAIxg17ONGUKYOl4QA/o7BqFi0F1ELqo0CQNRoZE
+        FjoMgdL+otLc3k1KJWyVcorfr/P+uqQCEpUKsKRscBySoQyiOGbgQeNl6JMLmSq4iemaWyLJ92qP
+        3BpMlvcX1aaszopbQLhKjmpAZmLW8FfEZtXofbyZDj1kzp2MIBEaHBoqBMIQLCUtfGVj1/7bFJfO
+        EojruRSfxV6UslUJrOsJrpC1FpSwbPMnBu7JuNqZkm/iEogWZFALLKOnXWfvmDRF2oKrdHco2Zl6
+        3lSixHWaIRFavHLeybhr6Jm1gMBtTAI8dB2mUT1f0wiC14Q3ODIwmQxcbX8anLmGRDWl3Ewltx9W
+        uaUgThztJnbV6hvpWPr6ObIz8MxaV2bCZHtNxp5Wza/NeE9miU1y/XqOlPlQD8GiZhI9dChtrl7q
+        BQSHphWlQXOQyd6/Zy53m1Zi6/oC+kMR3k2+iv5Zr/z+C+qXhX74LQ/yr8N/p6XgQsZXu8SbMaKg
+        LXUxsCQUAlwx9S38a9kO9PtXt35fhxXSHZOrWDA1JOubWlYlFi7ZLr+79ef3UXYmmB6aMSYTg91Q
+        pvVp4hCkzGq7Ia2MYpvwxoWG/3MKT4tjeOvyXPwRFs/jCC8enkhpXdryuK7HmDqItc4HiWmEPsUr
+        T51WZn4R6fu76sEpPcuI3hZEP0LoqTP00H0chyTthk19qTBJYbLBLrd2fpz/v6Z+hd03yjBP9UW4
+        W4TLy8vdHS9RPTDqohkG73cEGEKUAjwP0pXkbrNP+thoCfHfVKvaBcftRSLkGHR3ZIl9laV3e/q2
+        6N463FtFqz7FrpcLideU3R09nhd71XZf3koPnh6spBIF/VYwm88PJ1+weGFJ0Hne2X0rg6Ylu9Xd
+        Lsq6WcYdwd5O3P/E8yXbJXYXmu8xvxUYfeXIXvSJrDP3Y95eS/Qxr59fvrbhOQOumNLSGboQR0lz
+        YanGwZctv+KRhbqL2oWGUl6/9ErdXxyY+fGTWX18OK/27vb+AgAA//8DAJ7NZpf5DAAA
+    headers:
+      CF-RAY:
+      - 996fc202cde1ed4f-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:21 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=eO4EWmV.5ZoECkIpnAaY5sSBUK9wFdJdNhKbyTIO478-1761878121-1.0.1.1-gSm1br4q740ZTDBXAgbtjUsTnLBFSxwCDB_yXRSeDzk6jRc5RKIB6wcLCiGioSy3PTKja7Goyu.0qGURIIKtGEBkZGwEMYLmMLerG00d5Rg;
+        path=/; expires=Fri, 31-Oct-25 03:05:21 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=csCCKW32niSRt5uCN_12uTrv6uFSvpNcPlYFnmVIBrg-1761878121273-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '7373'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '7391'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999212'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999210'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_03319b21e980480fbaf69e09f1d9241c
+    status:
+      code: 200
+      message: OK
+- request:
+    body: "{\"messages\":[{\"role\":\"system\",\"content\":\"Convert all responses
+      into valid JSON output.\"},{\"role\":\"user\",\"content\":\"Assess the quality
+      of the task completed based on the description, expected output, and actual
+      results.\\n\\nTask Description:\\nResearch a topic to teach a kid aged 6 about
+      math.\\n\\nExpected Output:\\nA topic, explanation, angle, and examples.\\n\\nActual
+      Output:\\nI now can give a great answer  \\nFinal Answer: \\n\\n**Topic: Introduction
+      to Basic Addition**\\n\\n**Explanation:**\\nBasic addition is about combining
+      two or more groups of things together to find out how many there are in total.
+      It's one of the most fundamental concepts in math and is a building block for
+      all other math skills. Teaching addition to a 6-year-old involves using simple
+      numbers and relatable examples that help them visualize and understand the concept
+      of adding together.\\n\\n**Angle:**\\nTo make the concept of addition fun and
+      engaging, we can use everyday objects that a child is familiar with, such as
+      toys, fruits, or drawing items. Incorporating visuals and interactive elements
+      will keep their attention and help reinforce the idea of combining numbers.\\n\\n**Examples:**\\n\\n1.
+      **Using Objects:**\\n   - **Scenario:** Let\u2019s say you have 2 apples and
+      your friend gives you 3 more apples.\\n   - **Visual**: Arrange the apples in
+      front of the child.\\n   - **Question:** \\\"How many apples do you have now?\\\"\\n
+      \  - **Calculation:** 2 apples (your apples) + 3 apples (friend's apples) =
+      5 apples.  \\n   - **Conclusion:** \\\"You now have 5 apples!\\\"\\n\\n2. **Drawing
+      Pictures:**\\n   - **Scenario:** Draw 4 stars on one side of the paper and 2
+      stars on the other side.\\n   - **Activity:** Ask the child to count the stars
+      in the first group and then the second group.\\n   - **Question:** \\\"If we
+      put them together, how many stars do we have?\\\"\\n   - **Calculation:** 4
+      stars + 2 stars = 6 stars.  \\n   - **Conclusion:** \\\"You drew 6 stars all
+      together!\\\"\\n\\n3. **Story Problems:**\\n   - **Scenario:** \\\"You have
+      5 toy cars, and you buy 3 more from the store. How many cars do you have?\\\"\\n
+      \  - **Interaction:** Create a fun story around the toy cars (perhaps the cars
+      are going on an adventure).\\n   - **Calculation:** 5 toy cars + 3 toy cars
+      = 8 toy cars.  \\n   - **Conclusion:** \\\"You now have a total of 8 toy cars
+      for your adventure!\\\"\\n\\n4. **Games:**\\n   - **Activity:** Play a simple
+      game where you roll a pair of dice. Each die shows a number.\\n   - **Task:**
+      Ask the child to add the numbers on the dice together.\\n   - **Example:** If
+      one die shows 2 and the other shows 4, the child will say \u201C2 + 4 = 6!\u201D\\n
+      \  - **Conclusion:** \u201CWhoever gets the highest number wins a point!\u201D\\n\\nIn
+      summary, when teaching a 6-year-old about basic addition, it is essential to
+      use simple numbers, real-life examples, visual aids, and engaging activities.
+      This ensures the child can grasp the concept while having a fun learning experience.
+      Making math relatable to their world helps build a strong foundation for their
+      future learning!\\n\\nPlease provide:\\n- Bullet points suggestions to improve
+      future similar tasks\\n- A score from 0 to 10 evaluating on completion, quality,
+      and overall performance- Entities extracted from the task output, if any, their
+      type, description, and relationships\"}],\"model\":\"gpt-4.1-mini\",\"response_format\":{\"type\":\"json_schema\",\"json_schema\":{\"schema\":{\"$defs\":{\"Entity\":{\"properties\":{\"name\":{\"description\":\"The
+      name of the entity.\",\"title\":\"Name\",\"type\":\"string\"},\"type\":{\"description\":\"The
+      type of the entity.\",\"title\":\"Type\",\"type\":\"string\"},\"description\":{\"description\":\"Description
+      of the entity.\",\"title\":\"Description\",\"type\":\"string\"},\"relationships\":{\"description\":\"Relationships
+      of the entity.\",\"items\":{\"type\":\"string\"},\"title\":\"Relationships\",\"type\":\"array\"}},\"required\":[\"name\",\"type\",\"description\",\"relationships\"],\"title\":\"Entity\",\"type\":\"object\",\"additionalProperties\":false}},\"properties\":{\"suggestions\":{\"description\":\"Suggestions
+      to improve future similar tasks.\",\"items\":{\"type\":\"string\"},\"title\":\"Suggestions\",\"type\":\"array\"},\"quality\":{\"description\":\"A
+      score from 0 to 10 evaluating on completion, quality, and overall performance,
+      all taking into account the task description, expected output, and the result
+      of the task.\",\"title\":\"Quality\",\"type\":\"number\"},\"entities\":{\"description\":\"Entities
+      extracted from the task output.\",\"items\":{\"$ref\":\"#/$defs/Entity\"},\"title\":\"Entities\",\"type\":\"array\"}},\"required\":[\"suggestions\",\"quality\",\"entities\"],\"title\":\"TaskEvaluation\",\"type\":\"object\",\"additionalProperties\":false},\"name\":\"TaskEvaluation\",\"strict\":true}},\"stream\":false}"
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '4609'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=csCCKW32niSRt5uCN_12uTrv6uFSvpNcPlYFnmVIBrg-1761878121273-0.0.1.1-604800000;
+        __cf_bm=eO4EWmV.5ZoECkIpnAaY5sSBUK9wFdJdNhKbyTIO478-1761878121-1.0.1.1-gSm1br4q740ZTDBXAgbtjUsTnLBFSxwCDB_yXRSeDzk6jRc5RKIB6wcLCiGioSy3PTKja7Goyu.0qGURIIKtGEBkZGwEMYLmMLerG00d5Rg
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//pFbfbxs3DH7PX0HoZRlgB7GTpqnfsg1Ys6JYsbYrsF5g0BJ9p0Ynqvrh
+        xAvyvw+SfLbTpUWKvtzDUSK/7yNF8u4AQGglZiBkh1H2zox//fDPy+OTi5fm/Wvp/ckf9vzT838/
+        xFdn5pU9FaN8gxefSMbh1pHk3hmKmm01S08YKXudPD+bnD8/n0ynxdCzIpOvtS6OT48m415bPZ4e
+        T5+Nj0/Hk4132bGWFMQMPh4AANyVbwZqFd2KGRyPhj89hYAtidn2EIDwbPIfgSHoENFGMdoZJdtI
+        tmC/a0RIbUshIw+NmH1sxKWVJikChIXXtARekV9pugFeQuwIZKeN+ikA3eoQtW2hx9jBteUbQ6ol
+        YA/aRvIUYoDIEFEb9uUq3TqDFnMwWFCM5I8aMWrEhVKw0iGhAdQqZBdG2+ty3VPg5CUFiB1GkJyM
+        gsoLtIVIKLuMokBjK8nFAD17qihQRr0is66BLq1k79hjpOyDQujJxhxPdiSvs58le0hWkc+6qeKZ
+        ZGf150QFT08YkqcHUrQegxv0iey0rOHeVm0BldKZNBrwZHJh1FOF6ZKN4ZtxcmAoBLYlyiJpoyA5
+        tsWnttGzSpLUwLEGeON5pRVB1C4U5A492Vj8kkoSI/sAbKHjm+wWFbpYUQ66oXOeUXaAUrKvhPkB
+        O0Pobf7vUNJRI65Gjfic0Oi4bsTsxagRZKOOmkoB3TXCYk+NmDXiFwxawsWGfUEc167aXueqeZdV
+        KP8VBem1q+dmjbiAZbIKc3rQDKRzwku1abtis8qYJPcLXdDFG860S+pbz8mFmhFt2yLpUlsFnDb0
+        ubpNdqNkyUt+BJ12m4fwPpQ8ValgzSmHy5p4srAo1AqYcK2NCY24uh/tk/+zdIgAh+icofDzQ/rv
+        Bv0vtHpUgL8IzdjoJYGO1AdIGzT1nZg1KOrZhlhqOVMaimwrVuQt3G9z1BboFnMDg8lQxftPdatB
+        JY3bfH7B+DePN5nSGy1j8hTgMET0383879oJ1MZbT7HjQr0j43YZKMkDtCoDqiI9meb0R2i+jezX
+        8MbzwuTEHEZeg/wGz3dD/3iU7fuQz1j0HnOngtKdb2vrrFOk9gxcGKr15obI+cFfa/V02ic/Qvt3
+        7HNKlZYEno3Rtv1qZnPTLe3hEcKXu7YMzuB6L8FkW2xpl2Jtd81nW96x85zabsAABVAug5D6fpgE
+        nkIy8enKnH6nMlf3+xPV0zIFzGPdJmP2DGgtxxo7z/KrjeV+O70Ntzmd4YurYqmtDt3cEwa2eVKH
+        yE4U6/0BwFXZEtKDwS+c597FeeRrKuFenE2rP7HbTnbWk+npxlp64c4wmZ6fjR7xOFeUR3nY2zSE
+        RNmR2t3drSWYlOY9w8Ee7//jecx35a5t+xT3O4PMvY/U3HlSWj7kvDvmKTfnrx3b6lwAi5AXIEnz
+        qMnnXChaYjJ1pxJhHSL186W2LXnndV2slm5+KqfnzybL87OpOLg/+A8AAP//AwBsA26GZwoAAA==
+    headers:
+      CF-RAY:
+      - 996fc2325f81ed4f-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:26 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '4765'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '4807'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999212'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999212'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_847e5f52c37f478b9a56a99113ce7d62
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"input":["Story Problems (toy cars)(Teaching Technique): Using narrative
+      contexts to create relatable math problems for kids."],"model":"text-embedding-3-small","encoding_format":"base64"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '189'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=I1qVn4HwObmpZbHCIfihkYYxjalVXJj8SvhRNmXBdMA-1744492719162-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/embeddings
+  response:
+    body:
+      string: !!binary |
+        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
+    headers:
+      CF-RAY:
+      - 996fc255fec1ed94-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:27 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=pbtvo4SJtDJBflp9bAkwF2aOSGVwUv_1kk.LV5Z1BD8-1761878127-1.0.1.1-Lp8CDqx4ZF41xS5B7q3.TqbAczOcLsXkN.80bpc7MSmUHsJTo1Gi5tuYiz1LC7oWjWQZPhRE5g.z.NwEe_FQPowDCsvKZUUzuNNNL8T1BKE;
+        path=/; expires=Fri, 31-Oct-25 03:05:27 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=OmupBuWMOaSbKIkKtzxmkldESV9dhmGPizW9UT17JA4-1761878127991-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-allow-origin:
+      - '*'
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-model:
+      - text-embedding-3-small
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '175'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      strict-transport-security:
+      - max-age=31536000; includeSubDomains; preload
+      via:
+      - envoy-router-568dcd8c65-kpd72
+      x-envoy-upstream-service-time:
+      - '386'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-requests:
+      - '10000'
+      x-ratelimit-limit-tokens:
+      - '10000000'
+      x-ratelimit-remaining-requests:
+      - '9999'
+      x-ratelimit-remaining-tokens:
+      - '9999972'
+      x-ratelimit-reset-requests:
+      - 6ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_99f475d50b2c411eace09a3706a27f7a
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"input":["Games (dice rolling)(Teaching Activity): Interactive play method
+      to engage children in learning addition through rolling dice and summing the
+      results."],"model":"text-embedding-3-small","encoding_format":"base64"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '224'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=OmupBuWMOaSbKIkKtzxmkldESV9dhmGPizW9UT17JA4-1761878127991-0.0.1.1-604800000;
+        __cf_bm=pbtvo4SJtDJBflp9bAkwF2aOSGVwUv_1kk.LV5Z1BD8-1761878127-1.0.1.1-Lp8CDqx4ZF41xS5B7q3.TqbAczOcLsXkN.80bpc7MSmUHsJTo1Gi5tuYiz1LC7oWjWQZPhRE5g.z.NwEe_FQPowDCsvKZUUzuNNNL8T1BKE
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/embeddings
+  response:
+    body:
+      string: !!binary |
+        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
+    headers:
+      CF-RAY:
+      - 996fcf368d2ced1a-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:44:14 GMT
+      Server:
+      - cloudflare
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-allow-origin:
+      - '*'
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-model:
+      - text-embedding-3-small
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '53'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      strict-transport-security:
+      - max-age=31536000; includeSubDomains; preload
+      via:
+      - envoy-router-568dcd8c65-4dhs8
+      x-envoy-upstream-service-time:
+      - '81'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-requests:
+      - '10000'
+      x-ratelimit-limit-tokens:
+      - '10000000'
+      x-ratelimit-remaining-requests:
+      - '9999'
+      x-ratelimit-remaining-tokens:
+      - '9999963'
+      x-ratelimit-reset-requests:
+      - 6ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_457f533e12f84f9ab20f97d4416ea060
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_memory_events_are_emitted.yaml b/lib/crewai/tests/cassettes/test_memory_events_are_emitted.yaml
--- a/lib/crewai/tests/cassettes/test_memory_events_are_emitted.yaml
+++ b/lib/crewai/tests/cassettes/test_memory_events_are_emitted.yaml
@@ -1966,4 +1966,556 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nResearch
+      a topic to teach a kid aged 6 about math.\n\nExpected Output:\nA topic, explanation,
+      angle, and examples.\n\nActual Output:\nI now can give a great answer  \nFinal
+      Answer: \n\n**Topic:** Introduction to Addition\n\n**Explanation:** \nAddition
+      is one of the simplest operations in math. It''s all about putting things together.
+      When we add, we combine two or more numbers to find out how many we have in
+      total. For a 6-year-old, it can be visualized as combining different groups
+      of objects. Here''s how we can teach it:\n\n1. **Basic Concept**: Explain that
+      addition means bringing two amounts together to get a new total. Use simple
+      language like, \"If you have 2 apples and I give you 3 more apples, how many
+      apples do you have now?\"\n\n2. **Visual Aids**: Use physical objects like blocks,
+      beads, or fruit. Show the child one group with 2 blocks and another group with
+      3 blocks. Next, combine them and count the total together.\n\n3. **Symbols of
+      Addition**: Introduce the plus sign (+) and the equals sign (=). For instance,
+      you can explain that \"2 + 3 = 5\" means that when adding 2 and 3 together,
+      they make 5.\n\n**Angle:** \nMake it fun and interactive! Use games and stories
+      to keep the child engaged. For example, you could create a story about a little
+      monster who collects candies. Every time he meets a friend, he adds more candies
+      to his pile. \n\n**Examples:**\n- **Using Blocks**: Start with 4 blocks. If
+      you add 2 more, how many blocks do you have? (4 + 2 = 6)\n- **Finger Counting**:
+      Have the child count fingers. Hold up 3 fingers on one hand and 2 on the other
+      hand. Ask, \"How many fingers are up?\" and help them see that when they count
+      all the fingers together, they get 5.\n- **Story Problem**: \"You have 1 toy
+      car, and your friend gives you 3 more toy cars. How many do you have now?\"
+      Write it down for them: 1 + 3 = ? And help them count to find the answer is
+      4.\n\nMake sure to encourage the child as they explore addition! Celebrate their
+      successes and provide help as needed. This will help foster a positive attitude
+      towards math, making it not just an academic subject, but an enjoyable activity.\n\nPlease
+      provide:\n- Bullet points suggestions to improve future similar tasks\n- A score
+      from 0 to 10 evaluating on completion, quality, and overall performance- Entities
+      extracted from the task output, if any, their type, description, and relationships"}],"model":"gpt-4.1-mini"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '2663'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=Dmt0PIbI1kDJNEjEUHh50Vv4Y9ZcWX6w2Uku_CIohuk-1751391377646-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        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
+        EAAA
+    headers:
+      CF-RAY:
+      - 996fc2662b62bab1-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:39 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=GCnzowRk3BBtL4hThExLBaTMoCuPX2iDYiXpVFdUP00-1761878139-1.0.1.1-XLODyX0MQKS_p7.OT8NQGYtBAEoNV5jjkXr.7wBXtRTDsCzL487WWm2eDTtkhfUnOPLSw0b3ttpMmgPZc26O86CB2NAaNHDAENdlxghjQL8;
+        path=/; expires=Fri, 31-Oct-25 03:05:39 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=7F8vpJeCnAeLp1RRxe6VMVnO1Uwd.ucHtiVvA_sGMd0-1761878139796-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '9968'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '9983'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999367'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999365'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_2eaa8f840d3346c1ad94db49b3227441
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nResearch
+      a topic to teach a kid aged 6 about math.\n\nExpected Output:\nA topic, explanation,
+      angle, and examples.\n\nActual Output:\nI now can give a great answer  \nFinal
+      Answer: \n\n**Topic:** Introduction to Addition\n\n**Explanation:** \nAddition
+      is one of the simplest operations in math. It''s all about putting things together.
+      When we add, we combine two or more numbers to find out how many we have in
+      total. For a 6-year-old, it can be visualized as combining different groups
+      of objects. Here''s how we can teach it:\n\n1. **Basic Concept**: Explain that
+      addition means bringing two amounts together to get a new total. Use simple
+      language like, \"If you have 2 apples and I give you 3 more apples, how many
+      apples do you have now?\"\n\n2. **Visual Aids**: Use physical objects like blocks,
+      beads, or fruit. Show the child one group with 2 blocks and another group with
+      3 blocks. Next, combine them and count the total together.\n\n3. **Symbols of
+      Addition**: Introduce the plus sign (+) and the equals sign (=). For instance,
+      you can explain that \"2 + 3 = 5\" means that when adding 2 and 3 together,
+      they make 5.\n\n**Angle:** \nMake it fun and interactive! Use games and stories
+      to keep the child engaged. For example, you could create a story about a little
+      monster who collects candies. Every time he meets a friend, he adds more candies
+      to his pile. \n\n**Examples:**\n- **Using Blocks**: Start with 4 blocks. If
+      you add 2 more, how many blocks do you have? (4 + 2 = 6)\n- **Finger Counting**:
+      Have the child count fingers. Hold up 3 fingers on one hand and 2 on the other
+      hand. Ask, \"How many fingers are up?\" and help them see that when they count
+      all the fingers together, they get 5.\n- **Story Problem**: \"You have 1 toy
+      car, and your friend gives you 3 more toy cars. How many do you have now?\"
+      Write it down for them: 1 + 3 = ? And help them count to find the answer is
+      4.\n\nMake sure to encourage the child as they explore addition! Celebrate their
+      successes and provide help as needed. This will help foster a positive attitude
+      towards math, making it not just an academic subject, but an enjoyable activity.\n\nPlease
+      provide:\n- Bullet points suggestions to improve future similar tasks\n- A score
+      from 0 to 10 evaluating on completion, quality, and overall performance- Entities
+      extracted from the task output, if any, their type, description, and relationships"}],"model":"gpt-4.1-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"$defs":{"Entity":{"properties":{"name":{"description":"The
+      name of the entity.","title":"Name","type":"string"},"type":{"description":"The
+      type of the entity.","title":"Type","type":"string"},"description":{"description":"Description
+      of the entity.","title":"Description","type":"string"},"relationships":{"description":"Relationships
+      of the entity.","items":{"type":"string"},"title":"Relationships","type":"array"}},"required":["name","type","description","relationships"],"title":"Entity","type":"object","additionalProperties":false}},"properties":{"suggestions":{"description":"Suggestions
+      to improve future similar tasks.","items":{"type":"string"},"title":"Suggestions","type":"array"},"quality":{"description":"A
+      score from 0 to 10 evaluating on completion, quality, and overall performance,
+      all taking into account the task description, expected output, and the result
+      of the task.","title":"Quality","type":"number"},"entities":{"description":"Entities
+      extracted from the task output.","items":{"$ref":"#/$defs/Entity"},"title":"Entities","type":"array"}},"required":["suggestions","quality","entities"],"title":"TaskEvaluation","type":"object","additionalProperties":false},"name":"TaskEvaluation","strict":true}},"stream":false}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '3969'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=7F8vpJeCnAeLp1RRxe6VMVnO1Uwd.ucHtiVvA_sGMd0-1761878139796-0.0.1.1-604800000;
+        __cf_bm=GCnzowRk3BBtL4hThExLBaTMoCuPX2iDYiXpVFdUP00-1761878139-1.0.1.1-XLODyX0MQKS_p7.OT8NQGYtBAEoNV5jjkXr.7wBXtRTDsCzL487WWm2eDTtkhfUnOPLSw0b3ttpMmgPZc26O86CB2NAaNHDAENdlxghjQL8
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//nFZRb9tGDH7PryDuacXsoE7TNDOwh6wo0D5sKdpsA1YHBn2iJC6nu9vx
+        5MQN8t8HnmzL6dKh24sAHXkfv4+kSN0fARiuzByMbTHbLrrp69//ePuOX6yv3n4In/nszeXLXy/X
+        73+Z3X64+KkxE70RVn+SzbtbxzZ00VHm4AezTYSZFHX26mx2/up8dvq8GLpQkdNrTczT0+PZtGPP
+        05PnJy+nz0+ns9Pt9TawJTFz+HQEAHBfnkrUV3Rn5lDAyklHItiQme+dAEwKTk8MirBk9NlMRqMN
+        PpMv3O8XRvqmIVHmsjDzTwvzzlvXVwQIQlbP4ZZzCzHoJUYHf/Vbf8gtgW3ZVdBx02ZAuQH0Fdzi
+        RiAHQC+3lNSt09cV5UwJ0Ge2HDETOMLk2TdgW3SOfENyvDCTQiKkGJI6db3L3FHFCAdkwfENwZor
+        CgIhAcYoID1nXDmCOqSBWSKvoROxr0OyVDjnENkOgd6noBiAHhS406qBhisQhLaFrE8liTbzmvNG
+        AVtyEaJDXwAdiQQ/IF5UFSCsElMNdKcuWLKoiWw3I1puWQYmwALcxZC0UiUuwtl0Q5imwVUareQJ
+        Oswt1KH3VUFEB3LDzm1T9jp44YoScCmghlhjYhyyxR7oDrVJtWyYwaLWIgeoeE1JCEpb3OWSTPaZ
+        Eom+1Ps8Hi/M9WRh/urRcd4szPyHycJoT2Sm0jv3C+Oxo4WZlyywRi7U8iYOpz+rgstICfe2isQm
+        jsP7fGEuPWlQzapw4Zsh7G4UHZqGCbBfB7cuvRO6FZcuyrdB2XchEfi+W1EqbViz15LkkNENuUrk
+        BryW47btf2Pp0QFyJcXl46ZbBVcSgIda3myzuDDXD5NDxVuAix3AXvTVruJXIbgnNb9vN8IWHQxT
+        ZdvbKxfsjUxgRVjJRIXVqecMvVC1b8F1icqfac+yfHhD0b4qdqzOFyIOVP9LBbdeT2q5agmi6wWE
+        Gw/fff+sTATSrtmd/fhsryFRTCTk80h/LPZ/p3/hG0dfyf5FjCmgbZ9kfQEd5TYUTuULHfmwB4S6
+        90VH+TDKHCCdctCLQjfYkRS75JCYStfdEMWDCUm+wYb+R0nGhjuU9c65XrImak3wyOVLaR8jWa51
+        ynhdBZZkn/0ynlTfqHU3OgZhuxas2TeUwIbeZ/bNZK91AzGFlaPu24p1/XC4iBLVvaBuQ987d2BA
+        70MecHQFXm8tD/ul50KjceWLq6Zmz9IuE6EErwtOcoimWB+OAK7Lcu0f7UsTU+hiXuZwQyXc+Yvt
+        cjXjUh+tJ+dnW2sZJ6NhNpvtLI8QlxVlZCcHC9pYtC1V491xm2NfcTgwHB3o/iefp7AH7eybb4Ef
+        DdZSzFQtY6KK7WPNo1sinU9fc9vnuRA2QmnNlpaZKWktKqqxd8OviJGNZOqWQ2PFxMP/SB2Xp/bk
+        /OWsPj87MUcPR38DAAD//wMAZsj3gp4JAAA=
+    headers:
+      CF-RAY:
+      - 996fc2a68c7dbab1-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:43 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '3333'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '3358'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999367'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999365'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_e56794132fe345d0bfcee4804d1ea766
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"input":["Examples(Illustrative Examples): Specific instances used to
+      explain addition including using blocks, finger counting, and story problems."],"model":"text-embedding-3-small","encoding_format":"base64"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '211'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=vLbBcLMQoKUtOCugPnUg_H9aADRheAVHbrMDJqmikBA-1751391361577-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/embeddings
+  response:
+    body:
+      string: !!binary |
+        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
+        SfN/r//1edS//vofAAAA//8DADmCS/LgIAAA
+    headers:
+      CF-RAY:
+      - 996fc2bdfba74c68-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:43 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=.S.0fRlkXW0.BA2KmS9TTms9JPq5SLnXktKdk0f0xho-1761878143-1.0.1.1-FYQzY6Kr.UXjSIXdnFMpEPUn.35ba4Hk8i16kCdAKgJwCLZiQAN8v9XzelGaNBPwPS9rIX_MqRctKhBDHgbMD_f_8fk0YOHhnCFfbGi56A8;
+        path=/; expires=Fri, 31-Oct-25 03:05:43 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=fhKPFQ8oWIy28FS88b8siDfqJGAFSqTpIwMwmdY2q_s-1761878143910-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-allow-origin:
+      - '*'
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-model:
+      - text-embedding-3-small
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '94'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      strict-transport-security:
+      - max-age=31536000; includeSubDomains; preload
+      via:
+      - envoy-router-568dcd8c65-k74d4
+      x-envoy-upstream-service-time:
+      - '122'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-requests:
+      - '10000'
+      x-ratelimit-limit-tokens:
+      - '10000000'
+      x-ratelimit-remaining-requests:
+      - '9999'
+      x-ratelimit-remaining-tokens:
+      - '9999966'
+      x-ratelimit-reset-requests:
+      - 6ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_d2945ad09e9c45ca99f752686167bb97
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_output_pydantic_hierarchical.yaml b/lib/crewai/tests/cassettes/test_output_pydantic_hierarchical.yaml
--- a/lib/crewai/tests/cassettes/test_output_pydantic_hierarchical.yaml
+++ b/lib/crewai/tests/cassettes/test_output_pydantic_hierarchical.yaml
@@ -1,569 +1,108 @@
 interactions:
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Crew Manager. You
-      are a seasoned manager with a knack for getting the best out of your team.\nYou
-      are also known for your ability to delegate work to the right people, and to
-      ask the right questions to get the best out of your team.\nEven though you don''t
-      perform tasks by yourself, you have a lot of experience in the field, which
-      allows you to properly evaluate the work of your team members.\nYour personal
-      goal is: Manage the team to complete the task in the best way possible.\nYou
-      ONLY have access to the following tools, and should NEVER make up tools that
-      are not listed here:\n\nTool Name: Delegate work to coworker(task: str, context:
-      str, coworker: Optional[str] = None, **kwargs)\nTool Description: Delegate a
-      specific task to one of the following coworkers: Scorer\nThe input to this tool
-      should be the coworker, the task you want them to do, and ALL necessary context
-      to execute the task, they know nothing about the task, so share absolute everything
-      you know, don''t reference things but instead explain them.\nTool Arguments:
-      {''task'': {''title'': ''Task'', ''type'': ''string''}, ''context'': {''title'':
-      ''Context'', ''type'': ''string''}, ''coworker'': {''title'': ''Coworker'',
-      ''type'': ''string''}, ''kwargs'': {''title'': ''Kwargs'', ''type'': ''object''}}\nTool
-      Name: Ask question to coworker(question: str, context: str, coworker: Optional[str]
-      = None, **kwargs)\nTool Description: Ask a specific question to one of the following
-      coworkers: Scorer\nThe input to this tool should be the coworker, the question
-      you have for them, and ALL necessary context to ask the question properly, they
-      know nothing about the question, so share absolute everything you know, don''t
-      reference things but instead explain them.\nTool Arguments: {''question'': {''title'':
-      ''Question'', ''type'': ''string''}, ''context'': {''title'': ''Context'', ''type'':
-      ''string''}, ''coworker'': {''title'': ''Coworker'', ''type'': ''string''},
-      ''kwargs'': {''title'': ''Kwargs'', ''type'': ''object''}}\n\nUse the following
-      format:\n\nThought: you should always think about what to do\nAction: the action
-      to take, only one name of [Delegate work to coworker, Ask question to coworker],
-      just the name, exactly as it''s written.\nAction Input: the input to the action,
-      just a simple python dictionary, enclosed in curly braces, using \" to wrap
-      keys and values.\nObservation: the result of the action\n\nOnce all necessary
-      information is gathered:\n\nThought: I now know the final answer\nFinal Answer:
-      the final answer to the original input question\n"}, {"role": "user", "content":
-      "\nCurrent Task: Give me an integer score between 1-5 for the following title:
-      ''The impact of AI in the future of work''\n\nThis is the expect criteria for
-      your final answer: The score of the title.\nyou MUST return the actual complete
-      content as the final answer, not a summary.\n\nBegin! This is VERY important
-      to you, use the tools available and give your best Final Answer, your job depends
-      on it!\n\nThought:"}], "model": "gpt-4o"}'
-    headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '2986'
-      content-type:
-      - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
-    method: POST
-    uri: https://api.openai.com/v1/chat/completions
-  response:
-    content: "{\n  \"id\": \"chatcmpl-AB7ftPrKueGANoTk2jisJQy28SMQZ\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214473,\n  \"model\": \"gpt-4o-2024-05-13\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": \"I need to get an integer score between
-      1-5 for the given title \\\"The impact of AI in the future of work.\\\" I will
-      delegate this task to Scorer, providing them with all necessary context.\\n\\nAction:
-      Delegate work to coworker\\nAction Input: {\\\"coworker\\\": \\\"Scorer\\\",
-      \\\"task\\\": \\\"Provide an integer score between 1-5 for the following title:
-      'The impact of AI in the future of work'\\\", \\\"context\\\": \\\"This is for
-      evaluating the impact of AI on the future of work. The score must be an integer
-      between 1-5.\\\"}\",\n        \"refusal\": null\n      },\n      \"logprobs\":
-      null,\n      \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      664,\n    \"completion_tokens\": 123,\n    \"total_tokens\": 787,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": \"fp_e375328146\"\n}\n"
-    headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85f9b85bf71cf3-GRU
-      Connection:
-      - keep-alive
-      Content-Encoding:
-      - gzip
-      Content-Type:
-      - application/json
-      Date:
-      - Tue, 24 Sep 2024 21:47:55 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
-      - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '1941'
-      openai-version:
-      - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '30000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '29999269'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 1ms
-      x-request-id:
-      - req_9ed13e6054d3e4d6b7b600e20891fb25
-    http_version: HTTP/1.1
-    status_code: 200
-- request:
-    body: '{"messages": [{"role": "system", "content": "You are Scorer. You''re an
-      expert scorer, specialized in scoring titles.\nYour personal goal is: Score
-      the title\nTo give my best complete final answer to the task use the exact following
-      format:\n\nThought: I now can give a great answer\nFinal Answer: Your final
-      answer must be the great and the most complete as possible, it must be outcome
-      described.\n\nI MUST use these formats, my job depends on it!"}, {"role": "user",
-      "content": "\nCurrent Task: Provide an integer score between 1-5 for the following
-      title: ''The impact of AI in the future of work''\n\nThis is the expect criteria
-      for your final answer: Your best answer to your coworker asking you this, accounting
-      for the context shared.\nyou MUST return the actual complete content as the
-      final answer, not a summary.\n\nThis is the context you''re working with:\nThis
-      is for evaluating the impact of AI on the future of work. The score must be
-      an integer between 1-5.\n\nBegin! This is VERY important to you, use the tools
-      available and give your best Final Answer, your job depends on it!\n\nThought:"}],
-      "model": "gpt-4o"}'
-    headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '1127'
-      content-type:
-      - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
-    method: POST
-    uri: https://api.openai.com/v1/chat/completions
-  response:
-    content: "{\n  \"id\": \"chatcmpl-AB7fvCyQD7z7StdDBs7M1mDlMsW6l\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214475,\n  \"model\": \"gpt-4o-2024-05-13\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": \"Thought: I now can give a great answer\\nFinal
-      Answer: 4\",\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      230,\n    \"completion_tokens\": 15,\n    \"total_tokens\": 245,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": \"fp_e375328146\"\n}\n"
-    headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85f9c6df9b1cf3-GRU
-      Connection:
-      - keep-alive
-      Content-Encoding:
-      - gzip
-      Content-Type:
-      - application/json
-      Date:
-      - Tue, 24 Sep 2024 21:47:56 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
-      - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '350'
-      openai-version:
-      - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '30000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '29999729'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 0s
-      x-request-id:
-      - req_a88c60d514500d2b940c40ad4d553e73
-    http_version: HTTP/1.1
-    status_code: 200
-- request:
-    body: '{"messages": [{"role": "system", "content": "You are Crew Manager. You
-      are a seasoned manager with a knack for getting the best out of your team.\nYou
-      are also known for your ability to delegate work to the right people, and to
-      ask the right questions to get the best out of your team.\nEven though you don''t
-      perform tasks by yourself, you have a lot of experience in the field, which
-      allows you to properly evaluate the work of your team members.\nYour personal
-      goal is: Manage the team to complete the task in the best way possible.\nYou
-      ONLY have access to the following tools, and should NEVER make up tools that
-      are not listed here:\n\nTool Name: Delegate work to coworker(task: str, context:
-      str, coworker: Optional[str] = None, **kwargs)\nTool Description: Delegate a
-      specific task to one of the following coworkers: Scorer\nThe input to this tool
-      should be the coworker, the task you want them to do, and ALL necessary context
-      to execute the task, they know nothing about the task, so share absolute everything
-      you know, don''t reference things but instead explain them.\nTool Arguments:
-      {''task'': {''title'': ''Task'', ''type'': ''string''}, ''context'': {''title'':
-      ''Context'', ''type'': ''string''}, ''coworker'': {''title'': ''Coworker'',
-      ''type'': ''string''}, ''kwargs'': {''title'': ''Kwargs'', ''type'': ''object''}}\nTool
-      Name: Ask question to coworker(question: str, context: str, coworker: Optional[str]
-      = None, **kwargs)\nTool Description: Ask a specific question to one of the following
-      coworkers: Scorer\nThe input to this tool should be the coworker, the question
-      you have for them, and ALL necessary context to ask the question properly, they
-      know nothing about the question, so share absolute everything you know, don''t
-      reference things but instead explain them.\nTool Arguments: {''question'': {''title'':
-      ''Question'', ''type'': ''string''}, ''context'': {''title'': ''Context'', ''type'':
-      ''string''}, ''coworker'': {''title'': ''Coworker'', ''type'': ''string''},
-      ''kwargs'': {''title'': ''Kwargs'', ''type'': ''object''}}\n\nUse the following
-      format:\n\nThought: you should always think about what to do\nAction: the action
-      to take, only one name of [Delegate work to coworker, Ask question to coworker],
-      just the name, exactly as it''s written.\nAction Input: the input to the action,
-      just a simple python dictionary, enclosed in curly braces, using \" to wrap
-      keys and values.\nObservation: the result of the action\n\nOnce all necessary
-      information is gathered:\n\nThought: I now know the final answer\nFinal Answer:
-      the final answer to the original input question\n"}, {"role": "user", "content":
-      "\nCurrent Task: Give me an integer score between 1-5 for the following title:
-      ''The impact of AI in the future of work''\n\nThis is the expect criteria for
-      your final answer: The score of the title.\nyou MUST return the actual complete
-      content as the final answer, not a summary.\n\nBegin! This is VERY important
-      to you, use the tools available and give your best Final Answer, your job depends
-      on it!\n\nThought:"}, {"role": "assistant", "content": "I need to get an integer
-      score between 1-5 for the given title \"The impact of AI in the future of work.\"
-      I will delegate this task to Scorer, providing them with all necessary context.\n\nAction:
-      Delegate work to coworker\nAction Input: {\"coworker\": \"Scorer\", \"task\":
-      \"Provide an integer score between 1-5 for the following title: ''The impact
-      of AI in the future of work''\", \"context\": \"This is for evaluating the impact
-      of AI on the future of work. The score must be an integer between 1-5.\"}\nObservation:
-      4"}], "model": "gpt-4o"}'
-    headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '3546'
-      content-type:
-      - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
-    method: POST
-    uri: https://api.openai.com/v1/chat/completions
-  response:
-    content: "{\n  \"id\": \"chatcmpl-AB7fwZ4WSniWh4YMRrip2x1Bx03b7\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214476,\n  \"model\": \"gpt-4o-2024-05-13\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": \"Thought: I now know the final answer.\\n\\nFinal
-      Answer: 4\",\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      795,\n    \"completion_tokens\": 14,\n    \"total_tokens\": 809,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": \"fp_e375328146\"\n}\n"
-    headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85f9cd08fb1cf3-GRU
-      Connection:
-      - keep-alive
-      Content-Encoding:
-      - gzip
-      Content-Type:
-      - application/json
-      Date:
-      - Tue, 24 Sep 2024 21:47:56 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
-      - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '285'
-      openai-version:
-      - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '30000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '29999141'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 1ms
-      x-request-id:
-      - req_7afa4cb902ce1bca02dcd7dbf2e36970
-    http_version: HTTP/1.1
-    status_code: 200
-- request:
-    body: !!binary |
-      CsUWCiQKIgoMc2VydmljZS5uYW1lEhIKEGNyZXdBSS10ZWxlbWV0cnkSnBYKEgoQY3Jld2FpLnRl
-      bGVtZXRyeRKWBwoQ7hmoiN2Q853yaKv7s8v78xII1Z7nWICk2xQqDENyZXcgQ3JlYXRlZDABORiE
-      ZSRpTPgXQZDhZyRpTPgXShoKDmNyZXdhaV92ZXJzaW9uEggKBjAuNjEuMEoaCg5weXRob25fdmVy
-      c2lvbhIICgYzLjExLjdKLgoIY3Jld19rZXkSIgogNWU2ZWZmZTY4MGE1ZDk3ZGMzODczYjE0ODI1
-      Y2NmYTNKMQoHY3Jld19pZBImCiQwNmFkMjAzYS1lYzY3LTQ5NzgtOWUwYy02N2FmOTgwNTExNjlK
-      HAoMY3Jld19wcm9jZXNzEgwKCnNlcXVlbnRpYWxKEQoLY3Jld19tZW1vcnkSAhAAShoKFGNyZXdf
-      bnVtYmVyX29mX3Rhc2tzEgIYAUobChVjcmV3X251bWJlcl9vZl9hZ2VudHMSAhgBSsgCCgtjcmV3
-      X2FnZW50cxK4Agq1Alt7ImtleSI6ICI5MmU3ZWIxOTE2NjRjOTM1Nzg1ZWQ3ZDQyNDBhMjk0ZCIs
-      ICJpZCI6ICJlYzQwNTViMC1hMjJhLTQ0NDYtODMyZS1jMmY5MzBjMWM0OGYiLCAicm9sZSI6ICJT
-      Y29yZXIiLCAidmVyYm9zZT8iOiBmYWxzZSwgIm1heF9pdGVyIjogMTUsICJtYXhfcnBtIjogbnVs
-      bCwgImZ1bmN0aW9uX2NhbGxpbmdfbGxtIjogIiIsICJsbG0iOiAiZ3B0LTRvIiwgImRlbGVnYXRp
-      b25fZW5hYmxlZD8iOiBmYWxzZSwgImFsbG93X2NvZGVfZXhlY3V0aW9uPyI6IGZhbHNlLCAibWF4
-      X3JldHJ5X2xpbWl0IjogMiwgInRvb2xzX25hbWVzIjogW119XUr7AQoKY3Jld190YXNrcxLsAQrp
-      AVt7ImtleSI6ICIyN2VmMzhjYzk5ZGE0YThkZWQ3MGVkNDA2ZTQ0YWI4NiIsICJpZCI6ICIyM2Mw
-      YzVkMC1kOWJhLTQwODAtOTVlNy1hNTVhMDI4Zjc5YmIiLCAiYXN5bmNfZXhlY3V0aW9uPyI6IGZh
-      bHNlLCAiaHVtYW5faW5wdXQ/IjogZmFsc2UsICJhZ2VudF9yb2xlIjogIlNjb3JlciIsICJhZ2Vu
-      dF9rZXkiOiAiOTJlN2ViMTkxNjY0YzkzNTc4NWVkN2Q0MjQwYTI5NGQiLCAidG9vbHNfbmFtZXMi
-      OiBbXX1degIYAYUBAAEAABKOAgoQJ9OdH2Oo8Rb6Phj24GNRNxIIJdpH3NFfg4kqDFRhc2sgQ3Jl
-      YXRlZDABOQCHeiRpTPgXQThOeyRpTPgXSi4KCGNyZXdfa2V5EiIKIDVlNmVmZmU2ODBhNWQ5N2Rj
-      Mzg3M2IxNDgyNWNjZmEzSjEKB2NyZXdfaWQSJgokMDZhZDIwM2EtZWM2Ny00OTc4LTllMGMtNjdh
-      Zjk4MDUxMTY5Si4KCHRhc2tfa2V5EiIKIDI3ZWYzOGNjOTlkYTRhOGRlZDcwZWQ0MDZlNDRhYjg2
-      SjEKB3Rhc2tfaWQSJgokMjNjMGM1ZDAtZDliYS00MDgwLTk1ZTctYTU1YTAyOGY3OWJiegIYAYUB
-      AAEAABKQAgoQz7ebW98sQ+bPLeiKpGCv/hIIzmkkC3T0j0wqDlRhc2sgRXhlY3V0aW9uMAE5iJR7
-      JGlM+BdB2HgueWlM+BdKLgoIY3Jld19rZXkSIgogNWU2ZWZmZTY4MGE1ZDk3ZGMzODczYjE0ODI1
-      Y2NmYTNKMQoHY3Jld19pZBImCiQwNmFkMjAzYS1lYzY3LTQ5NzgtOWUwYy02N2FmOTgwNTExNjlK
-      LgoIdGFza19rZXkSIgogMjdlZjM4Y2M5OWRhNGE4ZGVkNzBlZDQwNmU0NGFiODZKMQoHdGFza19p
-      ZBImCiQyM2MwYzVkMC1kOWJhLTQwODAtOTVlNy1hNTVhMDI4Zjc5YmJ6AhgBhQEAAQAAEpgHChD6
-      So0yENrsTtbKKm1BpmVCEghSKU/H68ezCioMQ3JldyBDcmVhdGVkMAE5aKdGemlM+BdBoFZLemlM
-      +BdKGgoOY3Jld2FpX3ZlcnNpb24SCAoGMC42MS4wShoKDnB5dGhvbl92ZXJzaW9uEggKBjMuMTEu
-      N0ouCghjcmV3X2tleRIiCiA1ZTZlZmZlNjgwYTVkOTdkYzM4NzNiMTQ4MjVjY2ZhM0oxCgdjcmV3
-      X2lkEiYKJDA4NzM1YWQ3LWJlMWEtNDRkMy05NTc3LWEzMzRmMjY1M2Y2MUoeCgxjcmV3X3Byb2Nl
-      c3MSDgoMaGllcmFyY2hpY2FsShEKC2NyZXdfbWVtb3J5EgIQAEoaChRjcmV3X251bWJlcl9vZl90
-      YXNrcxICGAFKGwoVY3Jld19udW1iZXJfb2ZfYWdlbnRzEgIYAUrIAgoLY3Jld19hZ2VudHMSuAIK
-      tQJbeyJrZXkiOiAiOTJlN2ViMTkxNjY0YzkzNTc4NWVkN2Q0MjQwYTI5NGQiLCAiaWQiOiAiM2Ex
-      ZWQwYjAtN2MyMy00YzI0LWJkNzEtYzllZGEzYTRhOTE2IiwgInJvbGUiOiAiU2NvcmVyIiwgInZl
-      cmJvc2U/IjogZmFsc2UsICJtYXhfaXRlciI6IDE1LCAibWF4X3JwbSI6IG51bGwsICJmdW5jdGlv
-      bl9jYWxsaW5nX2xsbSI6ICIiLCAibGxtIjogImdwdC00byIsICJkZWxlZ2F0aW9uX2VuYWJsZWQ/
-      IjogZmFsc2UsICJhbGxvd19jb2RlX2V4ZWN1dGlvbj8iOiBmYWxzZSwgIm1heF9yZXRyeV9saW1p
-      dCI6IDIsICJ0b29sc19uYW1lcyI6IFtdfV1K+wEKCmNyZXdfdGFza3MS7AEK6QFbeyJrZXkiOiAi
-      MjdlZjM4Y2M5OWRhNGE4ZGVkNzBlZDQwNmU0NGFiODYiLCAiaWQiOiAiOWIxNmIxN2EtMGU4OS00
-      ZjBiLTg3NzQtZmY5MTg1NzRmMzY2IiwgImFzeW5jX2V4ZWN1dGlvbj8iOiBmYWxzZSwgImh1bWFu
-      X2lucHV0PyI6IGZhbHNlLCAiYWdlbnRfcm9sZSI6ICJTY29yZXIiLCAiYWdlbnRfa2V5IjogIjky
-      ZTdlYjE5MTY2NGM5MzU3ODVlZDdkNDI0MGEyOTRkIiwgInRvb2xzX25hbWVzIjogW119XXoCGAGF
-      AQABAAASjgIKEERPBzklAtGSN2WJ/m32bsYSCCh9XOn+rkCQKgxUYXNrIENyZWF0ZWQwATlgnTR7
-      aUz4F0HgWDV7aUz4F0ouCghjcmV3X2tleRIiCiA1ZTZlZmZlNjgwYTVkOTdkYzM4NzNiMTQ4MjVj
-      Y2ZhM0oxCgdjcmV3X2lkEiYKJDA4NzM1YWQ3LWJlMWEtNDRkMy05NTc3LWEzMzRmMjY1M2Y2MUou
-      Cgh0YXNrX2tleRIiCiAyN2VmMzhjYzk5ZGE0YThkZWQ3MGVkNDA2ZTQ0YWI4NkoxCgd0YXNrX2lk
-      EiYKJDliMTZiMTdhLTBlODktNGYwYi04Nzc0LWZmOTE4NTc0ZjM2NnoCGAGFAQABAAASnAEKEPU4
-      SNHw9hxH/s8bG9c91koSCDcUNUW+hkT9KgpUb29sIFVzYWdlMAE5UDVuQGpM+BdBEG90QGpM+BdK
-      GgoOY3Jld2FpX3ZlcnNpb24SCAoGMC42MS4wSigKCXRvb2xfbmFtZRIbChlEZWxlZ2F0ZSB3b3Jr
-      IHRvIGNvd29ya2VySg4KCGF0dGVtcHRzEgIYAXoCGAGFAQABAAA=
+    body: '{"trace_id": "e97144c4-2bdc-48ac-bbe5-59e4d9814c49", "execution_type":
+      "crew", "user_identifier": null, "execution_context": {"crew_fingerprint": null,
+      "crew_name": "crew", "flow_name": null, "crewai_version": "1.2.1", "privacy_level":
+      "standard"}, "execution_metadata": {"expected_duration_estimate": 300, "agent_count":
+      0, "task_count": 0, "flow_method_count": 0, "execution_started_at": "2025-10-31T07:44:22.182046+00:00"},
+      "ephemeral_trace_id": "e97144c4-2bdc-48ac-bbe5-59e4d9814c49"}'
     headers:
       Accept:
       - '*/*'
       Accept-Encoding:
-      - gzip, deflate
+      - gzip, deflate, zstd
       Connection:
       - keep-alive
       Content-Length:
-      - '2888'
+      - '488'
       Content-Type:
-      - application/x-protobuf
+      - application/json
       User-Agent:
-      - OTel-OTLP-Exporter-Python/1.27.0
+      - CrewAI-CLI/1.2.1
+      X-Crewai-Organization-Id:
+      - 73c2b193-f579-422c-84c7-76a39a1da77f
+      X-Crewai-Version:
+      - 1.2.1
     method: POST
-    uri: https://telemetry.crewai.com:4319/v1/traces
+    uri: https://app.crewai.com/crewai_plus/api/v1/tracing/ephemeral/batches
   response:
     body:
-      string: "\n\0"
-    headers:
-      Content-Length:
-      - '2'
-      Content-Type:
-      - application/x-protobuf
-      Date:
-      - Tue, 24 Sep 2024 21:47:57 GMT
-    status:
-      code: 200
-      message: OK
-- request:
-    body: '{"messages": [{"role": "user", "content": "4"}, {"role": "system", "content":
-      "I''m gonna convert this raw text into valid JSON.\n\nThe json should have the
-      following structure, with the following keys:\n{\n    score: int\n}"}], "model":
-      "gpt-4o", "tool_choice": {"type": "function", "function": {"name": "ScoreOutput"}},
-      "tools": [{"type": "function", "function": {"name": "ScoreOutput", "description":
-      "Correctly extracted `ScoreOutput` with all the required parameters with correct
-      types", "parameters": {"properties": {"score": {"title": "Score", "type": "integer"}},
-      "required": ["score"], "type": "object"}}}]}'
+      string: '{"id":"dfc603d5-afb3-49bb-808c-dfae122dde9d","ephemeral_trace_id":"e97144c4-2bdc-48ac-bbe5-59e4d9814c49","execution_type":"crew","crew_name":"crew","flow_name":null,"status":"running","duration_ms":null,"crewai_version":"1.2.1","total_events":0,"execution_context":{"crew_fingerprint":null,"crew_name":"crew","flow_name":null,"crewai_version":"1.2.1","privacy_level":"standard"},"created_at":"2025-10-31T07:44:22.756Z","updated_at":"2025-10-31T07:44:22.756Z","access_code":"TRACE-0d13ac15e6","user_identifier":null}'
     headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '615'
-      content-type:
-      - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
-    method: POST
-    uri: https://api.openai.com/v1/chat/completions
-  response:
-    content: "{\n  \"id\": \"chatcmpl-AB7fxFJVaaPLV8eezP1LWgZes9p8t\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214477,\n  \"model\": \"gpt-4o-2024-05-13\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": null,\n        \"tool_calls\": [\n          {\n
-      \           \"id\": \"call_TuUA4HNG1rH6GOq9nrx94Fp7\",\n            \"type\":
-      \"function\",\n            \"function\": {\n              \"name\": \"ScoreOutput\",\n
-      \             \"arguments\": \"{\\\"score\\\":4}\"\n            }\n          }\n
-      \       ],\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      100,\n    \"completion_tokens\": 5,\n    \"total_tokens\": 105,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": \"fp_3537616b13\"\n}\n"
-    headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85f9d13ee71cf3-GRU
       Connection:
       - keep-alive
-      Content-Encoding:
-      - gzip
+      Content-Length:
+      - '515'
       Content-Type:
-      - application/json
+      - application/json; charset=utf-8
       Date:
-      - Tue, 24 Sep 2024 21:47:57 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
-      - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '267'
-      openai-version:
-      - '2020-10-01'
+      - Fri, 31 Oct 2025 07:44:22 GMT
+      cache-control:
+      - no-store
+      content-security-policy:
+      - 'default-src ''self'' *.app.crewai.com app.crewai.com; script-src ''self''
+        ''unsafe-inline'' *.app.crewai.com app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts
+        https://www.gstatic.com https://run.pstmn.io https://apis.google.com https://apis.google.com/js/api.js
+        https://accounts.google.com https://accounts.google.com/gsi/client https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css.map
+        https://*.google.com https://docs.google.com https://slides.google.com https://js.hs-scripts.com
+        https://js.sentry-cdn.com https://browser.sentry-cdn.com https://www.googletagmanager.com
+        https://js-na1.hs-scripts.com https://js.hubspot.com http://js-na1.hs-scripts.com
+        https://bat.bing.com https://cdn.amplitude.com https://cdn.segment.com https://d1d3n03t5zntha.cloudfront.net/
+        https://descriptusercontent.com https://edge.fullstory.com https://googleads.g.doubleclick.net
+        https://js.hs-analytics.net https://js.hs-banner.com https://js.hsadspixel.net
+        https://js.hscollectedforms.net https://js.usemessages.com https://snap.licdn.com
+        https://static.cloudflareinsights.com https://static.reo.dev https://www.google-analytics.com
+        https://share.descript.com/; style-src ''self'' ''unsafe-inline'' *.app.crewai.com
+        app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts; img-src ''self'' data:
+        *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com https://dashboard.tools.crewai.com
+        https://cdn.jsdelivr.net https://forms.hsforms.com https://track.hubspot.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://www.google.com
+        https://www.google.com.br; font-src ''self'' data: *.app.crewai.com app.crewai.com;
+        connect-src ''self'' *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com
+        https://connect.useparagon.com/ https://zeus.useparagon.com/* https://*.useparagon.com/*
+        https://run.pstmn.io https://connect.tools.crewai.com/ https://*.sentry.io
+        https://www.google-analytics.com https://edge.fullstory.com https://rs.fullstory.com
+        https://api.hubspot.com https://forms.hscollectedforms.net https://api.hubapi.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://google.com/pagead/form-data/16713662509
+        https://google.com/ccm/form-data/16713662509 https://www.google.com/ccm/collect
+        https://worker-actionkit.tools.crewai.com https://api.reo.dev; frame-src ''self''
+        *.app.crewai.com app.crewai.com https://connect.useparagon.com/ https://zeus.tools.crewai.com
+        https://zeus.useparagon.com/* https://connect.tools.crewai.com/ https://docs.google.com
+        https://drive.google.com https://slides.google.com https://accounts.google.com
+        https://*.google.com https://app.hubspot.com/ https://td.doubleclick.net https://www.googletagmanager.com/
+        https://www.youtube.com https://share.descript.com'
+      etag:
+      - W/"c886631dcc4aae274f1bdcfb3b17fb01"
+      expires:
+      - '0'
+      permissions-policy:
+      - camera=(), microphone=(self), geolocation=()
+      pragma:
+      - no-cache
+      referrer-policy:
+      - strict-origin-when-cross-origin
       strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '30000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '29999947'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 0s
+      - max-age=63072000; includeSubDomains
+      vary:
+      - Accept
+      x-content-type-options:
+      - nosniff
+      x-frame-options:
+      - SAMEORIGIN
+      x-permitted-cross-domain-policies:
+      - none
       x-request-id:
-      - req_c8bb2af8f4a63658c3c9316045a413e1
-    http_version: HTTP/1.1
-    status_code: 200
+      - 9b9d1dac-6f4b-455b-8be9-fa8bb0c85a4f
+      x-runtime:
+      - '0.073038'
+      x-xss-protection:
+      - 1; mode=block
+    status:
+      code: 201
+      message: Created
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Crew Manager. You
-      are a seasoned manager with a knack for getting the best out of your team.\nYou
+    body: '{"messages":[{"role":"system","content":"You are Crew Manager. You are
+      a seasoned manager with a knack for getting the best out of your team.\nYou
       are also known for your ability to delegate work to the right people, and to
       ask the right questions to get the best out of your team.\nEven though you don''t
       perform tasks by yourself, you have a lot of experience in the field, which
@@ -594,15 +133,17 @@ interactions:
       to wrap keys and values.\nObservation: the result of the action\n```\n\nOnce
       all necessary information is gathered, return the following format:\n\n```\nThought:
       I now know the final answer\nFinal Answer: the final answer to the original
-      input question\n```"}, {"role": "user", "content": "\nCurrent Task: Give me
-      an integer score between 1-5 for the following title: ''The impact of AI in
-      the future of work''\n\nThis is the expected criteria for your final answer:
-      The score of the title.\nyou MUST return the actual complete content as the
-      final answer, not a summary.\nEnsure your final answer contains only the content
-      in the following format: {\n  \"score\": int\n}\n\nEnsure the final output does
-      not include any code block markers like ```json or ```python.\n\nBegin! This
-      is VERY important to you, use the tools available and give your best Final Answer,
-      your job depends on it!\n\nThought:"}], "model": "gpt-4o", "stop": ["\nObservation:"]}'
+      input question\n```"},{"role":"user","content":"\nCurrent Task: Give me an integer
+      score between 1-5 for the following title: ''The impact of AI in the future
+      of work''\n\nThis is the expected criteria for your final answer: The score
+      of the title.\nyou MUST return the actual complete content as the final answer,
+      not a summary.\nEnsure your final answer contains only the content in the following
+      format: {\n  \"properties\": {\n    \"score\": {\n      \"title\": \"Score\",\n      \"type\":
+      \"integer\"\n    }\n  },\n  \"required\": [\n    \"score\"\n  ],\n  \"title\":
+      \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\": false\n}\n\nEnsure
+      the final output does not include any code block markers like ```json or ```python.\n\nBegin!
+      This is VERY important to you, use the tools available and give your best Final
+      Answer, your job depends on it!\n\nThought:"}],"model":"gpt-4o"}'
     headers:
       accept:
       - application/json
@@ -611,13 +152,13 @@ interactions:
       connection:
       - keep-alive
       content-length:
-      - '3194'
+      - '3379'
       content-type:
       - application/json
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.93.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
@@ -627,52 +168,52 @@ interactions:
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.93.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
       x-stainless-read-timeout:
-      - '600.0'
+      - '600'
       x-stainless-retry-count:
       - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.12.9
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
     body:
       string: !!binary |
-        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
+        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
+        kOYqAAYAAA==
     headers:
       CF-RAY:
-      - 974eec034af08486-SJC
+      - 997186dc6d3aea38-FCO
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Mon, 25 Aug 2025 23:38:17 GMT
+      - Fri, 31 Oct 2025 07:44:26 GMT
       Server:
       - cloudflare
       Set-Cookie:
-      - __cf_bm=N_ULh2gJbt2dWumbG8h6_rw_QD0TBQ3f1NYS.FsG3w0-1756165097-1.0.1.1-fGULs7H8u7wOLv7QAwRQdlWcZr2zj6dkLXQk5xPa.7SBOn9qj1nh6.VDONMzgxqO2telES4KZZPzeC2G4YFJXV5Q4hemTm4jcMsXA10XFYM;
-        path=/; expires=Tue, 26-Aug-25 00:08:17 GMT; domain=.api.openai.com; HttpOnly;
+      - __cf_bm=n45oVEbg4Ph05GBqJp2KyKI77cF1e_lNGmWrdQjbV20-1761896666-1.0.1.1-hTLlylCKTisapDYTpS63zm.2k2AGNs0DvyKGQ6MEtJHyYJBoXKqzsHRbsZN_dbtjm4Kj_5RG3J73ysTSs817q_9mvPtjHgZOvOPhDwGxV_M;
+        path=/; expires=Fri, 31-Oct-25 08:14:26 GMT; domain=.api.openai.com; HttpOnly;
         Secure; SameSite=None
-      - _cfuvid=_3IyqhyxR3x9q67TqmIC1eWhmeXZIMbk_6ChUHMngHM-1756165097262-0.0.1.1-604800000;
+      - _cfuvid=gOhnFtutoiWlRm84LU88kCfEmlv5P_3_ZJ_wlDnkYy4-1761896666288-0.0.1.1-604800000;
         path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
       Strict-Transport-Security:
       - max-age=31536000; includeSubDomains; preload
@@ -689,13 +230,15 @@ interactions:
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '2201'
+      - '3152'
       openai-project:
       - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
       x-envoy-upstream-service-time:
-      - '2275'
+      - '3196'
+      x-openai-proxy-wasm:
+      - v0.1
       x-ratelimit-limit-project-requests:
       - '10000'
       x-ratelimit-limit-requests:
@@ -707,51 +250,34 @@ interactions:
       x-ratelimit-remaining-requests:
       - '9999'
       x-ratelimit-remaining-tokens:
-      - '29999242'
+      - '29999195'
       x-ratelimit-reset-project-requests:
       - 6ms
       x-ratelimit-reset-requests:
       - 6ms
       x-ratelimit-reset-tokens:
       - 1ms
       x-request-id:
-      - req_8253241bc24547018d1600b0ec310060
+      - req_5011a1ac60f3411f9164a03bedad1bc5
     status:
       code: 200
       message: OK
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Scorer. You''re an
-      expert scorer, specialized in scoring titles.\nYour personal goal is: Score
-      the title\nTo give my best complete final answer to the task respond using the
-      exact following format:\n\nThought: I now can give a great answer\nFinal Answer:
-      Your final answer must be the great and the most complete as possible, it must
-      be outcome described.\n\nI MUST use these formats, my job depends on it!"},
-      {"role": "user", "content": "\nCurrent Task: Score the title ''The impact of
-      AI in the future of work'' on a scale from 1 to 5.\n\nThis is the expected criteria
+    body: '{"messages":[{"role":"system","content":"You are Scorer. You''re an expert
+      scorer, specialized in scoring titles.\nYour personal goal is: Score the title\nTo
+      give my best complete final answer to the task respond using the exact following
+      format:\n\nThought: I now can give a great answer\nFinal Answer: Your final
+      answer must be the great and the most complete as possible, it must be outcome
+      described.\n\nI MUST use these formats, my job depends on it!"},{"role":"user","content":"\nCurrent
+      Task: Evaluate and provide an integer score between 1-5 for the title ''The
+      impact of AI in the future of work''. Consider factors such as relevance, clarity,
+      engagement, and potential impact of the title.\n\nThis is the expected criteria
       for your final answer: Your best answer to your coworker asking you this, accounting
       for the context shared.\nyou MUST return the actual complete content as the
-      final answer, not a summary.\n\nThis is the context you''re working with:\nThe
-      task involves evaluating the given title and providing an integer score between
-      1 and 5 based on the title''s potential impact, relevance, and interest level.\n\nBegin!
-      This is VERY important to you, use the tools available and give your best Final
-      Answer, your job depends on it!\n\nThought:"}, {"role": "assistant", "content":
-      "Thought: I need to delegate the task of scoring the title to our Scorer, providing
-      them with context about the title and the task at hand.\n\nAction: Delegate
-      work to coworker\nAction Input: {\"task\": \"Score the title ''The impact of
-      AI in the future of work'' on a scale from 1 to 5.\", \"context\": \"The task
-      involves evaluating the given title and providing an integer score between 1
-      and 5 based on the title''s potential impact, relevance, and interest level.\",
-      \"coworker\": \"Scorer\"}\nObservation: I encountered an error: Action ''Delegate
-      work to coworker'' don''t exist, these are the only available Actions:\n\nMoving
-      on then. I MUST either use a tool (use one at time) OR give my best final answer
-      not both at the same time. When responding, I must use the following format:\n\n```\nThought:
-      you should always think about what to do\nAction: the action to take, should
-      be one of []\nAction Input: the input to the action, dictionary enclosed in
-      curly braces\nObservation: the result of the action\n```\nThis Thought/Action/Action
-      Input/Result can repeat N times. Once I know the final answer, I must return
-      the following format:\n\n```\nThought: I now can give a great answer\nFinal
-      Answer: Your final answer must be the great and the most complete as possible,
-      it must be outcome described\n\n```"}], "model": "gpt-4o", "stop": ["\nObservation:"]}'
+      final answer, not a summary.\n\nThis is the context you''re working with:\nThis
+      score will be used to assess the quality of the title in terms of its relevance
+      and impact.\n\nBegin! This is VERY important to you, use the tools available
+      and give your best Final Answer, your job depends on it!\n\nThought:"}],"model":"gpt-4.1-mini"}'
     headers:
       accept:
       - application/json
@@ -760,16 +286,13 @@ interactions:
       connection:
       - keep-alive
       content-length:
-      - '2548'
+      - '1222'
       content-type:
       - application/json
-      cookie:
-      - __cf_bm=N_ULh2gJbt2dWumbG8h6_rw_QD0TBQ3f1NYS.FsG3w0-1756165097-1.0.1.1-fGULs7H8u7wOLv7QAwRQdlWcZr2zj6dkLXQk5xPa.7SBOn9qj1nh6.VDONMzgxqO2telES4KZZPzeC2G4YFJXV5Q4hemTm4jcMsXA10XFYM;
-        _cfuvid=_3IyqhyxR3x9q67TqmIC1eWhmeXZIMbk_6ChUHMngHM-1756165097262-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.93.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
@@ -779,52 +302,54 @@ interactions:
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.93.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
       x-stainless-read-timeout:
-      - '600.0'
+      - '600'
       x-stainless-retry-count:
       - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.12.9
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
     body:
       string: !!binary |
-        H4sIAAAAAAAAA5xVTY/bRgy9+1cQuvRiL7zfW98WKVoYCNoiSHpoHRjjESUxOxoKQ8peI9j/XnC0
-        lrxpChS9CNJw+PhIPlJfZwAFlcUKCt849W0XFu8edtcfPskfhO/p+Vjq49Ofx19/2/10uPz0Cxdz
-        8+DdF/R68rrw3HYBlTgOZp/QKRrq5f3t3eXd7fLH+2xoucRgbnWnixteXC2vbhbLh8Xy7tWxYfIo
-        xQr+mgEAfM1PoxhLfC5WsJyfTloUcTUWq/ESQJE42EnhREjURS3mk9FzVIyZ9ceG+7rRFazhQCEA
-        7l3onSJog6CkAWHnBEvgCKQCHZsnuQDUds7rHBIG3LvocQ4ulkBRMaEoBNxjACfQYcpoNe0xQo79
-        rBebuIkL+H2EW2e4FXwc424Kex/CAFfwuAaKGanqtU9oZwdOT5sCpK9rFBVwUJL4XoQ4GuWGD+an
-        6JvIgWtCGfLU5KJUnNoM0QXnUeZwaMg3QIYjVEeqyLuoOS+lFsMRlDvycCBt4EAlLhI631CsjWcg
-        76z1cmGpfTjVZchJ+qwUA2+obsLxVDi1Gj2uoXECO8QIFE01QrEOx1zOOpmG7JVh7xJxL+CkQ69y
-        qsEcKFahx+iNyxfegQlAhpYkLLGimFnGshdNhAPH9alZ761ZRpTktfokEOhpSBmcarIunBdlbHTZ
-        o93JLU58sDC+T8RCeszxPUePKULC2qXS7I/rHyQzPHXUcqg4mYha95SZKjiwccIQ7HsofMXpvMND
-        doIu+SYr6h1HoRJT9mhQ8FSo+UngXeI9lWgd9pwwI45azxhnIxH5AN7FLF1wUNs0g4tywLSJP1N0
-        AR7z1wpuYfH/tDsJYrhe9WEcKn07U5bVWbVHDTs1ftNoDgHfiJ7iKB1Th6BXTjKgq0xDbNgca86h
-        xkILuB33+k0C2HaBjy1GvTjfLgmrXpwtt9iHcGZwMbIOE2J77fOr5WXcZIHrLvFOvnEtTLzSbG0q
-        ONrWEuWuyNaXGcDnvDH7N0uw6BK3nW6VnzCHu72+GvCKaUdP1qvl7atVWV2YDPfX9/PvAG5LVEdB
-        zpZu4Z1vsJxcpw3t+pL4zDA7S/ufdL6HPaROsf4v8JPBe+wUy22XsCT/NuXpWkLbTP92bSxzJlwI
-        pj153CphslaUWLk+DL+XQo6i2G4rijWmLtHwj6m67c3drqqWuPQPxexl9jcAAAD//wMAzZYQhWwH
-        AAA=
+        H4sIAAAAAAAAAwAAAP//jFRNj9tGDL37VxBzlo2113Y2ewsKBNkCRS6L9tANDHqGkpgdDYUZyo4T
+        7H8vKDlrJ02BXgx5HvnIx69vMwDHwd2D8y2q7/o4/+0v2m7LzR/1l+Vt1z2u059fb99/8L8fTo9f
+        P7rKPGT/mbx+91p46fpIypIm2GdCJWNdvtku795ut9vtCHQSKJpb0+t8vVjOO048X92sNvOb9Xy5
+        Pru3wp6Ku4e/ZwAA38ZfSzQF+uLu4ab6/tJRKdiQu381AnBZor04LIWLYlJXXUAvSSmNuT+2MjSt
+        3sMDJDmCxwQNHwgQGhMAmMqR8lN6zwkjvBv/mfFRhhigeMkE2hIoayR4co8tAXc9egWp4d0DcBrx
+        etAhk70dJT8/OUBYgwyj1WYBj68UXKDlpo0nyBTpgEnHhCYWTlbWwqkBE3gJUVrs7dXI+4ieCmAK
+        8Fn20GF+Ji0LeFAj95Ewj2DRjNy0Wks+Yg5G46XrhsQe1chGXdKzr6DDZ3thBcJygloy4BCYkkVS
+        gSEFylbnMKkVPxSw8kETMXmaFFJqsKGOkkKkA0XLp0jkUAEWU2L+50qZEginhB17o9JsNd1nQctU
+        KVNRQJ+lFOAUhqKZqSzggxzpQLm66oofe7UnKNH0xhN01jabWIrRdO1PgCHYV+nJc20hTSL0WQ5i
+        5TgQUJxSVwFKrakC1gK92CwxxnPfKyiDb02QWbOka1oo5FXyyO5bjJFSY1l/PFDGGCurMBdAa46k
+        pnodgmqszdS8SdWRtb0Kbi05V+ecRmvdGeeMU1HCYOOC0FOuyStsFtcrkakeCtpepiHGKwBTEkXT
+        MS7jpzPy8rp+UZo+y7785OpqTlzanc2rJFu1otK7EX2ZAXwa13z4YXNdn6XrdafyTGO41Xo18bnL
+        ebmgy83mjKooxgtw+/ZN9QvCXSBFjuXqUjiPvqVwcb2cFZtvuQJmV7L/nc6vuCfpnJr/Q38BvKde
+        Kez6TIH9j5IvZpns/P6X2WuZx4RdoXxgTztlytaKQDUOcbqJrpyKUrerOTWU+8zTYaz73dqv7jbL
+        +m67crOX2T8AAAD//wMAu+XbmCcGAAA=
     headers:
       CF-RAY:
-      - 974eec121c168486-SJC
+      - 997186f4ef56dd1f-FCO
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Mon, 25 Aug 2025 23:38:21 GMT
+      - Fri, 31 Oct 2025 07:44:28 GMT
       Server:
       - cloudflare
+      Set-Cookie:
+      - __cf_bm=8qRmqHic3PKOkCdnlc5s2fTHlZ8fBzfDa2aJ.xrQBBg-1761896668-1.0.1.1-JIBosm31AwPEXmz19O636o_doSclt_nENWvAfvp_gbjWPtfO2e99BjAvWJsUWjHVZGRlO6DJILFTRbA7iKdYGQykSCe_mj9a9644nS5E6VA;
+        path=/; expires=Fri, 31-Oct-25 08:14:28 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=TlYX1UMlEMLrIXQ.QBUJAS4tT0N5uBkshUKYyJjd9.g-1761896668679-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
       Strict-Transport-Security:
       - max-age=31536000; includeSubDomains; preload
       Transfer-Encoding:
@@ -840,39 +365,41 @@ interactions:
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '3958'
+      - '2019'
       openai-project:
       - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
       x-envoy-upstream-service-time:
-      - '4032'
-      x-ratelimit-limit-project-requests:
-      - '10000'
+      - '2126'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
       x-ratelimit-limit-requests:
-      - '10000'
+      - '30000'
       x-ratelimit-limit-tokens:
-      - '30000000'
-      x-ratelimit-remaining-project-requests:
-      - '9999'
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999720'
       x-ratelimit-remaining-requests:
-      - '9999'
+      - '29999'
       x-ratelimit-remaining-tokens:
-      - '29999412'
-      x-ratelimit-reset-project-requests:
-      - 6ms
+      - '149999720'
+      x-ratelimit-reset-project-tokens:
+      - 0s
       x-ratelimit-reset-requests:
-      - 6ms
+      - 2ms
       x-ratelimit-reset-tokens:
-      - 1ms
+      - 0s
       x-request-id:
-      - req_bd8ada32c9474dad85877e84f73b632b
+      - req_019c6c76f5414041b69f973973952df4
     status:
       code: 200
       message: OK
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Crew Manager. You
-      are a seasoned manager with a knack for getting the best out of your team.\nYou
+    body: '{"messages":[{"role":"system","content":"You are Crew Manager. You are
+      a seasoned manager with a knack for getting the best out of your team.\nYou
       are also known for your ability to delegate work to the right people, and to
       ask the right questions to get the best out of your team.\nEven though you don''t
       perform tasks by yourself, you have a lot of experience in the field, which
@@ -903,25 +430,33 @@ interactions:
       to wrap keys and values.\nObservation: the result of the action\n```\n\nOnce
       all necessary information is gathered, return the following format:\n\n```\nThought:
       I now know the final answer\nFinal Answer: the final answer to the original
-      input question\n```"}, {"role": "user", "content": "\nCurrent Task: Give me
-      an integer score between 1-5 for the following title: ''The impact of AI in
-      the future of work''\n\nThis is the expected criteria for your final answer:
-      The score of the title.\nyou MUST return the actual complete content as the
-      final answer, not a summary.\nEnsure your final answer contains only the content
-      in the following format: {\n  \"score\": int\n}\n\nEnsure the final output does
-      not include any code block markers like ```json or ```python.\n\nBegin! This
-      is VERY important to you, use the tools available and give your best Final Answer,
-      your job depends on it!\n\nThought:"}, {"role": "assistant", "content": "Thought:
-      I need to delegate the task of scoring the title to our Scorer, providing them
-      with context about the title and the task at hand.\n\nAction: Delegate work
-      to coworker\nAction Input: {\"task\": \"Score the title ''The impact of AI in
-      the future of work'' on a scale from 1 to 5.\", \"context\": \"The task involves
-      evaluating the given title and providing an integer score between 1 and 5 based
-      on the title''s potential impact, relevance, and interest level.\", \"coworker\":
-      \"Scorer\"}\nObservation: 5 - The title \"The impact of AI in the future of
-      work\" is highly impactful, relevant, and interesting due to the transformative
-      potential of AI technologies in various job sectors and its relevance to ongoing
-      discussions about the future of employment."}], "model": "gpt-4o", "stop": ["\nObservation:"]}'
+      input question\n```"},{"role":"user","content":"\nCurrent Task: Give me an integer
+      score between 1-5 for the following title: ''The impact of AI in the future
+      of work''\n\nThis is the expected criteria for your final answer: The score
+      of the title.\nyou MUST return the actual complete content as the final answer,
+      not a summary.\nEnsure your final answer contains only the content in the following
+      format: {\n  \"properties\": {\n    \"score\": {\n      \"title\": \"Score\",\n      \"type\":
+      \"integer\"\n    }\n  },\n  \"required\": [\n    \"score\"\n  ],\n  \"title\":
+      \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\": false\n}\n\nEnsure
+      the final output does not include any code block markers like ```json or ```python.\n\nBegin!
+      This is VERY important to you, use the tools available and give your best Final
+      Answer, your job depends on it!\n\nThought:"},{"role":"assistant","content":"To
+      complete the task, I need to delegate the scoring of the title ''The impact
+      of AI in the future of work'' to the Scorer. \n\nAction: Delegate work to coworker\nAction
+      Input: {\"task\": \"Evaluate and provide an integer score between 1-5 for the
+      title ''The impact of AI in the future of work''. Consider factors such as relevance,
+      clarity, engagement, and potential impact of the title.\", \"context\": \"This
+      score will be used to assess the quality of the title in terms of its relevance
+      and impact.\", \"coworker\": \"Scorer\"}\nObservation: I would score the title
+      \"The impact of AI in the future of work\" a 4 out of 5. The title is highly
+      relevant given the increasing role of AI in shaping workplaces and job markets.
+      It is clear and straightforward in communicating the topic, making it easy for
+      audiences to understand the focus at a glance. The engagement level is solid,
+      as AI and future work dynamics attract broad interest across industries. However,
+      the title could be slightly more compelling by adding specifics or a provocative
+      element to enhance its potential impact, such as mentioning specific sectors
+      or challenges. Overall, it is a strong, relevant, and clear title with potential
+      for broad impact, hence a 4 instead of a perfect 5."}],"model":"gpt-4o"}'
     headers:
       accept:
       - application/json
@@ -930,16 +465,16 @@ interactions:
       connection:
       - keep-alive
       content-length:
-      - '3994'
+      - '4667'
       content-type:
       - application/json
       cookie:
-      - __cf_bm=N_ULh2gJbt2dWumbG8h6_rw_QD0TBQ3f1NYS.FsG3w0-1756165097-1.0.1.1-fGULs7H8u7wOLv7QAwRQdlWcZr2zj6dkLXQk5xPa.7SBOn9qj1nh6.VDONMzgxqO2telES4KZZPzeC2G4YFJXV5Q4hemTm4jcMsXA10XFYM;
-        _cfuvid=_3IyqhyxR3x9q67TqmIC1eWhmeXZIMbk_6ChUHMngHM-1756165097262-0.0.1.1-604800000
+      - __cf_bm=n45oVEbg4Ph05GBqJp2KyKI77cF1e_lNGmWrdQjbV20-1761896666-1.0.1.1-hTLlylCKTisapDYTpS63zm.2k2AGNs0DvyKGQ6MEtJHyYJBoXKqzsHRbsZN_dbtjm4Kj_5RG3J73ysTSs817q_9mvPtjHgZOvOPhDwGxV_M;
+        _cfuvid=gOhnFtutoiWlRm84LU88kCfEmlv5P_3_ZJ_wlDnkYy4-1761896666288-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.93.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
@@ -949,42 +484,41 @@ interactions:
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.93.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
       x-stainless-read-timeout:
-      - '600.0'
+      - '600'
       x-stainless-retry-count:
       - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.12.9
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
     body:
       string: !!binary |
-        H4sIAAAAAAAAAwAAAP//jFLBbtQwEL3nK0Y+b6pkd5OmuRUQEgiJIgE9kCry2pPErGNbtsOCVvvv
-        yMl2k9JW4uLDvHnj997MMQIggpMSCOuoZ72R8dtit/levOkG/u72k9x/zL7d8DuXfjl8vr++I6vA
-        0LufyPwj64rp3kj0QqsJZhapxzA1vc7yNM/SJB2BXnOUgdYaH291vE7W2zgp4iQ/EzstGDpSwo8I
-        AOA4vkGi4viblJCsHis9OkdbJOWlCYBYLUOFUOeE81R5sppBppVHNar+2umh7XwJH0DpA+zD4zuE
-        RigqgSp3QHtVqUq9Hwu3Y6GEY6UAKuKYtliRErJKnZY/WGwGR4NBNUi5AKhS2tMQ0Ojt4YycLm6k
-        bo3VO/cPlTRCCdfVFqnTKih3XhsyoqcI4GFMbXgSBDFW98bXXu9x/K7Ybqd5ZN7TjK7TM+i1p3LB
-        yrPVC/Nqjp4K6Ra5E0ZZh3ymzkuiAxd6AUQL18/VvDR7ci5U+z/jZ4AxNB55bSxywZ46ntsshjN+
-        re2S8iiYOLS/BMPaC7RhExwbOsjpwoj74zz2dSNUi9ZYMZ1ZY+oiucnybLNhOxKdor8AAAD//wMA
-        Q4ZWRG8DAAA=
+        H4sIAAAAAAAAAwAAAP//jJNdb9MwFIbv8yssX7corda05A6QkLhhwJiQWKbItU8SU8f27GPGqPLf
+        JydZkxaQuHHk85xPvyfHhBAqBc0J5Q1D3lq1fPcNsl34Ut+m2Hj2/bo9fLyxD28/t+H37ZouYoTZ
+        /wCOL1GvuGmtApRGD5g7YAgx62qbrXavsyzb9aA1AlQMqy0ur8xyna6vlulumWZjYGMkB09zcpcQ
+        QsixP2OLWsAvmpN08WJpwXtWA81PToRQZ1S0UOa99Mg00sUEudEIuu/6a2NC3WBOPhBtHskhHtgA
+        qaRmijDtH8EV+n1/e9PfcnIsNCEFtc5YcCjBF3Q0RrPnxsHMEm0oUfW2gt4MeDGDT3ZkUiPU4Ao6
+        wC5+usVQzcFDkA5E9Ly7qBWv96PfZanrgDbgWHBebFDuBJgQMurG1KezuSqmPBS6m7+fgyp4FuXT
+        QakZYFobZDFNr9z9SLqTVsrU1pm9vwilldTSN6UD5o2Oung0lva0S+JwcSfCmczx/VuLJZoD9OVW
+        aTouBZ3WcMLbzQjRIFPzsBM5y1gKQCaVn+0V5Yw3IKbYaQlZENLMQDKb+892/pZ7mF3q+n/ST4Bz
+        sAiitA6E5OcjT24Ootj/cju9c98w9eB+Sg4lSnBRCwEVC2r4g6h/8ghtWUldg7NODr9RZUu+r1bb
+        3WaTbWnSJc8AAAD//wMAQ/5c5U8EAAA=
     headers:
       CF-RAY:
-      - 974eec2bee738486-SJC
+      - 997187038d85ea38-FCO
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Mon, 25 Aug 2025 23:38:22 GMT
+      - Fri, 31 Oct 2025 07:44:29 GMT
       Server:
       - cloudflare
       Strict-Transport-Security:
@@ -1002,13 +536,15 @@ interactions:
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '879'
+      - '740'
       openai-project:
       - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
       x-envoy-upstream-service-time:
-      - '923'
+      - '772'
+      x-openai-proxy-wasm:
+      - v0.1
       x-ratelimit-limit-project-requests:
       - '10000'
       x-ratelimit-limit-requests:
@@ -1020,68 +556,25 @@ interactions:
       x-ratelimit-remaining-requests:
       - '9999'
       x-ratelimit-remaining-tokens:
-      - '29999055'
+      - '29998885'
       x-ratelimit-reset-project-requests:
       - 6ms
       x-ratelimit-reset-requests:
       - 6ms
       x-ratelimit-reset-tokens:
-      - 1ms
+      - 2ms
       x-request-id:
-      - req_5699dd0d905247f6b4b41d76411079e0
+      - req_5c525e6992a14138826044dd5a2becf9
     status:
       code: 200
       message: OK
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Crew Manager. You
-      are a seasoned manager with a knack for getting the best out of your team.\nYou
-      are also known for your ability to delegate work to the right people, and to
-      ask the right questions to get the best out of your team.\nEven though you don''t
-      perform tasks by yourself, you have a lot of experience in the field, which
-      allows you to properly evaluate the work of your team members.\nYour personal
-      goal is: Manage the team to complete the task in the best way possible.\nYou
-      ONLY have access to the following tools, and should NEVER make up tools that
-      are not listed here:\n\nTool Name: Delegate work to coworker\nTool Arguments:
-      {''task'': {''description'': ''The task to delegate'', ''type'': ''str''}, ''context'':
-      {''description'': ''The context for the task'', ''type'': ''str''}, ''coworker'':
-      {''description'': ''The role/name of the coworker to delegate to'', ''type'':
-      ''str''}}\nTool Description: Delegate a specific task to one of the following
-      coworkers: Scorer\nThe input to this tool should be the coworker, the task you
-      want them to do, and ALL necessary context to execute the task, they know nothing
-      about the task, so share absolutely everything you know, don''t reference things
-      but instead explain them.\nTool Name: Ask question to coworker\nTool Arguments:
-      {''question'': {''description'': ''The question to ask'', ''type'': ''str''},
-      ''context'': {''description'': ''The context for the question'', ''type'': ''str''},
-      ''coworker'': {''description'': ''The role/name of the coworker to ask'', ''type'':
-      ''str''}}\nTool Description: Ask a specific question to one of the following
-      coworkers: Scorer\nThe input to this tool should be the coworker, the question
-      you have for them, and ALL necessary context to ask the question properly, they
-      know nothing about the question, so share absolutely everything you know, don''t
-      reference things but instead explain them.\n\nIMPORTANT: Use the following format
-      in your response:\n\n```\nThought: you should always think about what to do\nAction:
-      the action to take, only one name of [Delegate work to coworker, Ask question
-      to coworker], just the name, exactly as it''s written.\nAction Input: the input
-      to the action, just a simple JSON object, enclosed in curly braces, using \"
-      to wrap keys and values.\nObservation: the result of the action\n```\n\nOnce
-      all necessary information is gathered, return the following format:\n\n```\nThought:
-      I now know the final answer\nFinal Answer: the final answer to the original
-      input question\n```"}, {"role": "user", "content": "\nCurrent Task: Give me
-      an integer score between 1-5 for the following title: ''The impact of AI in
-      the future of work''\n\nThis is the expected criteria for your final answer:
-      The score of the title.\nyou MUST return the actual complete content as the
-      final answer, not a summary.\nEnsure your final answer contains only the content
-      in the following format: {\n  \"score\": int\n}\n\nEnsure the final output does
-      not include any code block markers like ```json or ```python.\n\nBegin! This
-      is VERY important to you, use the tools available and give your best Final Answer,
-      your job depends on it!\n\nThought:"}, {"role": "assistant", "content": "Thought:
-      I need to delegate the task of scoring the title to our Scorer, providing them
-      with context about the title and the task at hand.\n\nAction: Delegate work
-      to coworker\nAction Input: {\"task\": \"Score the title ''The impact of AI in
-      the future of work'' on a scale from 1 to 5.\", \"context\": \"The task involves
-      evaluating the given title and providing an integer score between 1 and 5 based
-      on the title''s potential impact, relevance, and interest level.\", \"coworker\":
-      \"Scorer\"}\nObservation: {\n  \"score\": 5\n}"}], "model": "gpt-4o", "stop":
-      ["\nObservation:"]}'
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    score: int\n}\n```"},{"role":"user","content":"{\n  \"properties\":
+      {\n    \"score\": {\n      \"title\": \"Score\",\n      \"type\": \"integer\"\n    }\n  },\n  \"required\":
+      [\n    \"score\"\n  ],\n  \"title\": \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\":
+      false\n}"}],"model":"gpt-4o","response_format":{"type":"json_schema","json_schema":{"schema":{"properties":{"score":{"title":"Score","type":"integer"}},"required":["score"],"title":"ScoreOutput","type":"object","additionalProperties":false},"name":"ScoreOutput","strict":true}},"stream":false}'
     headers:
       accept:
       - application/json
@@ -1090,60 +583,60 @@ interactions:
       connection:
       - keep-alive
       content-length:
-      - '3760'
+      - '779'
       content-type:
       - application/json
       cookie:
-      - __cf_bm=N_ULh2gJbt2dWumbG8h6_rw_QD0TBQ3f1NYS.FsG3w0-1756165097-1.0.1.1-fGULs7H8u7wOLv7QAwRQdlWcZr2zj6dkLXQk5xPa.7SBOn9qj1nh6.VDONMzgxqO2telES4KZZPzeC2G4YFJXV5Q4hemTm4jcMsXA10XFYM;
-        _cfuvid=_3IyqhyxR3x9q67TqmIC1eWhmeXZIMbk_6ChUHMngHM-1756165097262-0.0.1.1-604800000
+      - __cf_bm=n45oVEbg4Ph05GBqJp2KyKI77cF1e_lNGmWrdQjbV20-1761896666-1.0.1.1-hTLlylCKTisapDYTpS63zm.2k2AGNs0DvyKGQ6MEtJHyYJBoXKqzsHRbsZN_dbtjm4Kj_5RG3J73ysTSs817q_9mvPtjHgZOvOPhDwGxV_M;
+        _cfuvid=gOhnFtutoiWlRm84LU88kCfEmlv5P_3_ZJ_wlDnkYy4-1761896666288-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.93.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
       - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
       x-stainless-lang:
       - python
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.93.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
       x-stainless-read-timeout:
-      - '600.0'
+      - '600'
       x-stainless-retry-count:
       - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.12.9
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
     body:
       string: !!binary |
-        H4sIAAAAAAAAAwAAAP//jFJBbtswELzrFQuerUB2LVXVLQnQoufmEKAKBJpaSawpLkFSdgvDfy9I
-        u5bSpkAuBMjZGc7s7ikBYLJlFTAxcC9Go9LHcrf9dnh+mO7p+VN+3PdPGvcH9+XD7rHs2CowaPcD
-        hf/DuhM0GoVekr7AwiL3GFTXH/NiXeTrIovASC2qQOuNT7eUbrLNNs3KNCuuxIGkQMcq+J4AAJzi
-        GSzqFn+yCqJMfBnROd4jq25FAMySCi+MOyed59qz1QwK0h51dP000NQPvoKvoOkI+3D4AaGTmivg
-        2h3R3tX6c7zex2sFp1oD1MwJslizCvJan5f6FrvJ8RBPT0otAK41eR7aE5O9XJHzLYui3ljaub+o
-        rJNauqGxyB3p4Nt5Miyi5wTgJfZsetUGZiyNxjee9hi/K7P8osfmKc3oZn0FPXmuFqxNsXpDr2nR
-        c6ncoutMcDFgO1PnEfGplbQAkkXqf928pX1JLnX/HvkZEAKNx7YxFlspXieeyyyGJf5f2a3L0TBz
-        aA9SYOMl2jCJFjs+qct+MffLeRybTuoerbHysmSdabbFrusyzETJknPyGwAA//8DAAH6vKZtAwAA
+        H4sIAAAAAAAAAwAAAP//jJJBj9MwEIXv+RXWnBuUljZNc13BAXFDYgXsKnLtSWpwPJY9QUDV/46c
+        dJssLBIXH/zNG783nnMmBBgNtQB1kqx6b/O7eywP4dMv87548/mePn7A4a6qlHz91r0LsEoKOn5F
+        xU+qV4p6b5ENuQmrgJIxdV3vy3V1KMvyMIKeNNok6zznW8o3xWabF1VelFfhiYzCCLX4kgkhxHk8
+        k0Wn8QfUolg93fQYo+wQ6luREBDIphuQMZrI0jGsZqjIMbrR9fkBoqKAD1AXl2VNwHaIMll0g7UL
+        IJ0jlini6O7xSi43P5Y6H+gY/5BCa5yJpyagjOTS25HJw0gvmRCPY+7hWRTwgXrPDdM3HJ9bb/dT
+        P5gnPdPdlTGxtAvRbrN6oV2jkaWxcTE4UFKdUM/Secpy0IYWIFuE/tvMS72n4MZ1/9N+BkqhZ9SN
+        D6iNeh54LguY9vBfZbchj4YhYvhuFDZsMKSP0NjKwU4rAvFnZOyb1rgOgw9m2pPWN+rYrvfVblfu
+        IbtkvwEAAP//AwCH29h7MAMAAA==
     headers:
       CF-RAY:
-      - 974eed9bdf8aeb2a-SJC
+      - 997187099d02ea38-FCO
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Mon, 25 Aug 2025 23:39:21 GMT
+      - Fri, 31 Oct 2025 07:44:30 GMT
       Server:
       - cloudflare
       Strict-Transport-Security:
@@ -1161,13 +654,15 @@ interactions:
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '1085'
+      - '409'
       openai-project:
       - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
       x-envoy-upstream-service-time:
-      - '1107'
+      - '447'
+      x-openai-proxy-wasm:
+      - v0.1
       x-ratelimit-limit-project-requests:
       - '10000'
       x-ratelimit-limit-requests:
@@ -1179,15 +674,15 @@ interactions:
       x-ratelimit-remaining-requests:
       - '9999'
       x-ratelimit-remaining-tokens:
-      - '29999114'
+      - '29999903'
       x-ratelimit-reset-project-requests:
       - 6ms
       x-ratelimit-reset-requests:
       - 6ms
       x-ratelimit-reset-tokens:
-      - 1ms
+      - 0s
       x-request-id:
-      - req_1b900c7238124d04835cb54adf6d7aeb
+      - req_c1d2e65ce5244e49bbc31969732c9b54
     status:
       code: 200
       message: OK
diff --git a/lib/crewai/tests/cassettes/test_output_pydantic_sequential.yaml b/lib/crewai/tests/cassettes/test_output_pydantic_sequential.yaml
--- a/lib/crewai/tests/cassettes/test_output_pydantic_sequential.yaml
+++ b/lib/crewai/tests/cassettes/test_output_pydantic_sequential.yaml
@@ -204,4 +204,235 @@ interactions:
       - req_d24b98d762df8198d3d365639be80fe4
     http_version: HTTP/1.1
     status_code: 200
+- request:
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    score: int\n}\n```"},{"role":"user","content":"4"}],"model":"gpt-4.1-mini"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '277'
+      content-type:
+      - application/json
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAA4yST2+cMBDF73wKa85LBITsEm5VKvWUQ0/9RwReM7BOzdi1TbXVar97ZdgspE2l
+        XjjMb97w3nhOEWMgWygZiAP3YjAqfvj0+ajl7iM9dI9ff2w5T+Rx3+fvvjx+OL6HTVDo/TMK/6K6
+        EXowCr3UNGNhkXsMU9PdNi12t0lRTGDQLaog642P85s0HiTJOEuyuzjJ4zS/yA9aCnRQsm8RY4yd
+        pm8wSi0eoWTJ5qUyoHO8RyivTYyB1SpUgDsnnefkYbNAockjTd6bpnl2mio6VRRYBU5oixWULK/o
+        XFHTNGupxW50PPinUakV4ETa85B/Mv10IeerTaV7Y/Xe/SGFTpJ0h9oid5qCJee1gYmeI8aepnWM
+        rxKCsXowvvb6O06/y+/ncbC8wgLT2wv02nO11LfZ5o1pdYueS+VW6wTBxQHbRbnsno+t1CsQrTL/
+        beat2XNuSf3/jF+AEGg8trWx2ErxOvDSZjHc6L/arjueDIND+1MKrL1EG96hxY6Paj4ccL+cx6Hu
+        JPVojZXz9XSmzkVW3KVdsc0gOke/AQAA//8DAILgqohMAwAA
+    headers:
+      CF-RAY:
+      - 996f4750dfd259cb-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 01:11:28 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=NFLqe8oMW.d350lBeNJ9PQDQM.Rj0B9eCRBNNKM18qg-1761873088-1.0.1.1-Ipgawg95icfLAihgKfper9rYrjt3ZrKVSv_9lKRqJzx.FBfkZrcDqSW3Zt7TiktUIOSgO9JpX3Ia3Fu9g3DMTwWpaGJtoOj3u0I2USV9.qQ;
+        path=/; expires=Fri, 31-Oct-25 01:41:28 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=dQQqd3jb3DFD.LOIZmhxylJs2Rzp3rGIU3yFiaKkBls-1761873088861-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '481'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '570'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999952'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999955'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_1b331f2fb8d943249e9c336608e2f2cf
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    score: int\n}\n```"},{"role":"user","content":"4"}],"model":"gpt-4.1-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"properties":{"score":{"title":"Score","type":"integer"}},"required":["score"],"title":"ScoreOutput","type":"object","additionalProperties":false},"name":"ScoreOutput","strict":true}},"stream":false}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '541'
+      content-type:
+      - application/json
+      cookie:
+      - __cf_bm=NFLqe8oMW.d350lBeNJ9PQDQM.Rj0B9eCRBNNKM18qg-1761873088-1.0.1.1-Ipgawg95icfLAihgKfper9rYrjt3ZrKVSv_9lKRqJzx.FBfkZrcDqSW3Zt7TiktUIOSgO9JpX3Ia3Fu9g3DMTwWpaGJtoOj3u0I2USV9.qQ;
+        _cfuvid=dQQqd3jb3DFD.LOIZmhxylJs2Rzp3rGIU3yFiaKkBls-1761873088861-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jFLLbtswELzrK4g9W4HlyI6sWx8IeuulQIs2gUCTK4kpRRLkKnBg+N8L
+        SrYl5wH0osPOznBmtIeEMVASSgai5SQ6p9MvP3/t3Tf6JFX79ffL04/b5+/Z/X672zT55x4WkWF3
+        TyjozLoRtnMaSVkzwsIjJ4yq2d0mK+5ul8V2ADorUUda4yjNb7K0U0alq+VqnS7zNMtP9NYqgQFK
+        9idhjLHD8I1GjcQ9lGy5OE86DIE3COVliTHwVscJ8BBUIG4IFhMorCE0g/fDAwRhPT5AmR/nOx7r
+        PvBo1PRazwBujCUegw7uHk/I8eJH28Z5uwuvqFAro0JbeeTBmvh2IOtgQI8JY49D7v4qCjhvO0cV
+        2b84PFesRzmY6p7AM0aWuJ7G21NV12KVROJKh1ltILhoUU7MqWPeS2VnQDKL/NbLe9pjbGWa/5Gf
+        ACHQEcrKeZRKXOed1jzGW/xo7VLxYBgC+mclsCKFPv4GiTXv9XggEF4CYVfVyjTonVfjldSuysWq
+        WGd1sVlBckz+AQAA//8DAKv/0dE0AwAA
+    headers:
+      CF-RAY:
+      - 996f4755989559cb-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 01:11:29 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '400'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '659'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999955'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999955'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_7829900551634a0db8009042f31db7fc
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_output_pydantic_to_another_task.yaml b/lib/crewai/tests/cassettes/test_output_pydantic_to_another_task.yaml
--- a/lib/crewai/tests/cassettes/test_output_pydantic_to_another_task.yaml
+++ b/lib/crewai/tests/cassettes/test_output_pydantic_to_another_task.yaml
@@ -1,242 +1,137 @@
 interactions:
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Scorer. You''re an
-      expert scorer, specialized in scoring titles.\nYour personal goal is: Score
-      the title\nTo give my best complete final answer to the task use the exact following
-      format:\n\nThought: I now can give a great answer\nFinal Answer: Your final
-      answer must be the great and the most complete as possible, it must be outcome
-      described.\n\nI MUST use these formats, my job depends on it!"}, {"role": "user",
-      "content": "\nCurrent Task: Give me an integer score between 1-5 for the following
-      title: ''The impact of AI in the future of work''\n\nThis is the expect criteria
-      for your final answer: The score of the title.\nyou MUST return the actual complete
-      content as the final answer, not a summary.\n\nBegin! This is VERY important
-      to you, use the tools available and give your best Final Answer, your job depends
-      on it!\n\nThought:"}], "model": "gpt-4-0125-preview"}'
-    headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '927'
-      content-type:
-      - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
-    method: POST
-    uri: https://api.openai.com/v1/chat/completions
-  response:
-    content: "{\n  \"id\": \"chatcmpl-AB7gEbfUEcEY8uxRqngZ1AHO3Kh8G\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214494,\n  \"model\": \"gpt-4-0125-preview\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": \"Thought: I now can give a great answer\\nFinal
-      Answer: 4\",\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      187,\n    \"completion_tokens\": 15,\n    \"total_tokens\": 202,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": null\n}\n"
+    body: '{"trace_id": "f4e3d2a7-6f34-4327-afca-c78e71cadd72", "execution_type":
+      "crew", "user_identifier": null, "execution_context": {"crew_fingerprint": null,
+      "crew_name": "crew", "flow_name": null, "crewai_version": "1.2.1", "privacy_level":
+      "standard"}, "execution_metadata": {"expected_duration_estimate": 300, "agent_count":
+      0, "task_count": 0, "flow_method_count": 0, "execution_started_at": "2025-10-31T21:52:20.918825+00:00"},
+      "ephemeral_trace_id": "f4e3d2a7-6f34-4327-afca-c78e71cadd72"}'
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85fa3b6b9e1cf3-GRU
+      Accept:
+      - '*/*'
+      Accept-Encoding:
+      - gzip, deflate, zstd
       Connection:
       - keep-alive
-      Content-Encoding:
-      - gzip
+      Content-Length:
+      - '488'
       Content-Type:
       - application/json
-      Date:
-      - Tue, 24 Sep 2024 21:48:14 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
-      - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '730'
-      openai-version:
-      - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '2000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '1999781'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 6ms
-      x-request-id:
-      - req_7229ec6efc9642277f866a4769b8428c
-    http_version: HTTP/1.1
-    status_code: 200
-- request:
-    body: '{"messages": [{"role": "user", "content": "4"}, {"role": "system", "content":
-      "I''m gonna convert this raw text into valid JSON.\n\nThe json should have the
-      following structure, with the following keys:\n{\n    score: int\n}"}], "model":
-      "gpt-3.5-turbo-0125", "tool_choice": {"type": "function", "function": {"name":
-      "ScoreOutput"}}, "tools": [{"type": "function", "function": {"name": "ScoreOutput",
-      "description": "Correctly extracted `ScoreOutput` with all the required parameters
-      with correct types", "parameters": {"properties": {"score": {"title": "Score",
-      "type": "integer"}}, "required": ["score"], "type": "object"}}}]}'
-    headers:
-      accept:
-      - application/json
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '627'
-      content-type:
-      - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
-      host:
-      - api.openai.com
-      user-agent:
-      - OpenAI/Python 1.47.0
-      x-stainless-arch:
-      - arm64
-      x-stainless-async:
-      - 'false'
-      x-stainless-lang:
-      - python
-      x-stainless-os:
-      - MacOS
-      x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
-      x-stainless-runtime:
-      - CPython
-      x-stainless-runtime-version:
-      - 3.11.7
+      User-Agent:
+      - CrewAI-CLI/1.2.1
+      X-Crewai-Organization-Id:
+      - 73c2b193-f579-422c-84c7-76a39a1da77f
+      X-Crewai-Version:
+      - 1.2.1
     method: POST
-    uri: https://api.openai.com/v1/chat/completions
+    uri: https://app.crewai.com/crewai_plus/api/v1/tracing/ephemeral/batches
   response:
-    content: "{\n  \"id\": \"chatcmpl-AB7gF9MWuZGxknKnrtesloXhXendq\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214495,\n  \"model\": \"gpt-3.5-turbo-0125\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": null,\n        \"tool_calls\": [\n          {\n
-      \           \"id\": \"call_vIxfdg9Ebnr1Z3TthsEcVXby\",\n            \"type\":
-      \"function\",\n            \"function\": {\n              \"name\": \"ScoreOutput\",\n
-      \             \"arguments\": \"{\\\"score\\\":4}\"\n            }\n          }\n
-      \       ],\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      103,\n    \"completion_tokens\": 5,\n    \"total_tokens\": 108,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": null\n}\n"
+    body:
+      string: '{"id":"2adb4334-2adb-4585-90b9-03921447ab54","ephemeral_trace_id":"f4e3d2a7-6f34-4327-afca-c78e71cadd72","execution_type":"crew","crew_name":"crew","flow_name":null,"status":"running","duration_ms":null,"crewai_version":"1.2.1","total_events":0,"execution_context":{"crew_fingerprint":null,"crew_name":"crew","flow_name":null,"crewai_version":"1.2.1","privacy_level":"standard"},"created_at":"2025-10-31T21:52:21.259Z","updated_at":"2025-10-31T21:52:21.259Z","access_code":"TRACE-c984d48836","user_identifier":null}'
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
-      CF-RAY:
-      - 8c85fa41bc891cf3-GRU
       Connection:
       - keep-alive
-      Content-Encoding:
-      - gzip
+      Content-Length:
+      - '515'
       Content-Type:
-      - application/json
+      - application/json; charset=utf-8
       Date:
-      - Tue, 24 Sep 2024 21:48:15 GMT
-      Server:
-      - cloudflare
-      Transfer-Encoding:
-      - chunked
-      X-Content-Type-Options:
-      - nosniff
-      access-control-expose-headers:
-      - X-Request-ID
-      openai-organization:
-      - crewai-iuxna1
-      openai-processing-ms:
-      - '253'
-      openai-version:
-      - '2020-10-01'
+      - Fri, 31 Oct 2025 21:52:21 GMT
+      cache-control:
+      - no-store
+      content-security-policy:
+      - 'default-src ''self'' *.app.crewai.com app.crewai.com; script-src ''self''
+        ''unsafe-inline'' *.app.crewai.com app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts
+        https://www.gstatic.com https://run.pstmn.io https://apis.google.com https://apis.google.com/js/api.js
+        https://accounts.google.com https://accounts.google.com/gsi/client https://cdnjs.cloudflare.com/ajax/libs/normalize/8.0.1/normalize.min.css.map
+        https://*.google.com https://docs.google.com https://slides.google.com https://js.hs-scripts.com
+        https://js.sentry-cdn.com https://browser.sentry-cdn.com https://www.googletagmanager.com
+        https://js-na1.hs-scripts.com https://js.hubspot.com http://js-na1.hs-scripts.com
+        https://bat.bing.com https://cdn.amplitude.com https://cdn.segment.com https://d1d3n03t5zntha.cloudfront.net/
+        https://descriptusercontent.com https://edge.fullstory.com https://googleads.g.doubleclick.net
+        https://js.hs-analytics.net https://js.hs-banner.com https://js.hsadspixel.net
+        https://js.hscollectedforms.net https://js.usemessages.com https://snap.licdn.com
+        https://static.cloudflareinsights.com https://static.reo.dev https://www.google-analytics.com
+        https://share.descript.com/; style-src ''self'' ''unsafe-inline'' *.app.crewai.com
+        app.crewai.com https://cdn.jsdelivr.net/npm/apexcharts; img-src ''self'' data:
+        *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com https://dashboard.tools.crewai.com
+        https://cdn.jsdelivr.net https://forms.hsforms.com https://track.hubspot.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://www.google.com
+        https://www.google.com.br; font-src ''self'' data: *.app.crewai.com app.crewai.com;
+        connect-src ''self'' *.app.crewai.com app.crewai.com https://zeus.tools.crewai.com
+        https://connect.useparagon.com/ https://zeus.useparagon.com/* https://*.useparagon.com/*
+        https://run.pstmn.io https://connect.tools.crewai.com/ https://*.sentry.io
+        https://www.google-analytics.com https://edge.fullstory.com https://rs.fullstory.com
+        https://api.hubspot.com https://forms.hscollectedforms.net https://api.hubapi.com
+        https://px.ads.linkedin.com https://px4.ads.linkedin.com https://google.com/pagead/form-data/16713662509
+        https://google.com/ccm/form-data/16713662509 https://www.google.com/ccm/collect
+        https://worker-actionkit.tools.crewai.com https://api.reo.dev; frame-src ''self''
+        *.app.crewai.com app.crewai.com https://connect.useparagon.com/ https://zeus.tools.crewai.com
+        https://zeus.useparagon.com/* https://connect.tools.crewai.com/ https://docs.google.com
+        https://drive.google.com https://slides.google.com https://accounts.google.com
+        https://*.google.com https://app.hubspot.com/ https://td.doubleclick.net https://www.googletagmanager.com/
+        https://www.youtube.com https://share.descript.com'
+      etag:
+      - W/"de8355cd003b150e7c530e4f15d97140"
+      expires:
+      - '0'
+      permissions-policy:
+      - camera=(), microphone=(self), geolocation=()
+      pragma:
+      - no-cache
+      referrer-policy:
+      - strict-origin-when-cross-origin
       strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
-      x-ratelimit-limit-requests:
-      - '10000'
-      x-ratelimit-limit-tokens:
-      - '50000000'
-      x-ratelimit-remaining-requests:
-      - '9999'
-      x-ratelimit-remaining-tokens:
-      - '49999946'
-      x-ratelimit-reset-requests:
-      - 6ms
-      x-ratelimit-reset-tokens:
-      - 0s
+      - max-age=63072000; includeSubDomains
+      vary:
+      - Accept
+      x-content-type-options:
+      - nosniff
+      x-frame-options:
+      - SAMEORIGIN
+      x-permitted-cross-domain-policies:
+      - none
       x-request-id:
-      - req_fe42bae7f8f0d8830aa96ac82a70bb78
-    http_version: HTTP/1.1
-    status_code: 200
+      - 09d43be3-106a-44dd-a9a2-816d53f91d5d
+      x-runtime:
+      - '0.066900'
+      x-xss-protection:
+      - 1; mode=block
+    status:
+      code: 201
+      message: Created
 - request:
-    body: '{"messages": [{"role": "system", "content": "You are Scorer. You''re an
-      expert scorer, specialized in scoring titles.\nYour personal goal is: Score
-      the title\nTo give my best complete final answer to the task use the exact following
+    body: '{"messages":[{"role":"system","content":"You are Scorer. You''re an expert
+      scorer, specialized in scoring titles.\nYour personal goal is: Score the title\nTo
+      give my best complete final answer to the task respond using the exact following
       format:\n\nThought: I now can give a great answer\nFinal Answer: Your final
       answer must be the great and the most complete as possible, it must be outcome
-      described.\n\nI MUST use these formats, my job depends on it!"}, {"role": "user",
-      "content": "\nCurrent Task: Given the score the title ''The impact of AI in
-      the future of work'' got, give me an integer score between 1-5 for the following
-      title: ''Return of the Jedi'', you MUST give it a score, use your best judgment\n\nThis
-      is the expect criteria for your final answer: The score of the title.\nyou MUST
-      return the actual complete content as the final answer, not a summary.\n\nThis
-      is the context you''re working with:\n4\n\nBegin! This is VERY important to
-      you, use the tools available and give your best Final Answer, your job depends
-      on it!\n\nThought:"}], "model": "gpt-4-0125-preview"}'
+      described.\n\nI MUST use these formats, my job depends on it!"},{"role":"user","content":"\nCurrent
+      Task: Give me an integer score between 1-5 for the following title: ''The impact
+      of AI in the future of work''\n\nThis is the expected criteria for your final
+      answer: The score of the title.\nyou MUST return the actual complete content
+      as the final answer, not a summary.\nEnsure your final answer contains only
+      the content in the following format: {\n  \"properties\": {\n    \"score\":
+      {\n      \"title\": \"Score\",\n      \"type\": \"integer\"\n    }\n  },\n  \"required\":
+      [\n    \"score\"\n  ],\n  \"title\": \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\":
+      false\n}\n\nEnsure the final output does not include any code block markers
+      like ```json or ```python.\n\nBegin! This is VERY important to you, use the
+      tools available and give your best Final Answer, your job depends on it!\n\nThought:"}],"model":"gpt-4o"}'
     headers:
       accept:
       - application/json
       accept-encoding:
-      - gzip, deflate
+      - gzip, deflate, zstd
       connection:
       - keep-alive
       content-length:
-      - '1076'
+      - '1334'
       content-type:
       - application/json
-      cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.47.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
@@ -246,170 +141,137 @@ interactions:
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.11.7
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
-    content: "{\n  \"id\": \"chatcmpl-AB7gFkgb0JsYMhXR8qaHnXKOQfP7B\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214495,\n  \"model\": \"gpt-4-0125-preview\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": \"Thought: I now can give a great answer\\n\\nFinal
-      Answer: 5\",\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      223,\n    \"completion_tokens\": 15,\n    \"total_tokens\": 238,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": null\n}\n"
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jFPLbtswELz7KxY824WdOPHjFgQokPbQFi2aolEgrMmVzIQiWXLlNAn8
+        7wElxZLTFuhFAmf2Ncvh8whAaCXWIOQWWVbeTC6vw8fi+pF31dWHO39xap++XH3/ef9kLpc/7sQ4
+        ZbjNHUl+zXonXeUNsXa2pWUgZEpVZ4vz2Wq+OJvPGqJyikxKKz1P5m5yMj2ZT6bLyfS8S9w6LSmK
+        NdyMAACem28a0Sr6LdYwHb8iFcWIJYn1IQhABGcSIjBGHRkti3FPSmeZbDP1FVj3ABItlHpHgFCm
+        iQFtfKCQ2ffaooGL5rSG58wCZMIH5ymwppiJDkxwlC7QAEkYazYNlomvLT0ekI++47RlKikcsYqi
+        DNqnXbZB37YESU5pSUHTDAoXgLcETRvYYCQFzoLmCIEM7dBKArQKdOVRciba8vv0249bNYF+1TqQ
+        Sk1u3mhJx9su7q2UTzX7mruRh2JaSxwIVEonEWg+H+2tQBOpizmsbp7Z/fCmAhV1xGQUWxszINBa
+        x5jqNh657Zj9wRXGlT64TXyTKgptddzmgTA6mxwQ2XnRsPtRUpvcVx8ZKl145Tlnd09Nu5PlrK0n
+        er/37GrVkewYTY+fLjvPHtfLFTFqEwf+FRLlllSf2psda6XdgBgNVP85zd9qt8q1Lf+nfE9ISZ5J
+        5T6Q0vJYcR8WKN39v8IOW24GFpHCTkvKWVNIN6GowNq0L1XEx8hU5YW2JQUfdPtcC5/LTTFbLM/O
+        zhditB+9AAAA//8DAB7xWDm3BAAA
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
       CF-RAY:
-      - 8c85fa461a4d1cf3-GRU
+      - 99766103c9f57d16-EWR
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Tue, 24 Sep 2024 21:48:16 GMT
+      - Fri, 31 Oct 2025 21:52:23 GMT
       Server:
       - cloudflare
+      Set-Cookie:
+      - __cf_bm=M0OyXPOd4vZCE92p.8e.is2jhrt7g6vYTBI3Y2Pg7PE-1761947543-1.0.1.1-orJHNWV50gzMMUsFex2S_O1ofp7KQ_r.9iAzzWwYGyBW1puzUvacw0OkY2KXSZf2mcUI_Rwg6lzRuwAT6WkysTCS52D.rp3oNdgPcSk3JSk;
+        path=/; expires=Fri, 31-Oct-25 22:22:23 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=LmEPJTcrhfn7YibgpOHVOK1U30pNnM9.PFftLZG98qs-1761947543691-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
       Transfer-Encoding:
       - chunked
       X-Content-Type-Options:
       - nosniff
       access-control-expose-headers:
       - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '799'
+      - '1824'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
+      x-envoy-upstream-service-time:
+      - '1855'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-requests:
+      - '10000'
       x-ratelimit-limit-requests:
       - '10000'
       x-ratelimit-limit-tokens:
-      - '2000000'
+      - '30000000'
+      x-ratelimit-remaining-project-requests:
+      - '9999'
       x-ratelimit-remaining-requests:
       - '9999'
       x-ratelimit-remaining-tokens:
-      - '1999744'
+      - '29999700'
+      x-ratelimit-reset-project-requests:
+      - 6ms
       x-ratelimit-reset-requests:
       - 6ms
       x-ratelimit-reset-tokens:
-      - 7ms
+      - 0s
       x-request-id:
-      - req_7ea6637f8e14c2b260cce6e3e3004cbb
-    http_version: HTTP/1.1
-    status_code: 200
-- request:
-    body: !!binary |
-      CsITCiQKIgoMc2VydmljZS5uYW1lEhIKEGNyZXdBSS10ZWxlbWV0cnkSmRMKEgoQY3Jld2FpLnRl
-      bGVtZXRyeRKbAQoQNiHDtik0VJXUvY2TAXlq5xIIVN7ytJgQOTQqClRvb2wgVXNhZ2UwATkgE44P
-      bkz4F0GgvJEPbkz4F0oaCg5jcmV3YWlfdmVyc2lvbhIICgYwLjYxLjBKJwoJdG9vbF9uYW1lEhoK
-      GEFzayBxdWVzdGlvbiB0byBjb3dvcmtlckoOCghhdHRlbXB0cxICGAF6AhgBhQEAAQAAEpACChB9
-      D1jc9xslW6yx+1EBiZyOEgg07DmIaDWZkCoOVGFzayBFeGVjdXRpb24wATnAXgcVbUz4F0H4h/Rb
-      bkz4F0ouCghjcmV3X2tleRIiCiA1ZTZlZmZlNjgwYTVkOTdkYzM4NzNiMTQ4MjVjY2ZhM0oxCgdj
-      cmV3X2lkEiYKJDFjZWJhZTk5LWYwNmQtNDEzYS05N2ExLWRlZWU1NjU3ZWFjNkouCgh0YXNrX2tl
-      eRIiCiAyN2VmMzhjYzk5ZGE0YThkZWQ3MGVkNDA2ZTQ0YWI4NkoxCgd0YXNrX2lkEiYKJDU1MjQ5
-      M2IwLWFmNDctNGVmMC04M2NjLWIwYmRjMzUxZWY2N3oCGAGFAQABAAASnAkKEIX+S/hQ6K5kLLu+
-      55qXcH8SCOxCl7XWayIeKgxDcmV3IENyZWF0ZWQwATkQYspcbkz4F0G4Ls5cbkz4F0oaCg5jcmV3
-      YWlfdmVyc2lvbhIICgYwLjYxLjBKGgoOcHl0aG9uX3ZlcnNpb24SCAoGMy4xMS43Si4KCGNyZXdf
-      a2V5EiIKIGQ0MjYwODMzYWIwYzIwYmI0NDkyMmM3OTlhYTk2YjRhSjEKB2NyZXdfaWQSJgokMjE2
-      YmRkZDYtYzVhOS00NDk2LWFlYzctYjNlMDBhNzQ5NDVjShwKDGNyZXdfcHJvY2VzcxIMCgpzZXF1
-      ZW50aWFsShEKC2NyZXdfbWVtb3J5EgIQAEoaChRjcmV3X251bWJlcl9vZl90YXNrcxICGAJKGwoV
-      Y3Jld19udW1iZXJfb2ZfYWdlbnRzEgIYAUrlAgoLY3Jld19hZ2VudHMS1QIK0gJbeyJrZXkiOiAi
-      OTJlN2ViMTkxNjY0YzkzNTc4NWVkN2Q0MjQwYTI5NGQiLCAiaWQiOiAiMDUzYWJkMGUtNzc0Ny00
-      Mzc5LTg5ZWUtMTc1YjkwYWRjOGFjIiwgInJvbGUiOiAiU2NvcmVyIiwgInZlcmJvc2U/IjogdHJ1
-      ZSwgIm1heF9pdGVyIjogMTUsICJtYXhfcnBtIjogbnVsbCwgImZ1bmN0aW9uX2NhbGxpbmdfbGxt
-      IjogImdwdC0zLjUtdHVyYm8tMDEyNSIsICJsbG0iOiAiZ3B0LTQtMDEyNS1wcmV2aWV3IiwgImRl
-      bGVnYXRpb25fZW5hYmxlZD8iOiBmYWxzZSwgImFsbG93X2NvZGVfZXhlY3V0aW9uPyI6IGZhbHNl
-      LCAibWF4X3JldHJ5X2xpbWl0IjogMiwgInRvb2xzX25hbWVzIjogW119XUrkAwoKY3Jld190YXNr
-      cxLVAwrSA1t7ImtleSI6ICIyN2VmMzhjYzk5ZGE0YThkZWQ3MGVkNDA2ZTQ0YWI4NiIsICJpZCI6
-      ICIxMTgyYzllZi02NzU3LTQ0ZTktOTA4Yi1jZmE2ZWIzODYxNWEiLCAiYXN5bmNfZXhlY3V0aW9u
-      PyI6IGZhbHNlLCAiaHVtYW5faW5wdXQ/IjogZmFsc2UsICJhZ2VudF9yb2xlIjogIlNjb3JlciIs
-      ICJhZ2VudF9rZXkiOiAiOTJlN2ViMTkxNjY0YzkzNTc4NWVkN2Q0MjQwYTI5NGQiLCAidG9vbHNf
-      bmFtZXMiOiBbXX0sIHsia2V5IjogIjYwOWRlZTM5MTA4OGNkMWM4N2I4ZmE2NmFhNjdhZGJlIiwg
-      ImlkIjogImJkZDhiZWYxLWZhNTYtNGQwYy1hYjQ0LTdiMjE0YzY2ODhiNSIsICJhc3luY19leGVj
-      dXRpb24/IjogZmFsc2UsICJodW1hbl9pbnB1dD8iOiBmYWxzZSwgImFnZW50X3JvbGUiOiAiU2Nv
-      cmVyIiwgImFnZW50X2tleSI6ICI5MmU3ZWIxOTE2NjRjOTM1Nzg1ZWQ3ZDQyNDBhMjk0ZCIsICJ0
-      b29sc19uYW1lcyI6IFtdfV16AhgBhQEAAQAAEo4CChCtIlcpdDnI8/HhoLC7gN6iEgje2a5QieRJ
-      MSoMVGFzayBDcmVhdGVkMAE58GXmXG5M+BdBKC3nXG5M+BdKLgoIY3Jld19rZXkSIgogZDQyNjA4
-      MzNhYjBjMjBiYjQ0OTIyYzc5OWFhOTZiNGFKMQoHY3Jld19pZBImCiQyMTZiZGRkNi1jNWE5LTQ0
-      OTYtYWVjNy1iM2UwMGE3NDk0NWNKLgoIdGFza19rZXkSIgogMjdlZjM4Y2M5OWRhNGE4ZGVkNzBl
-      ZDQwNmU0NGFiODZKMQoHdGFza19pZBImCiQxMTgyYzllZi02NzU3LTQ0ZTktOTA4Yi1jZmE2ZWIz
-      ODYxNWF6AhgBhQEAAQAAEpACChCBZ3BQ5YuuLU2Wn6fiGtU/Egh7U3eIthSUQioOVGFzayBFeGVj
-      dXRpb24wATlIe+dcbkz4F0HwIavCbkz4F0ouCghjcmV3X2tleRIiCiBkNDI2MDgzM2FiMGMyMGJi
-      NDQ5MjJjNzk5YWE5NmI0YUoxCgdjcmV3X2lkEiYKJDIxNmJkZGQ2LWM1YTktNDQ5Ni1hZWM3LWIz
-      ZTAwYTc0OTQ1Y0ouCgh0YXNrX2tleRIiCiAyN2VmMzhjYzk5ZGE0YThkZWQ3MGVkNDA2ZTQ0YWI4
-      NkoxCgd0YXNrX2lkEiYKJDExODJjOWVmLTY3NTctNDRlOS05MDhiLWNmYTZlYjM4NjE1YXoCGAGF
-      AQABAAASjgIKEOXCP/jH0lAyFChYhl/yRVASCMIALtbkZaYqKgxUYXNrIENyZWF0ZWQwATl4b8vC
-      bkz4F0E4x8zCbkz4F0ouCghjcmV3X2tleRIiCiBkNDI2MDgzM2FiMGMyMGJiNDQ5MjJjNzk5YWE5
-      NmI0YUoxCgdjcmV3X2lkEiYKJDIxNmJkZGQ2LWM1YTktNDQ5Ni1hZWM3LWIzZTAwYTc0OTQ1Y0ou
-      Cgh0YXNrX2tleRIiCiA2MDlkZWUzOTEwODhjZDFjODdiOGZhNjZhYTY3YWRiZUoxCgd0YXNrX2lk
-      EiYKJGJkZDhiZWYxLWZhNTYtNGQwYy1hYjQ0LTdiMjE0YzY2ODhiNXoCGAGFAQABAAA=
-    headers:
-      Accept:
-      - '*/*'
-      Accept-Encoding:
-      - gzip, deflate
-      Connection:
-      - keep-alive
-      Content-Length:
-      - '2501'
-      Content-Type:
-      - application/x-protobuf
-      User-Agent:
-      - OTel-OTLP-Exporter-Python/1.27.0
-    method: POST
-    uri: https://telemetry.crewai.com:4319/v1/traces
-  response:
-    body:
-      string: "\n\0"
-    headers:
-      Content-Length:
-      - '2'
-      Content-Type:
-      - application/x-protobuf
-      Date:
-      - Tue, 24 Sep 2024 21:48:17 GMT
+      - req_ef5bf5e7aa51435489f0c9d725916ff7
     status:
       code: 200
       message: OK
 - request:
-    body: '{"messages": [{"role": "user", "content": "5"}, {"role": "system", "content":
-      "I''m gonna convert this raw text into valid JSON.\n\nThe json should have the
-      following structure, with the following keys:\n{\n    score: int\n}"}], "model":
-      "gpt-3.5-turbo-0125", "tool_choice": {"type": "function", "function": {"name":
-      "ScoreOutput"}}, "tools": [{"type": "function", "function": {"name": "ScoreOutput",
-      "description": "Correctly extracted `ScoreOutput` with all the required parameters
-      with correct types", "parameters": {"properties": {"score": {"title": "Score",
-      "type": "integer"}}, "required": ["score"], "type": "object"}}}]}'
+    body: '{"messages":[{"role":"system","content":"You are Scorer. You''re an expert
+      scorer, specialized in scoring titles.\nYour personal goal is: Score the title\nTo
+      give my best complete final answer to the task respond using the exact following
+      format:\n\nThought: I now can give a great answer\nFinal Answer: Your final
+      answer must be the great and the most complete as possible, it must be outcome
+      described.\n\nI MUST use these formats, my job depends on it!"},{"role":"user","content":"\nCurrent
+      Task: Given the score the title ''The impact of AI in the future of work'' got,
+      give me an integer score between 1-5 for the following title: ''Return of the
+      Jedi'', you MUST give it a score, use your best judgment\n\nThis is the expected
+      criteria for your final answer: The score of the title.\nyou MUST return the
+      actual complete content as the final answer, not a summary.\nEnsure your final
+      answer contains only the content in the following format: {\n  \"properties\":
+      {\n    \"score\": {\n      \"title\": \"Score\",\n      \"type\": \"integer\"\n    }\n  },\n  \"required\":
+      [\n    \"score\"\n  ],\n  \"title\": \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\":
+      false\n}\n\nEnsure the final output does not include any code block markers
+      like ```json or ```python.\n\nThis is the context you''re working with:\n{\n  \"properties\":
+      {\n    \"score\": {\n      \"title\": \"Score\",\n      \"type\": \"integer\",\n      \"description\":
+      \"The assigned score for the title based on its relevance and impact\"\n    }\n  },\n  \"required\":
+      [\n    \"score\"\n  ],\n  \"title\": \"ScoreOutput\",\n  \"type\": \"object\",\n  \"additionalProperties\":
+      false,\n  \"score\": 4\n}\n\nBegin! This is VERY important to you, use the tools
+      available and give your best Final Answer, your job depends on it!\n\nThought:"}],"model":"gpt-4o"}'
     headers:
       accept:
       - application/json
       accept-encoding:
-      - gzip, deflate
+      - gzip, deflate, zstd
       connection:
       - keep-alive
       content-length:
-      - '627'
+      - '1840'
       content-type:
       - application/json
       cookie:
-      - __cf_bm=9.8sBYBkvBR8R1K_bVF7xgU..80XKlEIg3N2OBbTSCU-1727214102-1.0.1.1-.qiTLXbPamYUMSuyNsOEB9jhGu.jOifujOrx9E2JZvStbIZ9RTIiE44xKKNfLPxQkOi6qAT3h6htK8lPDGV_5g;
-        _cfuvid=lbRdAddVWV6W3f5Dm9SaOPWDUOxqtZBSPr_fTW26nEA-1727213194587-0.0.1.1-604800000
+      - __cf_bm=M0OyXPOd4vZCE92p.8e.is2jhrt7g6vYTBI3Y2Pg7PE-1761947543-1.0.1.1-orJHNWV50gzMMUsFex2S_O1ofp7KQ_r.9iAzzWwYGyBW1puzUvacw0OkY2KXSZf2mcUI_Rwg6lzRuwAT6WkysTCS52D.rp3oNdgPcSk3JSk;
+        _cfuvid=LmEPJTcrhfn7YibgpOHVOK1U30pNnM9.PFftLZG98qs-1761947543691-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.47.0
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
@@ -419,70 +281,88 @@ interactions:
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.47.0
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.11.7
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
-    content: "{\n  \"id\": \"chatcmpl-AB7gHtXxJaZ5NZiXZzc0HUAObflqc\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1727214497,\n  \"model\": \"gpt-3.5-turbo-0125\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": null,\n        \"tool_calls\": [\n          {\n
-      \           \"id\": \"call_hFpl2Plo4DudP1t3SGHby2vo\",\n            \"type\":
-      \"function\",\n            \"function\": {\n              \"name\": \"ScoreOutput\",\n
-      \             \"arguments\": \"{\\\"score\\\":5}\"\n            }\n          }\n
-      \       ],\n        \"refusal\": null\n      },\n      \"logprobs\": null,\n
-      \     \"finish_reason\": \"stop\"\n    }\n  ],\n  \"usage\": {\n    \"prompt_tokens\":
-      103,\n    \"completion_tokens\": 5,\n    \"total_tokens\": 108,\n    \"completion_tokens_details\":
-      {\n      \"reasoning_tokens\": 0\n    }\n  },\n  \"system_fingerprint\": null\n}\n"
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jJNdb5swFIbv8yssX5OJpCRpuJumrZoqtdO6rRelQo59AG/G9uxDuyji
+        v1cGGkjWSbsB+Tzn0+/xYUYIlYKmhPKKIa+tmn+4d9fyvr76Wl5cXcer2215s5R3H3c/xPf9DY1C
+        hNn9BI6vUe+4qa0ClEb3mDtgCCHrYrNebJPNKkk6UBsBKoSVFueJmS/jZTKPL+fxegisjOTgaUoe
+        ZoQQcui+oUUt4A9NSRy9WmrwnpVA06MTIdQZFSyUeS89Mo00GiE3GkF3XX+rTFNWmJLPRJtnwpkm
+        pXwCwkgZWidM+2dwmf4kNVPkfXdKySHThGTUOmPBoQSf0cEYzJ4bBxNLsKFE1dkyetfjaAL3dmBS
+        I5TgMtrDNvzaqK/m4HcjHYjg+XBWKxwfB7/zUrcN2gaHgtNivXZHwISQQTmmvpzMVTDlYfA5jpZk
+        up1eqYOi8SwoqhulJoBpbZCFvJ2YjwNpj/IpU1pndv4slBZSS1/lDpg3Okjl0Vja0XYWpg1r0pwo
+        HwSpLeZofkFXLomXfT46LuZILy8GiAaZmkRdrqI38uUCkEnlJ4tGOeMViDF03ErWCGkmYDaZ+u9u
+        3srdTy51+T/pR8A5WASRWwdC8tOJRzcHQft/uR1vuWuYenBPkkOOElxQQkDBGtU/Ker3HqHOC6lL
+        cNbJ/l0VNl+stut1wra7DZ21sxcAAAD//wMAwih5UmAEAAA=
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
       CF-RAY:
-      - 8c85fa4cebc21cf3-GRU
+      - 99766114cf7c7d16-EWR
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Tue, 24 Sep 2024 21:48:17 GMT
+      - Fri, 31 Oct 2025 21:52:25 GMT
       Server:
       - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
       Transfer-Encoding:
       - chunked
       X-Content-Type-Options:
       - nosniff
       access-control-expose-headers:
       - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '196'
+      - '1188'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
+      x-envoy-upstream-service-time:
+      - '1206'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-requests:
+      - '10000'
       x-ratelimit-limit-requests:
       - '10000'
       x-ratelimit-limit-tokens:
-      - '50000000'
+      - '30000000'
+      x-ratelimit-remaining-project-requests:
+      - '9999'
       x-ratelimit-remaining-requests:
       - '9999'
       x-ratelimit-remaining-tokens:
-      - '49999947'
+      - '29999586'
+      x-ratelimit-reset-project-requests:
+      - 6ms
       x-ratelimit-reset-requests:
       - 6ms
       x-ratelimit-reset-tokens:
       - 0s
       x-request-id:
-      - req_deaa35bcd479744c6ce7363ae1b27d9e
-    http_version: HTTP/1.1
-    status_code: 200
+      - req_030ffb3d92bb47589d61d50b48f068d4
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_save_task_pydantic_output.yaml b/lib/crewai/tests/cassettes/test_save_task_pydantic_output.yaml
--- a/lib/crewai/tests/cassettes/test_save_task_pydantic_output.yaml
+++ b/lib/crewai/tests/cassettes/test_save_task_pydantic_output.yaml
@@ -530,4 +530,235 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    score: int\n}\n```"},{"role":"user","content":"4"}],"model":"gpt-4.1-mini"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '277'
+      content-type:
+      - application/json
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jJIxb9swEIV3/QriZiuwFNlxtBadig6ZGrQKJJo8SbQpkiWpwoHh/16Q
+        ci0lTYEuGu679/TueOeEEBAcSgKsp54NRqafvj2ffh4PX56e2n37+vW7Gj8/n/qjE/64OcAqKPT+
+        gMz/Ud0xPRiJXmg1YWaRegyu2cM22z3crx/XEQyaowyyzvi0uMvSQSiR5ut8k66LNCuu8l4Lhg5K
+        8iMhhJBz/IagiuMJShLNYmVA52iHUN6aCAGrZagAdU44T5WH1QyZVh5VzN40zcFpValzpQKrwDFt
+        sYKSFJW6VKppmqXUYjs6GvKrUcoFoEppT8P8MfTLlVxuMaXujNV7904KrVDC9bVF6rQKkZzXBiK9
+        JIS8xHWMbyYEY/VgfO31EePvisfJDuZXmGF2f4Veeyrn+jZffeBWc/RUSLdYJzDKeuSzct49HbnQ
+        C5AsZv47zEfe09xCdf9jPwPG0HjktbHIBXs78NxmMdzov9puO46BwaH9JRjWXqAN78CxpaOcDgfc
+        q/M41K1QHVpjxXQ9rakLlu82Wbvb5pBckt8AAAD//wMA5Zmg4EwDAAA=
+    headers:
+      CF-RAY:
+      - 996f475b7e3fedda-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 01:11:31 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=9OwoBJAn84Nsq0RZdCIu06cNB6RLqor4C1.Q58nU28U-1761873091-1.0.1.1-p82_h8Vnxe0NfH5Iv6MFt.SderZj.v9VnCx_ro6ti2MGhlJOLFsPd6XhBxPsnmuV7Vt_4_uqAbE57E5f1Epl1cmGBT.0844N3CLnTwZFWQI;
+        path=/; expires=Fri, 31-Oct-25 01:41:31 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=E4.xW3I8m58fngo4vkTKo8hmBumar1HkV.yU8KKjlZg-1761873091967-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '1770'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '1998'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999955'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999952'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_ba7a12cb40744f648d17844196f9c2c6
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    score: int\n}\n```"},{"role":"user","content":"4"}],"model":"gpt-4.1-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"properties":{"score":{"title":"Score","type":"integer"}},"required":["score"],"title":"ScoreOutput","type":"object","additionalProperties":false},"name":"ScoreOutput","strict":true}},"stream":false}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '541'
+      content-type:
+      - application/json
+      cookie:
+      - __cf_bm=9OwoBJAn84Nsq0RZdCIu06cNB6RLqor4C1.Q58nU28U-1761873091-1.0.1.1-p82_h8Vnxe0NfH5Iv6MFt.SderZj.v9VnCx_ro6ti2MGhlJOLFsPd6XhBxPsnmuV7Vt_4_uqAbE57E5f1Epl1cmGBT.0844N3CLnTwZFWQI;
+        _cfuvid=E4.xW3I8m58fngo4vkTKo8hmBumar1HkV.yU8KKjlZg-1761873091967-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jFLBbqMwFLzzFdY7hypQklKuVS899NpK2wo59gPcGtuyH92uovz7ypAE
+        0t1KvXB482Y8M7x9whgoCRUD0XESvdPp3dPzZ/gty77xO7fZPj4MMs/ldYf3Lt/CKjLs7g0FnVhX
+        wvZOIylrJlh45IRRNbvZZuXN9fo2H4HeStSR1jpKi6ss7ZVRab7ON+m6SLPiSO+sEhigYr8Sxhjb
+        j99o1Ej8hIqtV6dJjyHwFqE6LzEG3uo4AR6CCsQNwWoGhTWEZvS+f4EgrMcXqIrDcsdjMwQejZpB
+        6wXAjbHEY9DR3esROZz9aNs6b3fhCxUaZVToao88WBPfDmQdjOghYex1zD1cRAHnbe+oJvuO43Pl
+        ZpKDue4ZPGFkiet5fHus6lKslkhc6bCoDQQXHcqZOXfMB6nsAkgWkf/18j/tKbYy7U/kZ0AIdISy
+        dh6lEpd55zWP8Ra/WztXPBqGgP5DCaxJoY+/QWLDBz0dCIQ/gbCvG2Va9M6r6UoaVxciLzdZU25z
+        SA7JXwAAAP//AwAXjqY4NAMAAA==
+    headers:
+      CF-RAY:
+      - 996f47692b63edda-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 01:11:33 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '929'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '991'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999955'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999955'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_892607f68e764ba3846c431954608c36
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cassettes/test_using_contextual_memory.yaml b/lib/crewai/tests/cassettes/test_using_contextual_memory.yaml
--- a/lib/crewai/tests/cassettes/test_using_contextual_memory.yaml
+++ b/lib/crewai/tests/cassettes/test_using_contextual_memory.yaml
@@ -1667,4 +1667,553 @@ interactions:
     status:
       code: 200
       message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nResearch
+      a topic to teach a kid aged 6 about math.\n\nExpected Output:\nA topic, explanation,
+      angle, and examples.\n\nActual Output:\nI now can give a great answer.\nFinal
+      Answer: \n**Topic**: Basic Addition\n\n**Explanation**:\nAddition is a fundamental
+      concept in math that means combining two or more numbers to get a new total.
+      It''s like putting together pieces of a puzzle to see the whole picture. When
+      we add, we take two or more groups of things and count them all together.\n\n**Angle**:\nUse
+      relatable and engaging real-life scenarios to illustrate addition, making it
+      fun and easier for a 6-year-old to understand and apply.\n\n**Examples**:\n\n1.
+      **Counting Apples**:\n   Let''s say you have 2 apples and your friend gives
+      you 3 more apples. How many apples do you have in total?\n   - You start with
+      2 apples.\n   - Your friend gives you 3 more apples.\n   - Now, you count all
+      the apples together: 2 + 3 = 5.\n   - So, you have 5 apples in total.\n\n2.
+      **Toy Cars**:\n   Imagine you have 4 toy cars and you find 2 more toy cars in
+      your room. How many toy cars do you have now?\n   - You start with 4 toy cars.\n   -
+      You find 2 more toy cars.\n   - You count them all together: 4 + 2 = 6.\n   -
+      So, you have 6 toy cars in total.\n\n3. **Drawing Pictures**:\n   If you draw
+      3 pictures today and 2 pictures tomorrow, how many pictures will you have drawn
+      in total?\n   - You draw 3 pictures today.\n   - You draw 2 pictures tomorrow.\n   -
+      You add them together: 3 + 2 = 5.\n   - So, you will have drawn 5 pictures in
+      total.\n\n4. **Using Fingers**:\n   Let''s use your fingers to practice addition.
+      Show 3 fingers on one hand and 1 finger on the other hand. How many fingers
+      are you holding up?\n   - 3 fingers on one hand.\n   - 1 finger on the other
+      hand.\n   - Put them together and count: 3 + 1 = 4.\n   - So, you are holding
+      up 4 fingers.\n\nBy using objects that kids are familiar with, such as apples,
+      toy cars, drawings, and even their own fingers, we can make the concept of addition
+      relatable and enjoyable. Practicing with real items helps children visualize
+      the math and understand that addition is simply combining groups to find out
+      how many there are altogether.\n\nPlease provide:\n- Bullet points suggestions
+      to improve future similar tasks\n- A score from 0 to 10 evaluating on completion,
+      quality, and overall performance- Entities extracted from the task output, if
+      any, their type, description, and relationships"}],"model":"gpt-4.1-mini"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '2711'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=uF44YidguuLD6X0Fw3uiyzdru2Ad2jXf2Nx1M4V87qI-1749851140865-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        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
+        Dxf14/PT6ujd0b8AAAD//wMAcO55jFcOAAA=
+    headers:
+      CF-RAY:
+      - 996fc2c3bbf5d7df-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:53 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=kgKK5IJqaYXKSVMHugdSipIgres75xcyE7AFoQvJpYQ-1761878153-1.0.1.1-Gs3miwKehE3t4oQeqLEaesnuSTAZMKeqirw5cieEuAcSRSUCmzwzKvXjWzc8yPxfuzLx3j8JOtRH4vqLwl0.G4VN12X8AB5I4TbGRI8pdZ0;
+        path=/; expires=Fri, 31-Oct-25 03:05:53 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=gRWE8NibQIkdP415ySHVelZVNQP_TP1Yiq9t0KwvhpI-1761878153913-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '9127'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '9143'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999355'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999357'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_42acad04b20045f2807d0d17c11e5ce4
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"messages":[{"role":"system","content":"Convert all responses into valid
+      JSON output."},{"role":"user","content":"Assess the quality of the task completed
+      based on the description, expected output, and actual results.\n\nTask Description:\nResearch
+      a topic to teach a kid aged 6 about math.\n\nExpected Output:\nA topic, explanation,
+      angle, and examples.\n\nActual Output:\nI now can give a great answer.\nFinal
+      Answer: \n**Topic**: Basic Addition\n\n**Explanation**:\nAddition is a fundamental
+      concept in math that means combining two or more numbers to get a new total.
+      It''s like putting together pieces of a puzzle to see the whole picture. When
+      we add, we take two or more groups of things and count them all together.\n\n**Angle**:\nUse
+      relatable and engaging real-life scenarios to illustrate addition, making it
+      fun and easier for a 6-year-old to understand and apply.\n\n**Examples**:\n\n1.
+      **Counting Apples**:\n   Let''s say you have 2 apples and your friend gives
+      you 3 more apples. How many apples do you have in total?\n   - You start with
+      2 apples.\n   - Your friend gives you 3 more apples.\n   - Now, you count all
+      the apples together: 2 + 3 = 5.\n   - So, you have 5 apples in total.\n\n2.
+      **Toy Cars**:\n   Imagine you have 4 toy cars and you find 2 more toy cars in
+      your room. How many toy cars do you have now?\n   - You start with 4 toy cars.\n   -
+      You find 2 more toy cars.\n   - You count them all together: 4 + 2 = 6.\n   -
+      So, you have 6 toy cars in total.\n\n3. **Drawing Pictures**:\n   If you draw
+      3 pictures today and 2 pictures tomorrow, how many pictures will you have drawn
+      in total?\n   - You draw 3 pictures today.\n   - You draw 2 pictures tomorrow.\n   -
+      You add them together: 3 + 2 = 5.\n   - So, you will have drawn 5 pictures in
+      total.\n\n4. **Using Fingers**:\n   Let''s use your fingers to practice addition.
+      Show 3 fingers on one hand and 1 finger on the other hand. How many fingers
+      are you holding up?\n   - 3 fingers on one hand.\n   - 1 finger on the other
+      hand.\n   - Put them together and count: 3 + 1 = 4.\n   - So, you are holding
+      up 4 fingers.\n\nBy using objects that kids are familiar with, such as apples,
+      toy cars, drawings, and even their own fingers, we can make the concept of addition
+      relatable and enjoyable. Practicing with real items helps children visualize
+      the math and understand that addition is simply combining groups to find out
+      how many there are altogether.\n\nPlease provide:\n- Bullet points suggestions
+      to improve future similar tasks\n- A score from 0 to 10 evaluating on completion,
+      quality, and overall performance- Entities extracted from the task output, if
+      any, their type, description, and relationships"}],"model":"gpt-4.1-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"$defs":{"Entity":{"properties":{"name":{"description":"The
+      name of the entity.","title":"Name","type":"string"},"type":{"description":"The
+      type of the entity.","title":"Type","type":"string"},"description":{"description":"Description
+      of the entity.","title":"Description","type":"string"},"relationships":{"description":"Relationships
+      of the entity.","items":{"type":"string"},"title":"Relationships","type":"array"}},"required":["name","type","description","relationships"],"title":"Entity","type":"object","additionalProperties":false}},"properties":{"suggestions":{"description":"Suggestions
+      to improve future similar tasks.","items":{"type":"string"},"title":"Suggestions","type":"array"},"quality":{"description":"A
+      score from 0 to 10 evaluating on completion, quality, and overall performance,
+      all taking into account the task description, expected output, and the result
+      of the task.","title":"Quality","type":"number"},"entities":{"description":"Entities
+      extracted from the task output.","items":{"$ref":"#/$defs/Entity"},"title":"Entities","type":"array"}},"required":["suggestions","quality","entities"],"title":"TaskEvaluation","type":"object","additionalProperties":false},"name":"TaskEvaluation","strict":true}},"stream":false}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '4017'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=gRWE8NibQIkdP415ySHVelZVNQP_TP1Yiq9t0KwvhpI-1761878153913-0.0.1.1-604800000;
+        __cf_bm=kgKK5IJqaYXKSVMHugdSipIgres75xcyE7AFoQvJpYQ-1761878153-1.0.1.1-Gs3miwKehE3t4oQeqLEaesnuSTAZMKeqirw5cieEuAcSRSUCmzwzKvXjWzc8yPxfuzLx3j8JOtRH4vqLwl0.G4VN12X8AB5I4TbGRI8pdZ0
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/chat/completions
+  response:
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//vJZNbyM3DIbv+RWELr3YQex8ub65aYrdQ9EtmiJAdwKDljgzTDSSVh9O
+        jCD/vZBmHDupD0WR7sWw9Yrk84oac56PAAQrMQchW4yyc3p8dfvXp9vZ6WT1uz6v4283fLqYfbm+
+        /fX+6dPNVIxyhF3dk4zbqGNpO6cpsjW9LD1hpJx1cnkxmV3OJudnReisIp3DGhfHZ8eTcceGx9OT
+        6fn45Gw8ORvCW8uSgpjD1yMAgOfymUGNoicxh5PRdqWjELAhMX/dBCC81XlFYAgcIpooRjtRWhPJ
+        FPbnSoTUNBQyeajE/GslPhupkyJYc0ioA1gPbCJ5lJHXBKSpIxMDRAtkWjSSgEyDTVmG2nrY2GQa
+        kC1r5ckcV2JUiT+4c5rrDWg0TcKGgNZkoE4+tuRzsg6jbAHhYrwh9GOr1Q8B8rl6askEtgY0rUn3
+        +RZKwbc0gGfGgseRaSCTNvlcZsB26CNLdpgDAI0CT2xq6yWBJvSGTTOQOpIZNLY7Bfp250TWQ3hg
+        rXsYoCdHMpIqxnNIJJRtDhmOuU/62UjrnfUYCWoitUL5UKhDoBDKyXUUW6sKfUcYkidIRpHP/VM9
+        3d2oEt8Sao6bSsx/HFWCTCyec+ueK2Gwo0rMK/ETBpawUIqz34IQN67XbqxjWZYUBenZ9VvmlVhA
+        nYzCjIM6G5DkIrDJvWkhtph/rK1eU+nMisvZxEebrXTWE5jUrcgXEw1FQDD0CNFGHNrmSZcOhJbd
+        cN+un5xGg6+cC9NoKt+unzA/VaESdy+jfXeHfV31vAedXR2kbbxNLoCt97lrNgqwhwZp07aFB9Df
+        n/I7zKscnGsuXG9jn3Ywd7gPBljrFKLvr6utAYcikELOiCVj/9g8ULl423YVTlxpKrc8oml4pem/
+        erixG7hC/6Hw0W5Aov8e+D97fMwlv7CMyX9sD1Sf+3vY+LMU/IVNQx/birpP+f9YuHvZHzue6hQw
+        zz6TtN4T0Bgb+2x54N0NysvriNO2cd6uwrtQUbPh0C49YbAmj7MQrRNFfTkCuCujNL2ZjsJ527m4
+        jPaBSrnZxTBKxW6E79Tp5VYtfwc7YTI53SpvMi4VRWQd9saxkChbUrvY3ezGpNjuCUd7vv/Jcyh3
+        751N82/S7wSZG0xq6Twplm8977Z5ui+z7fC213MuwCKQX7OkZWTyuReKaky6f/EQYRMidcv+tjnP
+        /dtH7ZZncjo7n9Szi6k4ejn6GwAA//8DAN8BUTKMCQAA
+    headers:
+      CF-RAY:
+      - 996fc2fe8f28d7df-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:57 GMT
+      Server:
+      - cloudflare
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '3759'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      x-envoy-upstream-service-time:
+      - '3850'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
+      x-ratelimit-limit-requests:
+      - '30000'
+      x-ratelimit-limit-tokens:
+      - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999357'
+      x-ratelimit-remaining-requests:
+      - '29999'
+      x-ratelimit-remaining-tokens:
+      - '149999355'
+      x-ratelimit-reset-project-tokens:
+      - 0s
+      x-ratelimit-reset-requests:
+      - 2ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_dc7b54ac42e9466fba10bf30986b2bf0
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"input":["Using Fingers(Example): An illustration of addition using fingers
+      to make the concept relatable and tangible."],"model":"text-embedding-3-small","encoding_format":"base64"}'
+    headers:
+      accept:
+      - application/json
+      accept-encoding:
+      - gzip, deflate, zstd
+      connection:
+      - keep-alive
+      content-length:
+      - '183'
+      content-type:
+      - application/json
+      cookie:
+      - _cfuvid=NaNzk_g04ozIFjR4zD0Joz9IJWntjKPTzifJUuegmAo-1756166265356-0.0.1.1-604800000
+      host:
+      - api.openai.com
+      user-agent:
+      - OpenAI/Python 1.109.1
+      x-stainless-arch:
+      - arm64
+      x-stainless-async:
+      - 'false'
+      x-stainless-lang:
+      - python
+      x-stainless-os:
+      - MacOS
+      x-stainless-package-version:
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
+      x-stainless-retry-count:
+      - '0'
+      x-stainless-runtime:
+      - CPython
+      x-stainless-runtime-version:
+      - 3.12.10
+    method: POST
+    uri: https://api.openai.com/v1/embeddings
+  response:
+    body:
+      string: !!binary |
+        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
+        /uNf/wkAAP//AwBrHHLA4CAAAA==
+    headers:
+      CF-RAY:
+      - 996fc319cecdedb7-MXP
+      Connection:
+      - keep-alive
+      Content-Encoding:
+      - gzip
+      Content-Type:
+      - application/json
+      Date:
+      - Fri, 31 Oct 2025 02:35:59 GMT
+      Server:
+      - cloudflare
+      Set-Cookie:
+      - __cf_bm=EdEqm0c4qXDd37eMDquvqY8nUh6i44aqdC__ePBIwdQ-1761878159-1.0.1.1-Y1V.w1Y5bONiTamPzQiiY1qXjAjFOKz.YIxcoojb6aoHLm_rch0X.0RiwtAKa7Of5uQVYh6zABwFVdBp_nG4IDme6u0HfG2NG.fQ10OUTo4;
+        path=/; expires=Fri, 31-Oct-25 03:05:59 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=BvgP1vTLLqluS8718kR0r7eL._6ojjbRzMUW6Yptgfk-1761878159085-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Transfer-Encoding:
+      - chunked
+      X-Content-Type-Options:
+      - nosniff
+      access-control-allow-origin:
+      - '*'
+      access-control-expose-headers:
+      - X-Request-ID
+      alt-svc:
+      - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
+      openai-model:
+      - text-embedding-3-small
+      openai-organization:
+      - crewai-iuxna1
+      openai-processing-ms:
+      - '58'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
+      openai-version:
+      - '2020-10-01'
+      strict-transport-security:
+      - max-age=31536000; includeSubDomains; preload
+      via:
+      - envoy-router-54b578b84c-pcfpl
+      x-envoy-upstream-service-time:
+      - '227'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-requests:
+      - '10000'
+      x-ratelimit-limit-tokens:
+      - '10000000'
+      x-ratelimit-remaining-requests:
+      - '9999'
+      x-ratelimit-remaining-tokens:
+      - '9999973'
+      x-ratelimit-reset-requests:
+      - 6ms
+      x-ratelimit-reset-tokens:
+      - 0s
+      x-request-id:
+      - req_1bad6e1c88504b1fb51574bb4f61deba
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/cli/test_token_manager.py b/lib/crewai/tests/cli/test_token_manager.py
--- a/lib/crewai/tests/cli/test_token_manager.py
+++ b/lib/crewai/tests/cli/test_token_manager.py
@@ -29,17 +29,27 @@ def test_get_or_create_key_existing(self, mock_get_or_create, mock_save, mock_re
     @patch("crewai.cli.shared.token_manager.Fernet.generate_key")
     @patch("crewai.cli.shared.token_manager.TokenManager.read_secure_file")
     @patch("crewai.cli.shared.token_manager.TokenManager.save_secure_file")
-    def test_get_or_create_key_new(self, mock_save, mock_read, mock_generate):
+    @patch("crewai.cli.shared.token_manager.TokenManager._acquire_lock")
+    @patch("crewai.cli.shared.token_manager.TokenManager._release_lock")
+    @patch("builtins.open", new_callable=unittest.mock.mock_open)
+    def test_get_or_create_key_new(
+        self, mock_open, mock_release_lock, mock_acquire_lock, mock_save, mock_read, mock_generate
+    ):
         mock_key = b"new_key"
         mock_read.return_value = None
         mock_generate.return_value = mock_key
 
         result = self.token_manager._get_or_create_key()
 
         self.assertEqual(result, mock_key)
-        mock_read.assert_called_once_with("secret.key")
+        # read_secure_file is called twice: once for fast path, once inside lock
+        self.assertEqual(mock_read.call_count, 2)
+        mock_read.assert_called_with("secret.key")
         mock_generate.assert_called_once()
         mock_save.assert_called_once_with("secret.key", mock_key)
+        # Verify lock was acquired and released
+        mock_acquire_lock.assert_called_once()
+        mock_release_lock.assert_called_once()
 
     @patch("crewai.cli.shared.token_manager.TokenManager.save_secure_file")
     def test_save_tokens(self, mock_save):
@@ -136,3 +146,21 @@ def test_clear_tokens(self, mock_get_path):
         mock_path.__truediv__.return_value.unlink.assert_called_once_with(
             missing_ok=True
         )
+
+    @patch("crewai.cli.shared.token_manager.Fernet.generate_key")
+    @patch("crewai.cli.shared.token_manager.TokenManager.read_secure_file")
+    @patch("crewai.cli.shared.token_manager.TokenManager.save_secure_file")
+    @patch("builtins.open", side_effect=OSError(9, "Bad file descriptor"))
+    def test_get_or_create_key_oserror_fallback(
+        self, mock_open, mock_save, mock_read, mock_generate
+    ):
+        """Test that OSError during file locking falls back to lock-free creation."""
+        mock_key = Fernet.generate_key()
+        mock_read.return_value = None
+        mock_generate.return_value = mock_key
+
+        result = self.token_manager._get_or_create_key()
+
+        self.assertEqual(result, mock_key)
+        self.assertGreaterEqual(mock_generate.call_count, 1)
+        self.assertGreaterEqual(mock_save.call_count, 1)
diff --git a/lib/crewai/tests/conftest.py b/lib/crewai/tests/conftest.py
--- a/lib/crewai/tests/conftest.py
+++ b/lib/crewai/tests/conftest.py
@@ -78,6 +78,17 @@ def auto_mock_telemetry(request):
             mock_instance = create_mock_telemetry_instance()
             mock_telemetry_class.return_value = mock_instance
 
+            # Create mock for TraceBatchManager
+            mock_trace_manager = Mock()
+            mock_trace_manager.add_trace = Mock()
+            mock_trace_manager.send_batch = Mock()
+            mock_trace_manager.stop = Mock()
+
+            # Create mock for BatchSpanProcessor to prevent OpenTelemetry background threads
+            mock_batch_processor = Mock()
+            mock_batch_processor.shutdown = Mock()
+            mock_batch_processor.force_flush = Mock()
+
             with (
                 patch(
                     "crewai.events.event_listener.Telemetry",
@@ -86,6 +97,22 @@ def auto_mock_telemetry(request):
                 patch("crewai.tools.tool_usage.Telemetry", mock_telemetry_class),
                 patch("crewai.cli.command.Telemetry", mock_telemetry_class),
                 patch("crewai.cli.create_flow.Telemetry", mock_telemetry_class),
+                patch(
+                    "crewai.events.listeners.tracing.trace_batch_manager.TraceBatchManager",
+                    return_value=mock_trace_manager,
+                ),
+                patch(
+                    "crewai.events.listeners.tracing.trace_listener.TraceBatchManager",
+                    return_value=mock_trace_manager,
+                ),
+                patch(
+                    "crewai.events.listeners.tracing.first_time_trace_handler.TraceBatchManager",
+                    return_value=mock_trace_manager,
+                ),
+                patch(
+                    "opentelemetry.sdk.trace.export.BatchSpanProcessor",
+                    return_value=mock_batch_processor,
+                ),
             ):
                 yield mock_instance
 
@@ -175,8 +202,8 @@ def clear_event_bus_handlers(setup_test_environment):
 
     yield
 
-    # Shutdown event bus and wait for all handlers to complete
-    crewai_event_bus.shutdown(wait=True)
+    # Shutdown event bus without waiting to avoid hanging on blocked threads
+    crewai_event_bus.shutdown(wait=False)
     crewai_event_bus._initialize()
 
     callback = EvaluationTraceCallback()
diff --git a/lib/crewai/tests/llms/openai/test_openai.py b/lib/crewai/tests/llms/openai/test_openai.py
--- a/lib/crewai/tests/llms/openai/test_openai.py
+++ b/lib/crewai/tests/llms/openai/test_openai.py
@@ -482,3 +482,48 @@ def test_openai_get_client_params_no_base_url():
     client_params = llm._get_client_params()
     # When no base_url is provided, it should not be in the params (filtered out as None)
     assert "base_url" not in client_params or client_params.get("base_url") is None
+
+
+def test_openai_streaming_with_response_model():
+    """
+    Test that streaming with response_model works correctly and doesn't call invalid API methods.
+    This test verifies the fix for the bug where streaming with response_model attempted to call
+    self.client.responses.stream() with invalid parameters (input, text_format).
+    """
+    from pydantic import BaseModel
+
+    class TestResponse(BaseModel):
+        """Test response model."""
+
+        answer: str
+        confidence: float
+
+    llm = LLM(model="openai/gpt-4o", stream=True)
+
+    with patch.object(llm.client.chat.completions, "create") as mock_create:
+        mock_chunk1 = MagicMock()
+        mock_chunk1.choices = [
+            MagicMock(delta=MagicMock(content='{"answer": "test", ', tool_calls=None))
+        ]
+
+        mock_chunk2 = MagicMock()
+        mock_chunk2.choices = [
+            MagicMock(
+                delta=MagicMock(content='"confidence": 0.95}', tool_calls=None)
+            )
+        ]
+
+        mock_create.return_value = iter([mock_chunk1, mock_chunk2])
+
+        result = llm.call("Test question", response_model=TestResponse)
+
+        assert result is not None
+        assert isinstance(result, str)
+
+        assert mock_create.called
+        call_kwargs = mock_create.call_args[1]
+        assert call_kwargs["model"] == "gpt-4o"
+        assert call_kwargs["stream"] is True
+
+        assert "input" not in call_kwargs
+        assert "text_format" not in call_kwargs
diff --git a/lib/crewai/tests/test_crew.py b/lib/crewai/tests/test_crew.py
--- a/lib/crewai/tests/test_crew.py
+++ b/lib/crewai/tests/test_crew.py
@@ -1,11 +1,13 @@
 """Test Agent creation and execution basic functionality."""
 
+from io import StringIO
 import json
 import threading
 from collections import defaultdict
 from concurrent.futures import Future
 from hashlib import md5
 import re
+import sys
 from unittest.mock import ANY, MagicMock, call, patch
 
 from crewai.agent import Agent
@@ -2442,37 +2444,51 @@ def test_memory_events_are_emitted():
 
     @crewai_event_bus.on(MemorySaveStartedEvent)
     def handle_memory_save_started(source, event):
-        events["MemorySaveStartedEvent"].append(event)
+        with condition:
+            events["MemorySaveStartedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemorySaveCompletedEvent)
     def handle_memory_save_completed(source, event):
-        events["MemorySaveCompletedEvent"].append(event)
+        with condition:
+            events["MemorySaveCompletedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemorySaveFailedEvent)
     def handle_memory_save_failed(source, event):
-        events["MemorySaveFailedEvent"].append(event)
+        with condition:
+            events["MemorySaveFailedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemoryQueryStartedEvent)
     def handle_memory_query_started(source, event):
-        events["MemoryQueryStartedEvent"].append(event)
+        with condition:
+            events["MemoryQueryStartedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemoryQueryCompletedEvent)
     def handle_memory_query_completed(source, event):
-        events["MemoryQueryCompletedEvent"].append(event)
+        with condition:
+            events["MemoryQueryCompletedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemoryQueryFailedEvent)
     def handle_memory_query_failed(source, event):
-        events["MemoryQueryFailedEvent"].append(event)
+        with condition:
+            events["MemoryQueryFailedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemoryRetrievalStartedEvent)
     def handle_memory_retrieval_started(source, event):
-        events["MemoryRetrievalStartedEvent"].append(event)
+        with condition:
+            events["MemoryRetrievalStartedEvent"].append(event)
+            condition.notify_all()
 
     @crewai_event_bus.on(MemoryRetrievalCompletedEvent)
     def handle_memory_retrieval_completed(source, event):
         with condition:
             events["MemoryRetrievalCompletedEvent"].append(event)
-            condition.notify()
+            condition.notify_all()
 
     math_researcher = Agent(
         role="Researcher",
@@ -2497,10 +2513,17 @@ def handle_memory_retrieval_completed(source, event):
 
     with condition:
         success = condition.wait_for(
-            lambda: len(events["MemoryRetrievalCompletedEvent"]) >= 1, timeout=5
+            lambda: (
+                len(events["MemorySaveStartedEvent"]) >= 3
+                and len(events["MemorySaveCompletedEvent"]) >= 3
+                and len(events["MemoryQueryStartedEvent"]) >= 3
+                and len(events["MemoryQueryCompletedEvent"]) >= 3
+                and len(events["MemoryRetrievalCompletedEvent"]) >= 1
+            ),
+            timeout=10,
         )
 
-    assert success, "Timeout waiting for memory events"
+    assert success, f"Timeout waiting for memory events. Got: {dict(events)}"
     assert len(events["MemorySaveStartedEvent"]) == 3
     assert len(events["MemorySaveCompletedEvent"]) == 3
     assert len(events["MemorySaveFailedEvent"]) == 0
@@ -2590,19 +2613,16 @@ def test_long_term_memory_with_memory_flag():
         agent=math_researcher,
     )
 
-    crew = Crew(
-        agents=[math_researcher],
-        tasks=[task1],
-        memory=True,
-        long_term_memory=LongTermMemory(),
-    )
-
     with (
         patch("crewai.utilities.printer.Printer.print") as mock_print,
-        patch(
-            "crewai.memory.long_term.long_term_memory.LongTermMemory.save"
-        ) as save_memory,
+        patch("crewai.memory.long_term.long_term_memory.LongTermMemory.save") as save_memory,
     ):
+        crew = Crew(
+            agents=[math_researcher],
+            tasks=[task1],
+            memory=True,
+            long_term_memory=LongTermMemory(),
+        )
         crew.kickoff()
         mock_print.assert_not_called()
         save_memory.assert_called_once()
@@ -2855,7 +2875,7 @@ def testing_tool(first_number: int, second_number: int) -> int:
 
 
 @pytest.mark.vcr(filter_headers=["authorization"])
-def test_crew_train_success(researcher, writer):
+def test_crew_train_success(researcher, writer, monkeypatch):
     task = Task(
         description="Come up with a list of 5 interesting ideas to explore for an article, then write one amazing paragraph highlight for each idea that showcases how good an article about this topic could be. Return the list of ideas with their paragraph and your notes.",
         expected_output="5 bullet points with a paragraph for each idea.",
@@ -2885,10 +2905,13 @@ def on_crew_train_completed(source, event: CrewTrainCompletedEvent):
                 condition.notify()
 
     # Mock human input to avoid blocking during training
-    with patch("builtins.input", return_value="Great work!"):
-        crew.train(
-            n_iterations=2, inputs={"topic": "AI"}, filename="trained_agents_data.pkl"
-        )
+    # Use StringIO to simulate user input for multiple calls to input()
+    mock_inputs = StringIO("Great work!\n" * 10)  # Provide enough inputs for all iterations
+    monkeypatch.setattr("sys.stdin", mock_inputs)
+
+    crew.train(
+        n_iterations=2, inputs={"topic": "AI"}, filename="trained_agents_data.pkl"
+    )
 
     with condition:
         success = condition.wait_for(lambda: len(received_events) == 2, timeout=5)
diff --git a/lib/crewai/tests/test_custom_llm.py b/lib/crewai/tests/test_custom_llm.py
--- a/lib/crewai/tests/test_custom_llm.py
+++ b/lib/crewai/tests/test_custom_llm.py
@@ -31,6 +31,7 @@ def call(
         available_functions=None,
         from_task=None,
         from_agent=None,
+        response_model=None,
     ):
         """
         Mock LLM call that returns a predefined response.
@@ -162,6 +163,9 @@ def call(
         tools: Optional[List[dict]] = None,
         callbacks: Optional[List[Any]] = None,
         available_functions: Optional[Dict[str, Any]] = None,
+        from_task=None,
+        from_agent=None,
+        response_model=None,
     ) -> Union[str, Any]:
         """Record the call and return a predefined response."""
         self.calls.append(
@@ -241,6 +245,9 @@ def call(
         tools: Optional[List[dict]] = None,
         callbacks: Optional[List[Any]] = None,
         available_functions: Optional[Dict[str, Any]] = None,
+        from_task=None,
+        from_agent=None,
+        response_model=None,
     ) -> Union[str, Any]:
         """Simulate API calls with timeout handling and retry logic.
 
diff --git a/lib/crewai/tests/test_task.py b/lib/crewai/tests/test_task.py
--- a/lib/crewai/tests/test_task.py
+++ b/lib/crewai/tests/test_task.py
@@ -340,7 +340,7 @@ class ScoreOutput(BaseModel):
     )
     result = crew.kickoff()
     assert isinstance(result.pydantic, ScoreOutput)
-    assert result.to_dict() == {"score": 4}
+    assert result.to_dict() == {"score": 0}
 
 
 @pytest.mark.vcr(filter_headers=["authorization"])
@@ -574,8 +574,8 @@ class ScoreOutput(BaseModel):
         goal="Score the title",
         backstory="You're an expert scorer, specialized in scoring titles.",
         allow_delegation=False,
-        llm="gpt-4-0125-preview",
-        function_calling_llm="gpt-3.5-turbo-0125",
+        llm="gpt-4o",
+        function_calling_llm="gpt-4o",
         verbose=True,
     )
 
@@ -599,7 +599,7 @@ class ScoreOutput(BaseModel):
     assert isinstance(pydantic_result, ScoreOutput), (
         "Expected pydantic result to be of type ScoreOutput"
     )
-    assert pydantic_result.score == 5
+    assert pydantic_result.score == 4
 
 
 @pytest.mark.vcr(filter_headers=["authorization"])
diff --git a/lib/crewai/tests/tracing/test_tracing.py b/lib/crewai/tests/tracing/test_tracing.py
--- a/lib/crewai/tests/tracing/test_tracing.py
+++ b/lib/crewai/tests/tracing/test_tracing.py
@@ -57,6 +57,7 @@ def reset_tracing_singletons(self):
         if hasattr(TraceCollectionListener, "_instance"):
             TraceCollectionListener._instance = None
             TraceCollectionListener._initialized = False
+            TraceCollectionListener._listeners_setup = False
 
         # Reset EventListener singleton
         if hasattr(EventListener, "_instance"):
@@ -74,6 +75,7 @@ def reset_tracing_singletons(self):
         if hasattr(TraceCollectionListener, "_instance"):
             TraceCollectionListener._instance = None
             TraceCollectionListener._initialized = False
+            TraceCollectionListener._listeners_setup = False
 
         if hasattr(EventListener, "_instance"):
             EventListener._instance = None
@@ -131,25 +133,16 @@ def test_trace_listener_collects_crew_events(self):
             )
             crew = Crew(agents=[agent], tasks=[task], verbose=True)
 
+            from crewai.events.listeners.tracing.trace_listener import TraceCollectionListener
             trace_listener = TraceCollectionListener()
-            from crewai.events.event_bus import crewai_event_bus
-
-            trace_listener.setup_listeners(crewai_event_bus)
 
-            with patch.object(
-                trace_listener.batch_manager,
-                "initialize_batch",
-                return_value=None,
-            ) as initialize_mock:
-                crew.kickoff()
+            crew.kickoff()
 
-                assert initialize_mock.call_count >= 1
+            initialized = trace_listener.batch_manager.wait_for_batch_initialization(timeout=5.0)
 
-                call_args = initialize_mock.call_args_list[0]
-                assert len(call_args[0]) == 2  # user_context, execution_metadata
-                _, execution_metadata = call_args[0]
-                assert isinstance(execution_metadata, dict)
-                assert "crew_name" in execution_metadata
+            assert initialized, "Batch should have been initialized"
+            assert trace_listener.batch_manager.is_batch_initialized()
+            assert trace_listener.batch_manager.current_batch is not None
 
     @pytest.mark.vcr(filter_headers=["authorization"])
     def test_batch_manager_finalizes_batch_clears_buffer(self):
@@ -364,24 +357,21 @@ def test_trace_listener_ephemeral_batch(self):
             )
             crew = Crew(agents=[agent], tasks=[task], tracing=True)
 
-            with patch.object(TraceBatchManager, "initialize_batch") as mock_initialize:
-                crew.kickoff()
+            from crewai.events.listeners.tracing.trace_listener import TraceCollectionListener
+            trace_listener = TraceCollectionListener()
+
+            crew.kickoff()
 
-                assert mock_initialize.call_count >= 1
-                assert mock_initialize.call_args_list[0][1]["use_ephemeral"] is True
+            wait_for_event_handlers()
+
+            assert trace_listener.batch_manager.is_batch_initialized(), (
+                "Batch should have been initialized for unauthenticated user"
+            )
 
     @pytest.mark.vcr(filter_headers=["authorization"])
     def test_trace_listener_with_authenticated_user(self):
         """Test that trace listener properly handles authenticated batches"""
-        with (
-            patch.dict(os.environ, {"CREWAI_TRACING_ENABLED": "true"}),
-            patch(
-                "crewai.events.listeners.tracing.trace_batch_manager.PlusAPI"
-            ) as mock_plus_api_class,
-        ):
-            mock_plus_api_instance = MagicMock()
-            mock_plus_api_class.return_value = mock_plus_api_instance
-
+        with patch.dict(os.environ, {"CREWAI_TRACING_ENABLED": "true"}):
             agent = Agent(
                 role="Test Agent",
                 goal="Test goal",
@@ -394,21 +384,17 @@ def test_trace_listener_with_authenticated_user(self):
                 agent=agent,
             )
 
-            with (
-                patch.object(TraceBatchManager, "initialize_batch") as mock_initialize,
-                patch.object(
-                    TraceBatchManager, "finalize_batch"
-                ) as mock_finalize_backend_batch,
-            ):
-                crew = Crew(agents=[agent], tasks=[task], tracing=True)
-                crew.kickoff()
-                wait_for_event_handlers()
+            from crewai.events.listeners.tracing.trace_listener import TraceCollectionListener
+            trace_listener = TraceCollectionListener()
+
+            crew = Crew(agents=[agent], tasks=[task], tracing=True)
+            crew.kickoff()
 
-                mock_plus_api_class.assert_called_with(api_key="mock_token_12345")
+            wait_for_event_handlers()
 
-                assert mock_initialize.call_count >= 1
-                mock_finalize_backend_batch.assert_called_with()
-                assert mock_finalize_backend_batch.call_count >= 1
+            assert trace_listener.batch_manager.is_batch_initialized(), (
+                "Batch should have been initialized for authenticated user"
+            )
 
     # Helper method to ensure cleanup
     def teardown_method(self):
@@ -489,30 +475,19 @@ def test_first_time_user_trace_collection_with_timeout(self, mock_plus_api_calls
             assert trace_listener.first_time_handler.is_first_time is True
             assert trace_listener.first_time_handler.collected_events is False
 
-            with (
-                patch.object(
-                    trace_listener.first_time_handler,
-                    "handle_execution_completion",
-                    wraps=trace_listener.first_time_handler.handle_execution_completion,
-                ) as mock_handle_completion,
-                patch.object(
-                    trace_listener.batch_manager,
-                    "add_event",
-                    wraps=trace_listener.batch_manager.add_event,
-                ) as mock_add_event,
-            ):
-                result = crew.kickoff()
-                wait_for_event_handlers()
-                assert result is not None
+            trace_listener.batch_manager.batch_owner_type = "crew"
 
-                assert mock_handle_completion.call_count >= 1
-                assert mock_add_event.call_count >= 1
+            result = crew.kickoff()
+            wait_for_event_handlers()
+            assert result is not None
 
-                assert trace_listener.first_time_handler.collected_events is True
+            assert trace_listener.first_time_handler.collected_events is True, (
+                "Events should have been collected"
+            )
 
-                mock_prompt.assert_called_once()
+            mock_prompt.assert_called_once()
 
-                mock_mark_completed.assert_called_once()
+            mock_mark_completed.assert_called_once()
 
     @pytest.mark.vcr(filter_headers=["authorization"])
     def test_first_time_user_trace_collection_user_accepts(self, mock_plus_api_calls):
@@ -556,9 +531,10 @@ def test_first_time_user_trace_collection_user_accepts(self, mock_plus_api_calls
             from crewai.events.event_bus import crewai_event_bus
 
             trace_listener = TraceCollectionListener()
-            trace_listener.setup_listeners(crewai_event_bus)
 
-            assert trace_listener.first_time_handler.is_first_time is True
+            trace_listener.batch_manager.ephemeral_trace_url = (
+                "https://crewai.com/trace/mock-id"
+            )
 
             with (
                 patch.object(
@@ -569,26 +545,17 @@ def test_first_time_user_trace_collection_user_accepts(self, mock_plus_api_calls
                 patch.object(
                     trace_listener.first_time_handler, "_display_ephemeral_trace_link"
                 ) as mock_display_link,
-                patch.object(
-                    trace_listener.first_time_handler,
-                    "handle_execution_completion",
-                    wraps=trace_listener.first_time_handler.handle_execution_completion,
-                ) as mock_handle_completion,
             ):
-                trace_listener.batch_manager.ephemeral_trace_url = (
-                    "https://crewai.com/trace/mock-id"
-                )
+                trace_listener.setup_listeners(crewai_event_bus)
+
+                assert trace_listener.first_time_handler.is_first_time is True
+
+                trace_listener.first_time_handler.collected_events = True
 
                 crew.kickoff()
                 wait_for_event_handlers()
 
-                assert mock_handle_completion.call_count >= 1, (
-                    "handle_execution_completion should be called"
-                )
-
-                assert trace_listener.first_time_handler.collected_events is True, (
-                    "Events should be marked as collected"
-                )
+                trace_listener.first_time_handler.handle_execution_completion()
 
                 mock_init_backend.assert_called_once()
 
@@ -636,15 +603,14 @@ def test_first_time_user_trace_consolidation_logic(self, mock_plus_api_calls):
             )
             crew = Crew(agents=[agent], tasks=[task])
 
-            with patch.object(TraceBatchManager, "initialize_batch") as mock_initialize:
-                result = crew.kickoff()
+            result = crew.kickoff()
 
-                assert trace_listener.batch_manager.wait_for_pending_events(timeout=5.0), (
-                    "Timeout waiting for trace event handlers to complete"
-                )
-                assert mock_initialize.call_count >= 1
-                assert mock_initialize.call_args_list[0][1]["use_ephemeral"] is True
-                assert result is not None
+            wait_for_event_handlers()
+
+            assert trace_listener.batch_manager.is_batch_initialized(), (
+                "Batch should have been initialized for first-time user"
+            )
+            assert result is not None
 
     def test_first_time_handler_timeout_behavior(self):
         """Test the timeout behavior of the first-time trace prompt"""
@@ -699,60 +665,43 @@ def test_first_time_handler_graceful_error_handling(self):
 
             mock_mark_completed.assert_called_once()
 
-    @pytest.mark.vcr(filter_headers=["authorization"])
-    def test_trace_batch_marked_as_failed_on_finalize_error(self, mock_plus_api_calls):
+    def test_trace_batch_marked_as_failed_on_finalize_error(self):
         """Test that trace batch is marked as failed when finalization returns non-200 status"""
+        # Test the error handling logic directly in TraceBatchManager
+        batch_manager = TraceBatchManager()
+
+        # Initialize a batch
+        batch_manager.current_batch = batch_manager.initialize_batch(
+            user_context={"privacy_level": "standard"},
+            execution_metadata={
+                "execution_type": "crew",
+                "crew_name": "test_crew",
+            },
+        )
+        batch_manager.trace_batch_id = "test_batch_id_12345"
+        batch_manager.backend_initialized = True
+
+        # Mock the API responses
+        with (
+            patch.object(
+                batch_manager.plus_api,
+                "send_trace_events",
+                return_value=MagicMock(status_code=200),
+            ),
+            patch.object(
+                batch_manager.plus_api,
+                "finalize_trace_batch",
+                return_value=MagicMock(status_code=500, text="Internal Server Error"),
+            ),
+            patch.object(
+                batch_manager.plus_api,
+                "mark_trace_batch_as_failed",
+            ) as mock_mark_failed,
+        ):
+            # Call finalize_batch directly
+            batch_manager.finalize_batch()
 
-        with patch.dict(os.environ, {"CREWAI_TRACING_ENABLED": "true"}):
-            agent = Agent(
-                role="Test Agent",
-                goal="Test goal",
-                backstory="Test backstory",
-                llm="gpt-4o-mini",
+            # Verify that mark_trace_batch_as_failed was called with the error message
+            mock_mark_failed.assert_called_once_with(
+                "test_batch_id_12345", "Internal Server Error"
             )
-            task = Task(
-                description="Say hello to the world",
-                expected_output="hello world",
-                agent=agent,
-            )
-            crew = Crew(agents=[agent], tasks=[task], verbose=True)
-
-            trace_listener = TraceCollectionListener()
-            from crewai.events.event_bus import crewai_event_bus
-
-            trace_listener.setup_listeners(crewai_event_bus)
-
-            mock_init_response = MagicMock()
-            mock_init_response.status_code = 200
-            mock_init_response.json.return_value = {"trace_id": "test_batch_id_12345"}
-
-            with (
-                patch.object(
-                    trace_listener.batch_manager.plus_api,
-                    "initialize_trace_batch",
-                    return_value=mock_init_response,
-                ),
-                patch.object(
-                    trace_listener.batch_manager.plus_api,
-                    "send_trace_events",
-                    return_value=MagicMock(status_code=200),
-                ),
-                patch.object(
-                    trace_listener.batch_manager.plus_api,
-                    "finalize_trace_batch",
-                    return_value=MagicMock(
-                        status_code=500, text="Internal Server Error"
-                    ),
-                ),
-                patch.object(
-                    trace_listener.batch_manager.plus_api,
-                    "mark_trace_batch_as_failed",
-                    wraps=mock_plus_api_calls["mark_trace_batch_as_failed"],
-                ) as mock_mark_failed,
-            ):
-                crew.kickoff()
-                wait_for_event_handlers()
-
-                mock_mark_failed.assert_called_once()
-                call_args = mock_mark_failed.call_args_list[0]
-                assert call_args[0][1] == "Internal Server Error"
diff --git a/lib/crewai/tests/utilities/cassettes/test_convert_with_instructions.yaml b/lib/crewai/tests/utilities/cassettes/test_convert_with_instructions.yaml
--- a/lib/crewai/tests/utilities/cassettes/test_convert_with_instructions.yaml
+++ b/lib/crewai/tests/utilities/cassettes/test_convert_with_instructions.yaml
@@ -1,12 +1,9 @@
 interactions:
 - request:
-    body: '{"messages": [{"role": "user", "content": "Name: Alice, Age: 30"}], "model":
-      "gpt-4o-mini", "tool_choice": {"type": "function", "function": {"name": "SimpleModel"}},
-      "tools": [{"type": "function", "function": {"name": "SimpleModel", "description":
-      "Correctly extracted `SimpleModel` with all the required parameters with correct
-      types", "parameters": {"properties": {"name": {"title": "Name", "type": "string"},
-      "age": {"title": "Age", "type": "integer"}}, "required": ["age", "name"], "type":
-      "object"}}}]}'
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    name: str,\n    age: int\n}\n```"},{"role":"user","content":"Name:
+      Alice, Age: 30"}],"model":"gpt-4o-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"properties":{"name":{"title":"Name","type":"string"},"age":{"title":"Age","type":"integer"}},"required":["name","age"],"title":"SimpleModel","type":"object","additionalProperties":false},"name":"SimpleModel","strict":true}},"stream":false}'
     headers:
       accept:
       - application/json
@@ -15,70 +12,67 @@ interactions:
       connection:
       - keep-alive
       content-length:
-      - '507'
+      - '614'
       content-type:
       - application/json
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.59.6
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
       - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
       x-stainless-lang:
       - python
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.59.6
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
       x-stainless-retry-count:
       - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.12.7
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
-    content: "{\n  \"id\": \"chatcmpl-Aq4a4xDv8G0i4fbTtPJEI2B8UNBup\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1736974028,\n  \"model\": \"gpt-4o-mini-2024-07-18\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": null,\n        \"tool_calls\": [\n          {\n
-      \           \"id\": \"call_uO5nec8hTk1fpYINM8TUafhe\",\n            \"type\":
-      \"function\",\n            \"function\": {\n              \"name\": \"SimpleModel\",\n
-      \             \"arguments\": \"{\\\"name\\\":\\\"Alice\\\",\\\"age\\\":30}\"\n
-      \           }\n          }\n        ],\n        \"refusal\": null\n      },\n
-      \     \"logprobs\": null,\n      \"finish_reason\": \"stop\"\n    }\n  ],\n
-      \ \"usage\": {\n    \"prompt_tokens\": 79,\n    \"completion_tokens\": 10,\n
-      \   \"total_tokens\": 89,\n    \"prompt_tokens_details\": {\n      \"cached_tokens\":
-      0,\n      \"audio_tokens\": 0\n    },\n    \"completion_tokens_details\": {\n
-      \     \"reasoning_tokens\": 0,\n      \"audio_tokens\": 0,\n      \"accepted_prediction_tokens\":
-      0,\n      \"rejected_prediction_tokens\": 0\n    }\n  },\n  \"service_tier\":
-      \"default\",\n  \"system_fingerprint\": \"fp_72ed7ab54c\"\n}\n"
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jJJNa9wwEIbv/hViznaRN/vpW9tDCbmEQkmgDkaRxl519YUkl6bL/vci
+        e7N2vqAXH+aZd/y+ozlmhIAUUBHgexa5dqr4end/+7d84nf0dkG71eH6x5dveGPu9fLw/QrypLCP
+        v5DHZ9UnbrVTGKU1I+YeWcQ0tdysy+2G7nblALQVqJKsc7FY2kJLI4sFXSwLuinK7Vm9t5JjgIr8
+        zAgh5Dh8k08j8A9UhObPFY0hsA6hujQRAt6qVAEWggyRmQj5BLk1Ec1g/ViDYRprqGr4rCTHGvIa
+        WJcqV/Q0V3ls+8CSc9MrNQPMGBtZSj74fTiT08Whsp3z9jG8kkIrjQz7xiML1iQ3IVoHAz1lhDwM
+        m+hfhAPnrXaxifaAw+9Kuh3nwfQAE92dWbSRqZmo3OTvjGsERiZVmK0SOON7FJN02jvrhbQzkM1C
+        vzXz3uwxuDTd/4yfAOfoIorGeRSSvww8tXlM5/lR22XJg2EI6H9Ljk2U6NNDCGxZr8ajgfAUIuqm
+        laZD77wcL6d1zWpNWbvG1WoH2Sn7BwAA//8DAFzfDxVHAwAA
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
       CF-RAY:
-      - 9028b81aeb1cb05f-ATL
+      - 996f142248320e95-MXP
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Wed, 15 Jan 2025 20:47:08 GMT
+      - Fri, 31 Oct 2025 00:36:32 GMT
       Server:
       - cloudflare
       Set-Cookie:
-      - __cf_bm=PzayZLF04c14veGc.0ocVg3VHBbpzKRW8Hqox8L9U7c-1736974028-1.0.1.1-mZpK8.SH9l7K2z8Tvt6z.dURiVPjFqEz7zYEITfRwdr5z0razsSebZGN9IRPmI5XC_w5rbZW2Kg6hh5cenXinQ;
-        path=/; expires=Wed, 15-Jan-25 21:17:08 GMT; domain=.api.openai.com; HttpOnly;
+      - __cf_bm=EsqV2uuHnkXCOCTW4ZgAmdmEKc4Mm3rVQw8twE209RI-1761870992-1.0.1.1-9xJoNnZ.Dpd56yJgZXGBk6iT6jSA7DBzzX2o7PVGP0baco7.cdHEcyfEimiAqgD6HguvoiO.P6i.fx.aeHfpa6fmsTSTXeC5pUlCU_yJcRA;
+        path=/; expires=Fri, 31-Oct-25 01:06:32 GMT; domain=.api.openai.com; HttpOnly;
         Secure; SameSite=None
-      - _cfuvid=ciwC3n2Srn20xx4JhEUeN6Ap0tNBaE44S95nIilboQ0-1736974028496-0.0.1.1-604800000;
+      - _cfuvid=KGFXdIUU9WK3qTOFK_oSCA_E_JdqnOONwqzgqMuyGto-1761870992424-0.0.1.1-604800000;
         path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
       Transfer-Encoding:
       - chunked
       X-Content-Type-Options:
@@ -87,28 +81,41 @@ interactions:
       - X-Request-ID
       alt-svc:
       - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '439'
+      - '488'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
+      x-envoy-upstream-service-time:
+      - '519'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
       x-ratelimit-limit-requests:
       - '30000'
       x-ratelimit-limit-tokens:
       - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999945'
       x-ratelimit-remaining-requests:
       - '29999'
       x-ratelimit-remaining-tokens:
-      - '149999978'
+      - '149999945'
+      x-ratelimit-reset-project-tokens:
+      - 0s
       x-ratelimit-reset-requests:
       - 2ms
       x-ratelimit-reset-tokens:
       - 0s
       x-request-id:
-      - req_a468000458b9d2848b7497b2e3d485a3
-    http_version: HTTP/1.1
-    status_code: 200
+      - req_4a7800f3477e434ba981c5ba29a6d7d3
+    status:
+      code: 200
+      message: OK
 version: 1
diff --git a/lib/crewai/tests/utilities/cassettes/test_converter_with_nested_model.yaml b/lib/crewai/tests/utilities/cassettes/test_converter_with_nested_model.yaml
--- a/lib/crewai/tests/utilities/cassettes/test_converter_with_nested_model.yaml
+++ b/lib/crewai/tests/utilities/cassettes/test_converter_with_nested_model.yaml
@@ -1,16 +1,12 @@
 interactions:
 - request:
-    body: '{"messages": [{"role": "user", "content": "Name: John Doe\nAge: 30\nAddress:
-      123 Main St, Anytown, 12345"}], "model": "gpt-4o-mini", "tool_choice": {"type":
-      "function", "function": {"name": "Person"}}, "tools": [{"type": "function",
-      "function": {"name": "Person", "description": "Correctly extracted `Person`
-      with all the required parameters with correct types", "parameters": {"$defs":
-      {"Address": {"properties": {"street": {"title": "Street", "type": "string"},
-      "city": {"title": "City", "type": "string"}, "zip_code": {"title": "Zip Code",
-      "type": "string"}}, "required": ["street", "city", "zip_code"], "title": "Address",
-      "type": "object"}}, "properties": {"name": {"title": "Name", "type": "string"},
-      "age": {"title": "Age", "type": "integer"}, "address": {"$ref": "#/$defs/Address"}},
-      "required": ["address", "age", "name"], "type": "object"}}}]}'
+    body: '{"messages":[{"role":"system","content":"Please convert the following text
+      into valid JSON.\n\nOutput ONLY the valid JSON and nothing else.\n\nThe JSON
+      must follow this schema exactly:\n```json\n{\n    name: str,\n    age: int,\n    address:
+      Address\n    {\n        street: str,\n        city: str,\n        zip_code:
+      str\n    }\n}\n```"},{"role":"user","content":"Name: John Doe\nAge: 30\nAddress:
+      123 Main St, Anytown, 12345"}],"model":"gpt-4o-mini","response_format":{"type":"json_schema","json_schema":{"schema":{"$defs":{"Address":{"properties":{"street":{"title":"Street","type":"string"},"city":{"title":"City","type":"string"},"zip_code":{"title":"Zip
+      Code","type":"string"}},"required":["street","city","zip_code"],"title":"Address","type":"object","additionalProperties":false}},"properties":{"name":{"title":"Name","type":"string"},"age":{"title":"Age","type":"integer"},"address":{"$ref":"#/$defs/Address"}},"required":["name","age","address"],"title":"Person","type":"object","additionalProperties":false},"name":"Person","strict":true}},"stream":false}'
     headers:
       accept:
       - application/json
@@ -19,68 +15,68 @@ interactions:
       connection:
       - keep-alive
       content-length:
-      - '853'
+      - '1066'
       content-type:
       - application/json
-      cookie:
-      - __cf_bm=PzayZLF04c14veGc.0ocVg3VHBbpzKRW8Hqox8L9U7c-1736974028-1.0.1.1-mZpK8.SH9l7K2z8Tvt6z.dURiVPjFqEz7zYEITfRwdr5z0razsSebZGN9IRPmI5XC_w5rbZW2Kg6hh5cenXinQ;
-        _cfuvid=ciwC3n2Srn20xx4JhEUeN6Ap0tNBaE44S95nIilboQ0-1736974028496-0.0.1.1-604800000
       host:
       - api.openai.com
       user-agent:
-      - OpenAI/Python 1.59.6
+      - OpenAI/Python 1.109.1
       x-stainless-arch:
       - arm64
       x-stainless-async:
       - 'false'
+      x-stainless-helper-method:
+      - chat.completions.parse
       x-stainless-lang:
       - python
       x-stainless-os:
       - MacOS
       x-stainless-package-version:
-      - 1.59.6
-      x-stainless-raw-response:
-      - 'true'
+      - 1.109.1
+      x-stainless-read-timeout:
+      - '600'
       x-stainless-retry-count:
       - '0'
       x-stainless-runtime:
       - CPython
       x-stainless-runtime-version:
-      - 3.12.7
+      - 3.12.10
     method: POST
     uri: https://api.openai.com/v1/chat/completions
   response:
-    content: "{\n  \"id\": \"chatcmpl-Aq4aFpbhU10QK0e6Jlkxy8AUxCZCf\",\n  \"object\":
-      \"chat.completion\",\n  \"created\": 1736974039,\n  \"model\": \"gpt-4o-mini-2024-07-18\",\n
-      \ \"choices\": [\n    {\n      \"index\": 0,\n      \"message\": {\n        \"role\":
-      \"assistant\",\n        \"content\": null,\n        \"tool_calls\": [\n          {\n
-      \           \"id\": \"call_N29aoGL9tN0qL2O7HI8Op2so\",\n            \"type\":
-      \"function\",\n            \"function\": {\n              \"name\": \"Person\",\n
-      \             \"arguments\": \"{\\\"name\\\":\\\"John Doe\\\",\\\"age\\\":30,\\\"address\\\":{\\\"street\\\":\\\"123
-      Main St\\\",\\\"city\\\":\\\"Anytown\\\",\\\"zip_code\\\":\\\"12345\\\"}}\"\n
-      \           }\n          }\n        ],\n        \"refusal\": null\n      },\n
-      \     \"logprobs\": null,\n      \"finish_reason\": \"stop\"\n    }\n  ],\n
-      \ \"usage\": {\n    \"prompt_tokens\": 118,\n    \"completion_tokens\": 30,\n
-      \   \"total_tokens\": 148,\n    \"prompt_tokens_details\": {\n      \"cached_tokens\":
-      0,\n      \"audio_tokens\": 0\n    },\n    \"completion_tokens_details\": {\n
-      \     \"reasoning_tokens\": 0,\n      \"audio_tokens\": 0,\n      \"accepted_prediction_tokens\":
-      0,\n      \"rejected_prediction_tokens\": 0\n    }\n  },\n  \"service_tier\":
-      \"default\",\n  \"system_fingerprint\": \"fp_bd83329f63\"\n}\n"
+    body:
+      string: !!binary |
+        H4sIAAAAAAAAAwAAAP//jJPLbtswEEX3+gpi1lYhP+TXrk0apAVaoEiBBKgCgSFHMmuJJMhxW9fw
+        vweUZEtOE6AbLebMvZoXDxFjoCSsGYgNJ1HbKr66f/iWfJrf3hU335f8Ovnwtb6/+Xi7nV5t1QOM
+        gsI8/URBJ9U7YWpbISmjWywccsLgOl7Mx8tFslpNGlAbiVWQlZbimYlrpVU8SSazOFnE42Wn3hgl
+        0MOa/YgYY+zQfEOdWuIfWLNkdIrU6D0vEdbnJMbAmSpEgHuvPHFNMOqhMJpQN6UfMh1CGWheYwZr
+        lsFns9Hs2mAGoxPkZcOmSR+R0qH3IdpZtHFPDpFao/Fkyr5wpdkdnb3aLKFo3+a813syv/UL/lfZ
+        XBiJZ59ZmkGbcMz0cdiLw2LneZin3lXVAHCtDfGwj2aKjx05nudWmdI68+RfSKFQWvlN7pB7o8OM
+        PBkLDT1GjD02+9ldjBysM7WlnMwWm99NklXrB/1Z9DQdd5AM8WqgmndbvfTLJRJXlR9sGAQXG5S9
+        tD8HvpPKDEA06Prfal7zbjtXuvwf+x4IgZZQ5tahVOKy4z7NYXg1b6Wdp9wUDB7dLyUwJ4UubEJi
+        wXdVe8vg956wzgulS3TWqfagC5un84QXc0zTFUTH6BkAAP//AwDQ4LiL3gMAAA==
     headers:
-      CF-Cache-Status:
-      - DYNAMIC
       CF-RAY:
-      - 9028b863dbaa672f-ATL
+      - 996f14274966b937-MXP
       Connection:
       - keep-alive
       Content-Encoding:
       - gzip
       Content-Type:
       - application/json
       Date:
-      - Wed, 15 Jan 2025 20:47:20 GMT
+      - Fri, 31 Oct 2025 00:36:33 GMT
       Server:
       - cloudflare
+      Set-Cookie:
+      - __cf_bm=Ky4svfN6lhcQM6_crJFh23VuIuexOT5hNS6bhEbr7Qw-1761870993-1.0.1.1-p4Z6TA9wRLlEmiM83sZcdaHZbTds.ZzUr2lEGCtUkU2kP2WdalMAAsExqn9B0k9Okf1SUq3vKTfFK2UC4a8NtjDpRaLru0DDiJJbp9VFOfQ;
+        path=/; expires=Fri, 31-Oct-25 01:06:33 GMT; domain=.api.openai.com; HttpOnly;
+        Secure; SameSite=None
+      - _cfuvid=vvK_iahsZb8gVwsnRdmPfAjYUYT08lth_CtAEZuGCGY-1761870993906-0.0.1.1-604800000;
+        path=/; domain=.api.openai.com; HttpOnly; Secure; SameSite=None
+      Strict-Transport-Security:
+      - max-age=31536000; includeSubDomains; preload
       Transfer-Encoding:
       - chunked
       X-Content-Type-Options:
@@ -89,457 +85,40 @@ interactions:
       - X-Request-ID
       alt-svc:
       - h3=":443"; ma=86400
+      cf-cache-status:
+      - DYNAMIC
       openai-organization:
       - crewai-iuxna1
       openai-processing-ms:
-      - '840'
+      - '1204'
+      openai-project:
+      - proj_xitITlrFeen7zjNSzML82h9x
       openai-version:
       - '2020-10-01'
-      strict-transport-security:
-      - max-age=31536000; includeSubDomains; preload
+      x-envoy-upstream-service-time:
+      - '1228'
+      x-openai-proxy-wasm:
+      - v0.1
+      x-ratelimit-limit-project-tokens:
+      - '150000000'
       x-ratelimit-limit-requests:
       - '30000'
       x-ratelimit-limit-tokens:
       - '150000000'
+      x-ratelimit-remaining-project-tokens:
+      - '149999912'
       x-ratelimit-remaining-requests:
       - '29999'
       x-ratelimit-remaining-tokens:
-      - '149999968'
+      - '149999912'
+      x-ratelimit-reset-project-tokens:
+      - 0s
       x-ratelimit-reset-requests:
       - 2ms
       x-ratelimit-reset-tokens:
       - 0s
       x-request-id:
-      - req_2f9d1e3f0ace4944891dde05093486aa
-    http_version: HTTP/1.1
-    status_code: 200
-- request:
-    body: '{"name": "llama3.2:3b"}'
-    headers:
-      accept:
-      - '*/*'
-      accept-encoding:
-      - gzip, deflate
-      connection:
-      - keep-alive
-      content-length:
-      - '23'
-      content-type:
-      - application/json
-      host:
-      - localhost:11434
-      user-agent:
-      - litellm/1.68.0
-    method: POST
-    uri: http://localhost:11434/api/show
-  response:
-    body:
-      string: "{\"license\":\"LLAMA 3.2 COMMUNITY LICENSE AGREEMENT\\nLlama 3.2 Version
-        Release Date: September 25, 2024\\n\\n\u201CAgreement\u201D means the terms
-        and conditions for use, reproduction, distribution \\nand modification of
-        the Llama Materials set forth herein.\\n\\n\u201CDocumentation\u201D means
-        the specifications, manuals and documentation accompanying Llama 3.2\\ndistributed
-        by Meta at https://llama.meta.com/doc/overview.\\n\\n\u201CLicensee\u201D
-        or \u201Cyou\u201D means you, or your employer or any other person or entity
-        (if you are \\nentering into this Agreement on such person or entity\u2019s
-        behalf), of the age required under\\napplicable laws, rules or regulations
-        to provide legal consent and that has legal authority\\nto bind your employer
-        or such other person or entity if you are entering in this Agreement\\non
-        their behalf.\\n\\n\u201CLlama 3.2\u201D means the foundational large language
-        models and software and algorithms, including\\nmachine-learning model code,
-        trained model weights, inference-enabling code, training-enabling code,\\nfine-tuning
-        enabling code and other elements of the foregoing distributed by Meta at \\nhttps://www.llama.com/llama-downloads.\\n\\n\u201CLlama
-        Materials\u201D means, collectively, Meta\u2019s proprietary Llama 3.2 and
-        Documentation (and \\nany portion thereof) made available under this Agreement.\\n\\n\u201CMeta\u201D
-        or \u201Cwe\u201D means Meta Platforms Ireland Limited (if you are located
-        in or, \\nif you are an entity, your principal place of business is in the
-        EEA or Switzerland) \\nand Meta Platforms, Inc. (if you are located outside
-        of the EEA or Switzerland). \\n\\n\\nBy clicking \u201CI Accept\u201D below
-        or by using or distributing any portion or element of the Llama Materials,\\nyou
-        agree to be bound by this Agreement.\\n\\n\\n1. License Rights and Redistribution.\\n\\n
-        \   a. Grant of Rights. You are granted a non-exclusive, worldwide, \\nnon-transferable
-        and royalty-free limited license under Meta\u2019s intellectual property or
-        other rights \\nowned by Meta embodied in the Llama Materials to use, reproduce,
-        distribute, copy, create derivative works \\nof, and make modifications to
-        the Llama Materials.  \\n\\n    b. Redistribution and Use.  \\n\\n        i.
-        If you distribute or make available the Llama Materials (or any derivative
-        works thereof), \\nor a product or service (including another AI model) that
-        contains any of them, you shall (A) provide\\na copy of this Agreement with
-        any such Llama Materials; and (B) prominently display \u201CBuilt with Llama\u201D\\non
-        a related website, user interface, blogpost, about page, or product documentation.
-        If you use the\\nLlama Materials or any outputs or results of the Llama Materials
-        to create, train, fine tune, or\\notherwise improve an AI model, which is
-        distributed or made available, you shall also include \u201CLlama\u201D\\nat
-        the beginning of any such AI model name.\\n\\n        ii. If you receive Llama
-        Materials, or any derivative works thereof, from a Licensee as part\\nof an
-        integrated end user product, then Section 2 of this Agreement will not apply
-        to you. \\n\\n        iii. You must retain in all copies of the Llama Materials
-        that you distribute the \\nfollowing attribution notice within a \u201CNotice\u201D
-        text file distributed as a part of such copies: \\n\u201CLlama 3.2 is licensed
-        under the Llama 3.2 Community License, Copyright \xA9 Meta Platforms,\\nInc.
-        All Rights Reserved.\u201D\\n\\n        iv. Your use of the Llama Materials
-        must comply with applicable laws and regulations\\n(including trade compliance
-        laws and regulations) and adhere to the Acceptable Use Policy for\\nthe Llama
-        Materials (available at https://www.llama.com/llama3_2/use-policy), which
-        is hereby \\nincorporated by reference into this Agreement.\\n  \\n2. Additional
-        Commercial Terms. If, on the Llama 3.2 version release date, the monthly active
-        users\\nof the products or services made available by or for Licensee, or
-        Licensee\u2019s affiliates, \\nis greater than 700 million monthly active
-        users in the preceding calendar month, you must request \\na license from
-        Meta, which Meta may grant to you in its sole discretion, and you are not
-        authorized to\\nexercise any of the rights under this Agreement unless or
-        until Meta otherwise expressly grants you such rights.\\n\\n3. Disclaimer
-        of Warranty. UNLESS REQUIRED BY APPLICABLE LAW, THE LLAMA MATERIALS AND ANY
-        OUTPUT AND \\nRESULTS THEREFROM ARE PROVIDED ON AN \u201CAS IS\u201D BASIS,
-        WITHOUT WARRANTIES OF ANY KIND, AND META DISCLAIMS\\nALL WARRANTIES OF ANY
-        KIND, BOTH EXPRESS AND IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES\\nOF
-        TITLE, NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
-        YOU ARE SOLELY RESPONSIBLE\\nFOR DETERMINING THE APPROPRIATENESS OF USING
-        OR REDISTRIBUTING THE LLAMA MATERIALS AND ASSUME ANY RISKS ASSOCIATED\\nWITH
-        YOUR USE OF THE LLAMA MATERIALS AND ANY OUTPUT AND RESULTS.\\n\\n4. Limitation
-        of Liability. IN NO EVENT WILL META OR ITS AFFILIATES BE LIABLE UNDER ANY
-        THEORY OF LIABILITY, \\nWHETHER IN CONTRACT, TORT, NEGLIGENCE, PRODUCTS LIABILITY,
-        OR OTHERWISE, ARISING OUT OF THIS AGREEMENT, \\nFOR ANY LOST PROFITS OR ANY
-        INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL, EXEMPLARY OR PUNITIVE DAMAGES,
-        EVEN \\nIF META OR ITS AFFILIATES HAVE BEEN ADVISED OF THE POSSIBILITY OF
-        ANY OF THE FOREGOING.\\n\\n5. Intellectual Property.\\n\\n    a. No trademark
-        licenses are granted under this Agreement, and in connection with the Llama
-        Materials, \\nneither Meta nor Licensee may use any name or mark owned by
-        or associated with the other or any of its affiliates, \\nexcept as required
-        for reasonable and customary use in describing and redistributing the Llama
-        Materials or as \\nset forth in this Section 5(a). Meta hereby grants you
-        a license to use \u201CLlama\u201D (the \u201CMark\u201D) solely as required
-        \\nto comply with the last sentence of Section 1.b.i. You will comply with
-        Meta\u2019s brand guidelines (currently accessible \\nat https://about.meta.com/brand/resources/meta/company-brand/).
-        All goodwill arising out of your use of the Mark \\nwill inure to the benefit
-        of Meta.\\n\\n    b. Subject to Meta\u2019s ownership of Llama Materials and
-        derivatives made by or for Meta, with respect to any\\n    derivative works
-        and modifications of the Llama Materials that are made by you, as between
-        you and Meta,\\n    you are and will be the owner of such derivative works
-        and modifications.\\n\\n    c. If you institute litigation or other proceedings
-        against Meta or any entity (including a cross-claim or\\n    counterclaim
-        in a lawsuit) alleging that the Llama Materials or Llama 3.2 outputs or results,
-        or any portion\\n    of any of the foregoing, constitutes infringement of
-        intellectual property or other rights owned or licensable\\n    by you, then
-        any licenses granted to you under this Agreement shall terminate as of the
-        date such litigation or\\n    claim is filed or instituted. You will indemnify
-        and hold harmless Meta from and against any claim by any third\\n    party
-        arising out of or related to your use or distribution of the Llama Materials.\\n\\n6.
-        Term and Termination. The term of this Agreement will commence upon your acceptance
-        of this Agreement or access\\nto the Llama Materials and will continue in
-        full force and effect until terminated in accordance with the terms\\nand
-        conditions herein. Meta may terminate this Agreement if you are in breach
-        of any term or condition of this\\nAgreement. Upon termination of this Agreement,
-        you shall delete and cease use of the Llama Materials. Sections 3,\\n4 and
-        7 shall survive the termination of this Agreement. \\n\\n7. Governing Law
-        and Jurisdiction. This Agreement will be governed and construed under the
-        laws of the State of \\nCalifornia without regard to choice of law principles,
-        and the UN Convention on Contracts for the International\\nSale of Goods does
-        not apply to this Agreement. The courts of California shall have exclusive
-        jurisdiction of\\nany dispute arising out of this Agreement.\\n**Llama 3.2**
-        **Acceptable Use Policy**\\n\\nMeta is committed to promoting safe and fair
-        use of its tools and features, including Llama 3.2. If you access or use Llama
-        3.2, you agree to this Acceptable Use Policy (\u201C**Policy**\u201D). The
-        most recent copy of this policy can be found at [https://www.llama.com/llama3_2/use-policy](https://www.llama.com/llama3_2/use-policy).\\n\\n**Prohibited
-        Uses**\\n\\nWe want everyone to use Llama 3.2 safely and responsibly. You
-        agree you will not use, or allow others to use, Llama 3.2 to:\\n\\n\\n\\n1.
-        Violate the law or others\u2019 rights, including to:\\n    1. Engage in,
-        promote, generate, contribute to, encourage, plan, incite, or further illegal
-        or unlawful activity or content, such as:\\n        1. Violence or terrorism\\n
-        \       2. Exploitation or harm to children, including the solicitation, creation,
-        acquisition, or dissemination of child exploitative content or failure to
-        report Child Sexual Abuse Material\\n        3. Human trafficking, exploitation,
-        and sexual violence\\n        4. The illegal distribution of information or
-        materials to minors, including obscene materials, or failure to employ legally
-        required age-gating in connection with such information or materials.\\n        5.
-        Sexual solicitation\\n        6. Any other criminal activity\\n    1. Engage
-        in, promote, incite, or facilitate the harassment, abuse, threatening, or
-        bullying of individuals or groups of individuals\\n    2. Engage in, promote,
-        incite, or facilitate discrimination or other unlawful or harmful conduct
-        in the provision of employment, employment benefits, credit, housing, other
-        economic benefits, or other essential goods and services\\n    3. Engage in
-        the unauthorized or unlicensed practice of any profession including, but not
-        limited to, financial, legal, medical/health, or related professional practices\\n
-        \   4. Collect, process, disclose, generate, or infer private or sensitive
-        information about individuals, including information about individuals\u2019
-        identity, health, or demographic information, unless you have obtained the
-        right to do so in accordance with applicable law\\n    5. Engage in or facilitate
-        any action or generate any content that infringes, misappropriates, or otherwise
-        violates any third-party rights, including the outputs or results of any products
-        or services using the Llama Materials\\n    6. Create, generate, or facilitate
-        the creation of malicious code, malware, computer viruses or do anything else
-        that could disable, overburden, interfere with or impair the proper working,
-        integrity, operation or appearance of a website or computer system\\n    7.
-        Engage in any action, or facilitate any action, to intentionally circumvent
-        or remove usage restrictions or other safety measures, or to enable functionality
-        disabled by Meta\\n2. Engage in, promote, incite, facilitate, or assist in
-        the planning or development of activities that present a risk of death or
-        bodily harm to individuals, including use of Llama 3.2 related to the following:\\n
-        \   8. Military, warfare, nuclear industries or applications, espionage, use
-        for materials or activities that are subject to the International Traffic
-        Arms Regulations (ITAR) maintained by the United States Department of State
-        or to the U.S. Biological Weapons Anti-Terrorism Act of 1989 or the Chemical
-        Weapons Convention Implementation Act of 1997\\n    9. Guns and illegal weapons
-        (including weapon development)\\n    10. Illegal drugs and regulated/controlled
-        substances\\n    11. Operation of critical infrastructure, transportation
-        technologies, or heavy machinery\\n    12. Self-harm or harm to others, including
-        suicide, cutting, and eating disorders\\n    13. Any content intended to incite
-        or promote violence, abuse, or any infliction of bodily harm to an individual\\n3.
-        Intentionally deceive or mislead others, including use of Llama 3.2 related
-        to the following:\\n    14. Generating, promoting, or furthering fraud or
-        the creation or promotion of disinformation\\n    15. Generating, promoting,
-        or furthering defamatory content, including the creation of defamatory statements,
-        images, or other content\\n    16. Generating, promoting, or further distributing
-        spam\\n    17. Impersonating another individual without consent, authorization,
-        or legal right\\n    18. Representing that the use of Llama 3.2 or outputs
-        are human-generated\\n    19. Generating or facilitating false online engagement,
-        including fake reviews and other means of fake online engagement\\n4. Fail
-        to appropriately disclose to end users any known dangers of your AI system\\n5.
-        Interact with third party tools, models, or software designed to generate
-        unlawful content or engage in unlawful or harmful conduct and/or represent
-        that the outputs of such tools, models, or software are associated with Meta
-        or Llama 3.2\\n\\nWith respect to any multimodal models included in Llama
-        3.2, the rights granted under Section 1(a) of the Llama 3.2 Community License
-        Agreement are not being granted to you if you are an individual domiciled
-        in, or a company with a principal place of business in, the European Union.
-        This restriction does not apply to end users of a product or service that
-        incorporates any such multimodal models.\\n\\nPlease report any violation
-        of this Policy, software \u201Cbug,\u201D or other problems that could lead
-        to a violation of this Policy through one of the following means:\\n\\n\\n\\n*
-        Reporting issues with the model: [https://github.com/meta-llama/llama-models/issues](https://l.workplace.com/l.php?u=https%3A%2F%2Fgithub.com%2Fmeta-llama%2Fllama-models%2Fissues\\u0026h=AT0qV8W9BFT6NwihiOHRuKYQM_UnkzN_NmHMy91OT55gkLpgi4kQupHUl0ssR4dQsIQ8n3tfd0vtkobvsEvt1l4Ic6GXI2EeuHV8N08OG2WnbAmm0FL4ObkazC6G_256vN0lN9DsykCvCqGZ)\\n*
-        Reporting risky content generated by the model: [developers.facebook.com/llama_output_feedback](http://developers.facebook.com/llama_output_feedback)\\n*
-        Reporting bugs and security concerns: [facebook.com/whitehat/info](http://facebook.com/whitehat/info)\\n*
-        Reporting violations of the Acceptable Use Policy or unlicensed uses of Llama
-        3.2: LlamaUseReport@meta.com\",\"modelfile\":\"# Modelfile generated by \\\"ollama
-        show\\\"\\n# To build a new Modelfile based on this, replace FROM with:\\n#
-        FROM llama3.2:3b\\n\\nFROM /root/.ollama/models/blobs/sha256-dde5aa3fc5ffc17176b5e8bdc82f587b24b2678c6c66101bf7da77af9f7ccdff\\nTEMPLATE
-        \\\"\\\"\\\"\\u003c|start_header_id|\\u003esystem\\u003c|end_header_id|\\u003e\\n\\nCutting
-        Knowledge Date: December 2023\\n\\n{{ if .System }}{{ .System }}\\n{{- end
-        }}\\n{{- if .Tools }}When you receive a tool call response, use the output
-        to format an answer to the orginal user question.\\n\\nYou are a helpful assistant
-        with tool calling capabilities.\\n{{- end }}\\u003c|eot_id|\\u003e\\n{{- range
-        $i, $_ := .Messages }}\\n{{- $last := eq (len (slice $.Messages $i)) 1 }}\\n{{-
-        if eq .Role \\\"user\\\" }}\\u003c|start_header_id|\\u003euser\\u003c|end_header_id|\\u003e\\n{{-
-        if and $.Tools $last }}\\n\\nGiven the following functions, please respond
-        with a JSON for a function call with its proper arguments that best answers
-        the given prompt.\\n\\nRespond in the format {\\\"name\\\": function name,
-        \\\"parameters\\\": dictionary of argument name and its value}. Do not use
-        variables.\\n\\n{{ range $.Tools }}\\n{{- . }}\\n{{ end }}\\n{{ .Content }}\\u003c|eot_id|\\u003e\\n{{-
-        else }}\\n\\n{{ .Content }}\\u003c|eot_id|\\u003e\\n{{- end }}{{ if $last
-        }}\\u003c|start_header_id|\\u003eassistant\\u003c|end_header_id|\\u003e\\n\\n{{
-        end }}\\n{{- else if eq .Role \\\"assistant\\\" }}\\u003c|start_header_id|\\u003eassistant\\u003c|end_header_id|\\u003e\\n{{-
-        if .ToolCalls }}\\n{{ range .ToolCalls }}\\n{\\\"name\\\": \\\"{{ .Function.Name
-        }}\\\", \\\"parameters\\\": {{ .Function.Arguments }}}{{ end }}\\n{{- else
-        }}\\n\\n{{ .Content }}\\n{{- end }}{{ if not $last }}\\u003c|eot_id|\\u003e{{
-        end }}\\n{{- else if eq .Role \\\"tool\\\" }}\\u003c|start_header_id|\\u003eipython\\u003c|end_header_id|\\u003e\\n\\n{{
-        .Content }}\\u003c|eot_id|\\u003e{{ if $last }}\\u003c|start_header_id|\\u003eassistant\\u003c|end_header_id|\\u003e\\n\\n{{
-        end }}\\n{{- end }}\\n{{- end }}\\\"\\\"\\\"\\nPARAMETER stop \\u003c|start_header_id|\\u003e\\nPARAMETER
-        stop \\u003c|end_header_id|\\u003e\\nPARAMETER stop \\u003c|eot_id|\\u003e\\nLICENSE
-        \\\"LLAMA 3.2 COMMUNITY LICENSE AGREEMENT\\nLlama 3.2 Version Release Date:
-        September 25, 2024\\n\\n\u201CAgreement\u201D means the terms and conditions
-        for use, reproduction, distribution \\nand modification of the Llama Materials
-        set forth herein.\\n\\n\u201CDocumentation\u201D means the specifications,
-        manuals and documentation accompanying Llama 3.2\\ndistributed by Meta at
-        https://llama.meta.com/doc/overview.\\n\\n\u201CLicensee\u201D or \u201Cyou\u201D
-        means you, or your employer or any other person or entity (if you are \\nentering
-        into this Agreement on such person or entity\u2019s behalf), of the age required
-        under\\napplicable laws, rules or regulations to provide legal consent and
-        that has legal authority\\nto bind your employer or such other person or entity
-        if you are entering in this Agreement\\non their behalf.\\n\\n\u201CLlama
-        3.2\u201D means the foundational large language models and software and algorithms,
-        including\\nmachine-learning model code, trained model weights, inference-enabling
-        code, training-enabling code,\\nfine-tuning enabling code and other elements
-        of the foregoing distributed by Meta at \\nhttps://www.llama.com/llama-downloads.\\n\\n\u201CLlama
-        Materials\u201D means, collectively, Meta\u2019s proprietary Llama 3.2 and
-        Documentation (and \\nany portion thereof) made available under this Agreement.\\n\\n\u201CMeta\u201D
-        or \u201Cwe\u201D means Meta Platforms Ireland Limited (if you are located
-        in or, \\nif you are an entity, your principal place of business is in the
-        EEA or Switzerland) \\nand Meta Platforms, Inc. (if you are located outside
-        of the EEA or Switzerland). \\n\\n\\nBy clicking \u201CI Accept\u201D below
-        or by using or distributing any portion or element of the Llama Materials,\\nyou
-        agree to be bound by this Agreement.\\n\\n\\n1. License Rights and Redistribution.\\n\\n
-        \   a. Grant of Rights. You are granted a non-exclusive, worldwide, \\nnon-transferable
-        and royalty-free limited license under Meta\u2019s intellectual property or
-        other rights \\nowned by Meta embodied in the Llama Materials to use, reproduce,
-        distribute, copy, create derivative works \\nof, and make modifications to
-        the Llama Materials.  \\n\\n    b. Redistribution and Use.  \\n\\n        i.
-        If you distribute or make available the Llama Materials (or any derivative
-        works thereof), \\nor a product or service (including another AI model) that
-        contains any of them, you shall (A) provide\\na copy of this Agreement with
-        any such Llama Materials; and (B) prominently display \u201CBuilt with Llama\u201D\\non
-        a related website, user interface, blogpost, about page, or product documentation.
-        If you use the\\nLlama Materials or any outputs or results of the Llama Materials
-        to create, train, fine tune, or\\notherwise improve an AI model, which is
-        distributed or made available, you shall also include \u201CLlama\u201D\\nat
-        the beginning of any such AI model name.\\n\\n        ii. If you receive Llama
-        Materials, or any derivative works thereof, from a Licensee as part\\nof an
-        integrated end user product, then Section 2 of this Agreement will not apply
-        to you. \\n\\n        iii. You must retain in all copies of the Llama Materials
-        that you distribute the \\nfollowing attribution notice within a \u201CNotice\u201D
-        text file distributed as a part of such copies: \\n\u201CLlama 3.2 is licensed
-        under the Llama 3.2 Community License, Copyright \xA9 Meta Platforms,\\nInc.
-        All Rights Reserved.\u201D\\n\\n        iv. Your use of the Llama Materials
-        must comply with applicable laws and regulations\\n(including trade compliance
-        laws and regulations) and adhere to the Acceptable Use Policy for\\nthe Llama
-        Materials (available at https://www.llama.com/llama3_2/use-policy), which
-        is hereby \\nincorporated by reference into this Agreement.\\n  \\n2. Additional
-        Commercial Terms. If, on the Llama 3.2 version release date, the monthly active
-        users\\nof the products or services made available by or for Licensee, or
-        Licensee\u2019s affiliates, \\nis greater than 700 million monthly active
-        users in the preceding calendar month, you must request \\na license from
-        Meta, which Meta may grant to you in its sole discretion, and you are not
-        authorized to\\nexercise any of the rights under this Agreement unless or
-        until Meta otherwise expressly grants you such rights.\\n\\n3. Disclaimer
-        of Warranty. UNLESS REQUIRED BY APPLICABLE LAW, THE LLAMA MATERIALS AND ANY
-        OUTPUT AND \\nRESULTS THEREFROM ARE PROVIDED ON AN \u201CAS IS\u201D BASIS,
-        WITHOUT WARRANTIES OF ANY KIND, AND META DISCLAIMS\\nALL WARRANTIES OF ANY
-        KIND, BOTH EXPRESS AND IMPLIED, INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES\\nOF
-        TITLE, NON-INFRINGEMENT, MERCHANTABILITY, OR FITNESS FOR A PARTICULAR PURPOSE.
-        YOU ARE SOLELY RESPONSIBLE\\nFOR DETERMINING THE APPROPRIATENESS OF USING
-        OR REDISTRIBUTING THE LLAMA MATERIALS AND ASSUME ANY RISKS ASSOCIATED\\nWITH
-        YOUR USE OF THE LLAMA MATERIALS AND ANY OUTPUT AND RESULTS.\\n\\n4. Limitation
-        of Liability. IN NO EVENT WILL META OR ITS AFFILIATES BE LIABLE UNDER ANY
-        THEORY OF LIABILITY, \\nWHETHER IN CONTRACT, TORT, NEGLIGENCE, PRODUCTS LIABILITY,
-        OR OTHERWISE, ARISING OUT OF THIS AGREEMENT, \\nFOR ANY LOST PROFITS OR ANY
-        INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL, EXEMPLARY OR PUNITIVE DAMAGES,
-        EVEN \\nIF META OR ITS AFFILIATES HAVE BEEN ADVISED OF THE POSSIBILITY OF
-        ANY OF THE FOREGOING.\\n\\n5. Intellectual Property.\\n\\n    a. No trademark
-        licenses are granted under this Agreement, and in connection with the Llama
-        Materials, \\nneither Meta nor Licensee may use any name or mark owned by
-        or associated with the other or any of its affiliates, \\nexcept as required
-        for reasonable and customary use in describing and redistributing the Llama
-        Materials or as \\nset forth in this Section 5(a). Meta hereby grants you
-        a license to use \u201CLlama\u201D (the \u201CMark\u201D) solely as required
-        \\nto comply with the last sentence of Section 1.b.i. You will comply with
-        Meta\u2019s brand guidelines (currently accessible \\nat https://about.meta.com/brand/resources/meta/company-brand/).
-        All goodwill arising out of your use of the Mark \\nwill inure to the benefit
-        of Meta.\\n\\n    b. Subject to Meta\u2019s ownership of Llama Materials and
-        derivatives made by or for Meta, with respect to any\\n    derivative works
-        and modifications of the Llama Materials that are made by you, as between
-        you and Meta,\\n    you are and will be the owner of such derivative works
-        and modifications.\\n\\n    c. If you institute litigation or other proceedings
-        against Meta or any entity (including a cross-claim or\\n    counterclaim
-        in a lawsuit) alleging that the Llama Materials or Llama 3.2 outputs or results,
-        or any portion\\n    of any of the foregoing, constitutes infringement of
-        intellectual property or other rights owned or licensable\\n    by you, then
-        any licenses granted to you under this Agreement shall terminate as of the
-        date such litigation or\\n    claim is filed or instituted. You will indemnify
-        and hold harmless Meta from and against any claim by any third\\n    party
-        arising out of or related to your use or distribution of the Llama Materials.\\n\\n6.
-        Term and Termination. The term of this Agreement will commence upon your acceptance
-        of this Agreement or access\\nto the Llama Materials and will continue in
-        full force and effect until terminated in accordance with the terms\\nand
-        conditions herein. Meta may terminate this Agreement if you are in breach
-        of any term or condition of this\\nAgreement. Upon termination of this Agreement,
-        you shall delete and cease use of the Llama Materials. Sections 3,\\n4 and
-        7 shall survive the termination of this Agreement. \\n\\n7. Governing Law
-        and Jurisdiction. This Agreement will be governed and construed under the
-        laws of the State of \\nCalifornia without regard to choice of law principles,
-        and the UN Convention on Contracts for the International\\nSale of Goods does
-        not apply to this Agreement. The courts of California shall have exclusive
-        jurisdiction of\\nany dispute arising out of this Agreement.\\\"\\nLICENSE
-        \\\"**Llama 3.2** **Acceptable Use Policy**\\n\\nMeta is committed to promoting
-        safe and fair use of its tools and features, including Llama 3.2. If you access
-        or use Llama 3.2, you agree to this Acceptable Use Policy (\u201C**Policy**\u201D).
-        The most recent copy of this policy can be found at [https://www.llama.com/llama3_2/use-policy](https://www.llama.com/llama3_2/use-policy).\\n\\n**Prohibited
-        Uses**\\n\\nWe want everyone to use Llama 3.2 safely and responsibly. You
-        agree you will not use, or allow others to use, Llama 3.2 to:\\n\\n\\n\\n1.
-        Violate the law or others\u2019 rights, including to:\\n    1. Engage in,
-        promote, generate, contribute to, encourage, plan, incite, or further illegal
-        or unlawful activity or content, such as:\\n        1. Violence or terrorism\\n
-        \       2. Exploitation or harm to children, including the solicitation, creation,
-        acquisition, or dissemination of child exploitative content or failure to
-        report Child Sexual Abuse Material\\n        3. Human trafficking, exploitation,
-        and sexual violence\\n        4. The illegal distribution of information or
-        materials to minors, including obscene materials, or failure to employ legally
-        required age-gating in connection with such information or materials.\\n        5.
-        Sexual solicitation\\n        6. Any other criminal activity\\n    1. Engage
-        in, promote, incite, or facilitate the harassment, abuse, threatening, or
-        bullying of individuals or groups of individuals\\n    2. Engage in, promote,
-        incite, or facilitate discrimination or other unlawful or harmful conduct
-        in the provision of employment, employment benefits, credit, housing, other
-        economic benefits, or other essential goods and services\\n    3. Engage in
-        the unauthorized or unlicensed practice of any profession including, but not
-        limited to, financial, legal, medical/health, or related professional practices\\n
-        \   4. Collect, process, disclose, generate, or infer private or sensitive
-        information about individuals, including information about individuals\u2019
-        identity, health, or demographic information, unless you have obtained the
-        right to do so in accordance with applicable law\\n    5. Engage in or facilitate
-        any action or generate any content that infringes, misappropriates, or otherwise
-        violates any third-party rights, including the outputs or results of any products
-        or services using the Llama Materials\\n    6. Create, generate, or facilitate
-        the creation of malicious code, malware, computer viruses or do anything else
-        that could disable, overburden, interfere with or impair the proper working,
-        integrity, operation or appearance of a website or computer system\\n    7.
-        Engage in any action, or facilitate any action, to intentionally circumvent
-        or remove usage restrictions or other safety measures, or to enable functionality
-        disabled by Meta\\n2. Engage in, promote, incite, facilitate, or assist in
-        the planning or development of activities that present a risk of death or
-        bodily harm to individuals, including use of Llama 3.2 related to the following:\\n
-        \   8. Military, warfare, nuclear industries or applications, espionage, use
-        for materials or activities that are subject to the International Traffic
-        Arms Regulations (ITAR) maintained by the United States Department of State
-        or to the U.S. Biological Weapons Anti-Terrorism Act of 1989 or the Chemical
-        Weapons Convention Implementation Act of 1997\\n    9. Guns and illegal weapons
-        (including weapon development)\\n    10. Illegal drugs and regulated/controlled
-        substances\\n    11. Operation of critical infrastructure, transportation
-        technologies, or heavy machinery\\n    12. Self-harm or harm to others, including
-        suicide, cutting, and eating disorders\\n    13. Any content intended to incite
-        or promote violence, abuse, or any infliction of bodily harm to an individual\\n3.
-        Intentionally deceive or mislead others, including use of Llama 3.2 related
-        to the following:\\n    14. Generating, promoting, or furthering fraud or
-        the creation or promotion of disinformation\\n    15. Generating, promoting,
-        or furthering defamatory content, including the creation of defamatory statements,
-        images, or other content\\n    16. Generating, promoting, or further distributing
-        spam\\n    17. Impersonating another individual without consent, authorization,
-        or legal right\\n    18. Representing that the use of Llama 3.2 or outputs
-        are human-generated\\n    19. Generating or facilitating false online engagement,
-        including fake reviews and other means of fake online engagement\\n4. Fail
-        to appropriately disclose to end users any known dangers of your AI system\\n5.
-        Interact with third party tools, models, or software designed to generate
-        unlawful content or engage in unlawful or harmful conduct and/or represent
-        that the outputs of such tools, models, or software are associated with Meta
-        or Llama 3.2\\n\\nWith respect to any multimodal models included in Llama
-        3.2, the rights granted under Section 1(a) of the Llama 3.2 Community License
-        Agreement are not being granted to you if you are an individual domiciled
-        in, or a company with a principal place of business in, the European Union.
-        This restriction does not apply to end users of a product or service that
-        incorporates any such multimodal models.\\n\\nPlease report any violation
-        of this Policy, software \u201Cbug,\u201D or other problems that could lead
-        to a violation of this Policy through one of the following means:\\n\\n\\n\\n*
-        Reporting issues with the model: [https://github.com/meta-llama/llama-models/issues](https://l.workplace.com/l.php?u=https%3A%2F%2Fgithub.com%2Fmeta-llama%2Fllama-models%2Fissues\\u0026h=AT0qV8W9BFT6NwihiOHRuKYQM_UnkzN_NmHMy91OT55gkLpgi4kQupHUl0ssR4dQsIQ8n3tfd0vtkobvsEvt1l4Ic6GXI2EeuHV8N08OG2WnbAmm0FL4ObkazC6G_256vN0lN9DsykCvCqGZ)\\n*
-        Reporting risky content generated by the model: [developers.facebook.com/llama_output_feedback](http://developers.facebook.com/llama_output_feedback)\\n*
-        Reporting bugs and security concerns: [facebook.com/whitehat/info](http://facebook.com/whitehat/info)\\n*
-        Reporting violations of the Acceptable Use Policy or unlicensed uses of Llama
-        3.2: LlamaUseReport@meta.com\\\"\\n\",\"parameters\":\"stop                           \\\"\\u003c|start_header_id|\\u003e\\\"\\nstop
-        \                          \\\"\\u003c|end_header_id|\\u003e\\\"\\nstop                           \\\"\\u003c|eot_id|\\u003e\\\"\",\"template\":\"\\u003c|start_header_id|\\u003esystem\\u003c|end_header_id|\\u003e\\n\\nCutting
-        Knowledge Date: December 2023\\n\\n{{ if .System }}{{ .System }}\\n{{- end
-        }}\\n{{- if .Tools }}When you receive a tool call response, use the output
-        to format an answer to the orginal user question.\\n\\nYou are a helpful assistant
-        with tool calling capabilities.\\n{{- end }}\\u003c|eot_id|\\u003e\\n{{- range
-        $i, $_ := .Messages }}\\n{{- $last := eq (len (slice $.Messages $i)) 1 }}\\n{{-
-        if eq .Role \\\"user\\\" }}\\u003c|start_header_id|\\u003euser\\u003c|end_header_id|\\u003e\\n{{-
-        if and $.Tools $last }}\\n\\nGiven the following functions, please respond
-        with a JSON for a function call with its proper arguments that best answers
-        the given prompt.\\n\\nRespond in the format {\\\"name\\\": function name,
-        \\\"parameters\\\": dictionary of argument name and its value}. Do not use
-        variables.\\n\\n{{ range $.Tools }}\\n{{- . }}\\n{{ end }}\\n{{ .Content }}\\u003c|eot_id|\\u003e\\n{{-
-        else }}\\n\\n{{ .Content }}\\u003c|eot_id|\\u003e\\n{{- end }}{{ if $last
-        }}\\u003c|start_header_id|\\u003eassistant\\u003c|end_header_id|\\u003e\\n\\n{{
-        end }}\\n{{- else if eq .Role \\\"assistant\\\" }}\\u003c|start_header_id|\\u003eassistant\\u003c|end_header_id|\\u003e\\n{{-
-        if .ToolCalls }}\\n{{ range .ToolCalls }}\\n{\\\"name\\\": \\\"{{ .Function.Name
-        }}\\\", \\\"parameters\\\": {{ .Function.Arguments }}}{{ end }}\\n{{- else
-        }}\\n\\n{{ .Content }}\\n{{- end }}{{ if not $last }}\\u003c|eot_id|\\u003e{{
-        end }}\\n{{- else if eq .Role \\\"tool\\\" }}\\u003c|start_header_id|\\u003eipython\\u003c|end_header_id|\\u003e\\n\\n{{
-        .Content }}\\u003c|eot_id|\\u003e{{ if $last }}\\u003c|start_header_id|\\u003eassistant\\u003c|end_header_id|\\u003e\\n\\n{{
-        end }}\\n{{- end }}\\n{{- end }}\",\"details\":{\"parent_model\":\"\",\"format\":\"gguf\",\"family\":\"llama\",\"families\":[\"llama\"],\"parameter_size\":\"3.2B\",\"quantization_level\":\"Q4_K_M\"},\"model_info\":{\"general.architecture\":\"llama\",\"general.basename\":\"Llama-3.2\",\"general.file_type\":15,\"general.finetune\":\"Instruct\",\"general.languages\":[\"en\",\"de\",\"fr\",\"it\",\"pt\",\"hi\",\"es\",\"th\"],\"general.parameter_count\":3212749888,\"general.quantization_version\":2,\"general.size_label\":\"3B\",\"general.tags\":[\"facebook\",\"meta\",\"pytorch\",\"llama\",\"llama-3\",\"text-generation\"],\"general.type\":\"model\",\"llama.attention.head_count\":24,\"llama.attention.head_count_kv\":8,\"llama.attention.key_length\":128,\"llama.attention.layer_norm_rms_epsilon\":0.00001,\"llama.attention.value_length\":128,\"llama.block_count\":28,\"llama.context_length\":131072,\"llama.embedding_length\":3072,\"llama.feed_forward_length\":8192,\"llama.rope.dimension_count\":128,\"llama.rope.freq_base\":500000,\"llama.vocab_size\":128256,\"tokenizer.ggml.bos_token_id\":128000,\"tokenizer.ggml.eos_token_id\":128009,\"tokenizer.ggml.merges\":null,\"tokenizer.ggml.model\":\"gpt2\",\"tokenizer.ggml.pre\":\"llama-bpe\",\"tokenizer.ggml.token_type\":null,\"tokenizer.ggml.tokens\":null},\"tensors\":[{\"name\":\"rope_freqs.weight\",\"type\":\"F32\",\"shape\":[64]},{\"name\":\"token_embd.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,128256]},{\"name\":\"blk.0.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.0.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.0.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.0.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.0.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.0.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.0.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.0.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.0.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.1.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.1.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.1.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.1.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.1.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.1.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.1.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.1.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.1.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.10.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.10.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.10.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.10.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.10.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.10.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.10.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.10.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.10.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.11.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.11.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.11.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.11.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.11.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.11.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.11.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.11.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.11.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.12.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.12.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.12.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.12.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.12.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.12.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.12.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.12.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.12.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.13.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.13.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.13.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.13.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.13.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.13.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.13.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.13.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.13.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.14.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.14.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.14.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.14.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.14.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.14.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.14.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.14.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.14.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.15.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.15.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.15.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.15.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.15.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.15.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.15.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.15.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.15.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.16.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.16.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.16.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.16.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.16.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.16.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.16.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.16.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.16.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.17.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.17.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.17.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.17.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.17.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.17.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.17.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.17.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.17.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.18.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.18.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.18.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.18.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.18.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.18.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.18.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.18.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.18.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.19.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.19.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.19.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.19.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.19.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.19.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.19.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.19.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.19.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.2.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.2.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.2.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.2.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.2.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.2.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.2.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.2.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.2.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.20.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.20.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.20.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.20.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.20.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.20.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.3.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.3.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.3.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.3.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.3.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.3.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.3.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.3.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.3.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.4.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.4.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.4.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.4.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.4.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.4.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.4.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.4.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.4.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.5.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.5.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.5.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.5.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.5.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.5.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.5.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.5.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.5.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.6.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.6.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.6.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.6.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.6.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.6.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.6.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.6.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.6.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.7.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.7.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.7.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.7.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.7.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.7.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.7.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.7.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.7.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.8.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.8.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.8.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.8.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.8.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.8.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.8.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.8.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.8.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.9.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.9.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.9.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.9.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.9.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.9.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.9.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.9.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.9.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.20.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.20.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.20.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.21.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.21.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.21.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.21.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.21.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.21.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.21.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.21.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.21.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.22.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.22.ffn_down.weight\",\"type\":\"Q3_K_M\",\"shape\":[8192,3072]},{\"name\":\"blk.22.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.22.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.22.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.22.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.22.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.22.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.22.attn_v.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.23.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.23.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.23.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.23.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.23.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.23.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.23.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.23.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.23.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.24.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.24.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.24.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.24.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.24.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.24.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.24.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.24.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.24.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.25.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.25.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.25.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.25.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.25.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.25.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.25.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.25.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.25.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.26.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.26.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.26.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.26.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.26.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.26.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.26.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.26.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.26.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"blk.27.attn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.27.ffn_down.weight\",\"type\":\"Q4_K_S\",\"shape\":[8192,3072]},{\"name\":\"blk.27.ffn_gate.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.27.ffn_up.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,8192]},{\"name\":\"blk.27.ffn_norm.weight\",\"type\":\"F32\",\"shape\":[3072]},{\"name\":\"blk.27.attn_k.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,1024]},{\"name\":\"blk.27.attn_output.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.27.attn_q.weight\",\"type\":\"Q3_K_M\",\"shape\":[3072,3072]},{\"name\":\"blk.27.attn_v.weight\",\"type\":\"Q4_K_S\",\"shape\":[3072,1024]},{\"name\":\"output_norm.weight\",\"type\":\"F32\",\"shape\":[3072]}],\"capabilities\":[\"completion\",\"tools\"],\"modified_at\":\"2025-05-07T01:18:18.293364002Z\"}"
-    headers:
-      Content-Type:
-      - application/json; charset=utf-8
-      Date:
-      - Wed, 07 May 2025 01:18:39 GMT
-      Transfer-Encoding:
-      - chunked
+      - req_3b02f6f421da97eaa6d99999c3ca29cc
     status:
       code: 200
       message: OK
diff --git a/lib/crewai/tests/utilities/test_converter.py b/lib/crewai/tests/utilities/test_converter.py
--- a/lib/crewai/tests/utilities/test_converter.py
+++ b/lib/crewai/tests/utilities/test_converter.py
@@ -231,7 +231,7 @@ def test_get_conversion_instructions_gpt() -> None:
         expected_instructions = (
             "Please convert the following text into valid JSON.\n\n"
             "Output ONLY the valid JSON and nothing else.\n\n"
-            "The JSON must follow this schema exactly:\n```json\n"
+            "Use this format exactly:\n```json\n"
             f"{model_schema}\n```"
         )
         assert instructions == expected_instructions
@@ -241,8 +241,14 @@ def test_get_conversion_instructions_non_gpt() -> None:
     llm = LLM(model="ollama/llama3.1", base_url="http://localhost:11434")
     with patch.object(LLM, "supports_function_calling", return_value=False):
         instructions = get_conversion_instructions(SimpleModel, llm)
-        assert '"name": str' in instructions
-        assert '"age": int' in instructions
+        # Check that the JSON schema is properly formatted
+        assert "Please convert the following text into valid JSON" in instructions
+        assert "Output ONLY the valid JSON and nothing else" in instructions
+        assert "Use this format exactly" in instructions
+        assert "```json" in instructions
+        assert '"type": "object"' in instructions
+        assert '"properties"' in instructions
+        assert "'type': 'json_schema'" not in instructions
 
 
 # Tests for is_gpt
@@ -295,16 +301,24 @@ def test_create_converter_fails_without_agent_or_converter_cls() -> None:
 
 def test_generate_model_description_simple_model() -> None:
     description = generate_model_description(SimpleModel)
-    expected_description = '{\n  "name": str,\n  "age": int\n}'
-    assert description == expected_description
+    # generate_model_description now returns a JSON schema dict
+    assert isinstance(description, dict)
+    assert description["type"] == "json_schema"
+    assert description["json_schema"]["name"] == "SimpleModel"
+    assert description["json_schema"]["strict"] is True
+    assert "name" in description["json_schema"]["schema"]["properties"]
+    assert "age" in description["json_schema"]["schema"]["properties"]
 
 
 def test_generate_model_description_nested_model() -> None:
     description = generate_model_description(NestedModel)
-    expected_description = (
-        '{\n  "id": int,\n  "data": {\n  "name": str,\n  "age": int\n}\n}'
-    )
-    assert description == expected_description
+    # generate_model_description now returns a JSON schema dict
+    assert isinstance(description, dict)
+    assert description["type"] == "json_schema"
+    assert description["json_schema"]["name"] == "NestedModel"
+    assert description["json_schema"]["strict"] is True
+    assert "id" in description["json_schema"]["schema"]["properties"]
+    assert "data" in description["json_schema"]["schema"]["properties"]
 
 
 def test_generate_model_description_optional_field() -> None:
@@ -313,26 +327,35 @@ class ModelWithOptionalField(BaseModel):
         age: int | None
 
     description = generate_model_description(ModelWithOptionalField)
-    expected_description = '{\n  "name": str,\n  "age": int | None\n}'
-    assert description == expected_description
+    # generate_model_description now returns a JSON schema dict
+    assert isinstance(description, dict)
+    assert description["type"] == "json_schema"
+    assert description["json_schema"]["name"] == "ModelWithOptionalField"
+    assert description["json_schema"]["strict"] is True
 
 
 def test_generate_model_description_list_field() -> None:
     class ModelWithListField(BaseModel):
         items: list[int]
 
     description = generate_model_description(ModelWithListField)
-    expected_description = '{\n  "items": List[int]\n}'
-    assert description == expected_description
+    # generate_model_description now returns a JSON schema dict
+    assert isinstance(description, dict)
+    assert description["type"] == "json_schema"
+    assert description["json_schema"]["name"] == "ModelWithListField"
+    assert description["json_schema"]["strict"] is True
 
 
 def test_generate_model_description_dict_field() -> None:
     class ModelWithDictField(BaseModel):
         attributes: dict[str, int]
 
     description = generate_model_description(ModelWithDictField)
-    expected_description = '{\n  "attributes": Dict[str, int]\n}'
-    assert description == expected_description
+    # generate_model_description now returns a JSON schema dict
+    assert isinstance(description, dict)
+    assert description["type"] == "json_schema"
+    assert description["json_schema"]["name"] == "ModelWithDictField"
+    assert description["json_schema"]["strict"] is True
 
 
 @pytest.mark.vcr(filter_headers=["authorization"])
@@ -374,9 +397,11 @@ def test_converter_with_llama3_2_model() -> None:
     assert output.age == 30
 
 
-@pytest.mark.vcr(filter_headers=["authorization"])
 def test_converter_with_llama3_1_model() -> None:
-    llm = LLM(model="ollama/llama3.1", base_url="http://localhost:11434")
+    llm = Mock(spec=LLM)
+    llm.supports_function_calling.return_value = True
+    llm.call.return_value = '{"name": "Alice Llama", "age": 30}'
+
     sample_text = "Name: Alice Llama, Age: 30"
     instructions = get_conversion_instructions(SimpleModel, llm)
     converter = Converter(
@@ -570,33 +595,38 @@ def test_converter_with_ambiguous_input() -> None:
 def test_converter_with_function_calling() -> None:
     llm = Mock(spec=LLM)
     llm.supports_function_calling.return_value = True
-
-    instructor = Mock()
-    instructor.to_pydantic.return_value = SimpleModel(name="Eve", age=35)
+    # Mock the llm.call to return a valid JSON string
+    llm.call.return_value = '{"name": "Eve", "age": 35}'
 
     converter = Converter(
         llm=llm,
         text="Name: Eve, Age: 35",
         model=SimpleModel,
         instructions="Convert this text.",
     )
-    
-    with patch.object(converter, '_create_instructor', return_value=instructor):
-        output = converter.to_pydantic()
 
-        assert isinstance(output, SimpleModel)
-        assert output.name == "Eve"
-        assert output.age == 35
-    instructor.to_pydantic.assert_called_once()
+    output = converter.to_pydantic()
+
+    assert isinstance(output, SimpleModel)
+    assert output.name == "Eve"
+    assert output.age == 35
+
+    # Verify llm.call was called with correct parameters
+    llm.call.assert_called_once()
+    call_args = llm.call.call_args
+    assert call_args[1]["response_model"] == SimpleModel
 
 
 def test_generate_model_description_union_field() -> None:
     class UnionModel(BaseModel):
         field: int | str | None
 
     description = generate_model_description(UnionModel)
-    expected_description = '{\n  "field": int | str | None\n}'
-    assert description == expected_description
+    # generate_model_description now returns a JSON schema dict
+    assert isinstance(description, dict)
+    assert description["type"] == "json_schema"
+    assert description["json_schema"]["name"] == "UnionModel"
+    assert description["json_schema"]["strict"] is True
 
 def test_internal_instructor_with_openai_provider() -> None:
     """Test InternalInstructor with OpenAI provider using registry pattern."""
EOF_114329324912

# Set environment variables to ensure proper test execution
export OTEL_SDK_DISABLED=true
export PYTHONUNBUFFERED=1
export CREWAI_DISABLE_TELEMETRY=true
export CREWAI_TESTING=true
export OPENAI_API_KEY=fake-api-key
export BRAVE_API_KEY=fake-brave-key
export SNOWFLAKE_USER=fake-snowflake-user
export SNOWFLAKE_PASSWORD=fake-snowflake-password
export SNOWFLAKE_ACCOUNT=fake-snowflake-account
export SNOWFLAKE_WAREHOUSE=fake-snowflake-warehouse
export SNOWFLAKE_DATABASE=fake-snowflake-database
export SNOWFLAKE_SCHEMA=fake-snowflake-schema
export EMBEDCHAIN_DB_URI=sqlite:///test.db

# Change to the crewai package directory
cd /testbed/lib/crewai

# Run the target test files using uv
# Using single-process mode for safety in virtualized environment
# --block-network ensures no external network calls
# --timeout=30 sets 30 second timeout per test
# -vv for verbose output
# --durations=10 shows slowest 10 tests
# --maxfail=3 stops after 3 failures
uv run pytest --no-header -rA --tb=short -p no:cacheprovider \
    --block-network --timeout=30 -vv --durations=10 --maxfail=3 \
    tests/agents/agent_adapters/test_base_agent_adapter.py \
    tests/agents/test_agent.py \
    tests/agents/test_lite_agent.py \
    tests/cli/test_token_manager.py \
    tests/conftest.py \
    tests/llms/openai/test_openai.py \
    tests/test_crew.py \
    tests/test_custom_llm.py \
    tests/test_task.py \
    tests/tracing/test_tracing.py \
    tests/utilities/test_converter.py

# Capture exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
cd /testbed
git checkout e229ef4e1995221873a46ab7adb2e052923579a1 \
    "lib/crewai/tests/agents/agent_adapters/test_base_agent_adapter.py" \
    "lib/crewai/tests/agents/test_agent.py" \
    "lib/crewai/tests/agents/test_lite_agent.py" \
    "lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[save].yaml" \
    "lib/crewai/tests/cassettes/test_crew_external_memory_save_with_memory_flag[search].yaml" \
    "lib/crewai/tests/cassettes/test_crew_train_success.yaml" \
    "lib/crewai/tests/cassettes/test_json_property_without_output_json.yaml" \
    "lib/crewai/tests/cassettes/test_long_term_memory_with_memory_flag.yaml" \
    "lib/crewai/tests/cassettes/test_memory_events_are_emitted.yaml" \
    "lib/crewai/tests/cassettes/test_output_pydantic_hierarchical.yaml" \
    "lib/crewai/tests/cassettes/test_output_pydantic_sequential.yaml" \
    "lib/crewai/tests/cassettes/test_output_pydantic_to_another_task.yaml" \
    "lib/crewai/tests/cassettes/test_save_task_pydantic_output.yaml" \
    "lib/crewai/tests/cassettes/test_using_contextual_memory.yaml" \
    "lib/crewai/tests/cli/test_token_manager.py" \
    "lib/crewai/tests/conftest.py" \
    "lib/crewai/tests/llms/openai/test_openai.py" \
    "lib/crewai/tests/test_crew.py" \
    "lib/crewai/tests/test_custom_llm.py" \
    "lib/crewai/tests/test_task.py" \
    "lib/crewai/tests/tracing/test_tracing.py" \
    "lib/crewai/tests/utilities/cassettes/test_convert_with_instructions.yaml" \
    "lib/crewai/tests/utilities/cassettes/test_converter_with_nested_model.yaml" \
    "lib/crewai/tests/utilities/test_converter.py"