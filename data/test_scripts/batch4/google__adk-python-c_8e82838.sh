#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 7edd7ea9b77fa19433f1e04a7eefccb47ab08b02 "tests/unittests/models/test_anthropic_llm.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/models/test_anthropic_llm.py b/tests/unittests/models/test_anthropic_llm.py
--- a/tests/unittests/models/test_anthropic_llm.py
+++ b/tests/unittests/models/test_anthropic_llm.py
@@ -19,6 +19,7 @@
 from anthropic import types as anthropic_types
 from google.adk import version as adk_version
 from google.adk.models import anthropic_llm
+from google.adk.models.anthropic_llm import AnthropicLlm
 from google.adk.models.anthropic_llm import Claude
 from google.adk.models.anthropic_llm import content_to_message_param
 from google.adk.models.anthropic_llm import function_declaration_to_tool_param
@@ -359,6 +360,37 @@ async def mock_coro():
       assert responses[0].content.parts[0].text == "Hello, how can I help you?"
 
 
+@pytest.mark.asyncio
+async def test_anthropic_llm_generate_content_async(
+    llm_request, generate_content_response, generate_llm_response
+):
+  anthropic_llm_instance = AnthropicLlm(model="claude-sonnet-4-20250514")
+  with mock.patch.object(
+      anthropic_llm_instance, "_anthropic_client"
+  ) as mock_client:
+    with mock.patch.object(
+        anthropic_llm,
+        "message_to_generate_content_response",
+        return_value=generate_llm_response,
+    ):
+      # Create a mock coroutine that returns the generate_content_response.
+      async def mock_coro():
+        return generate_content_response
+
+      # Assign the coroutine to the mocked method
+      mock_client.messages.create.return_value = mock_coro()
+
+      responses = [
+          resp
+          async for resp in anthropic_llm_instance.generate_content_async(
+              llm_request, stream=False
+          )
+      ]
+      assert len(responses) == 1
+      assert isinstance(responses[0], LlmResponse)
+      assert responses[0].content.parts[0].text == "Hello, how can I help you?"
+
+
 @pytest.mark.asyncio
 async def test_generate_content_async_with_max_tokens(
     llm_request, generate_content_response, generate_llm_response
EOF_114329324912

# Execute the target test file using pytest
# Running in single-process mode for safety in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/unittests/models/test_anthropic_llm.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 7edd7ea9b77fa19433f1e04a7eefccb47ab08b02 "tests/unittests/models/test_anthropic_llm.py"