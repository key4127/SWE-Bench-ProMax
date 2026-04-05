#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout bee41c19610cd35c5663e176e0fe1459e6bd80f3 "tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py b/tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py
--- a/tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py
+++ b/tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py
@@ -163,18 +163,17 @@ def test_add_reasoning_system_prompt_with_existing_list_content(self):
         
         result = mistral_config._add_reasoning_system_prompt_if_needed(messages, optional_params)
         
-        # Should modify existing system message with list content
+        # Should modify existing system message with list content converted to string
         assert len(result) == 2
         assert result[0]["role"] == "system"
-        assert isinstance(result[0]["content"], list)
+        assert isinstance(result[0]["content"], str)
         
-        # First item should be the reasoning prompt
-        assert result[0]["content"][0]["type"] == "text"
-        assert "<think>" in result[0]["content"][0]["text"]
+        # Should contain the reasoning prompt
+        assert "<think>" in result[0]["content"]
         
-        # Original content should be preserved
-        assert "You are a helpful assistant." in result[0]["content"][1]["text"]
-        assert "You always provide detailed explanations." in result[0]["content"][2]["text"]
+        # Original content should be preserved (converted from list to string)
+        assert "You are a helpful assistant." in result[0]["content"]
+        assert "You always provide detailed explanations." in result[0]["content"]
         
         assert result[1]["role"] == "user"
         
EOF_114329324912

# Ensure PYTHONPATH is set correctly
export PYTHONPATH=/testbed:$PYTHONPATH

# Run the target test file with pytest
# Using -xvs flags as specified in the context retrieval information
# -x: stop on first failure
# -v: verbose output
# -s: no capture (show print statements)
pytest -xvs tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py

# Capture exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file to clean state
git checkout bee41c19610cd35c5663e176e0fe1459e6bd80f3 "tests/test_litellm/llms/mistral/test_mistral_chat_transformation.py"

# Exit with the captured return code
exit $rc