#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 320ca3d407a00e14cef31f4dc8943c25ebc0527c "tests/clients/test_lm.py" "tests/reliability/conftest.py" "tests/reliability/reliability_conf.yaml" "tests/reliability/test_pydantic_models.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/adapters/test_two_step_adapter.py b/tests/adapters/test_two_step_adapter.py
new file mode 100644
--- /dev/null
+++ b/tests/adapters/test_two_step_adapter.py
@@ -0,0 +1,113 @@
+from unittest import mock
+import pytest
+
+import dspy
+
+
+def test_two_step_adapter_call():
+    class TestSignature(dspy.Signature):
+        question: str = dspy.InputField(desc="The math question to solve")
+        solution: str = dspy.OutputField(desc="Step by step solution")
+        answer: float = dspy.OutputField(desc="The final numerical answer")
+    
+    program = dspy.Predict(TestSignature)
+
+    mock_main_lm = mock.MagicMock(spec=dspy.LM)
+    mock_main_lm.return_value = ["text from main LM"]
+    mock_main_lm.kwargs = {"temperature": 1.0}
+
+    mock_extraction_lm = mock.MagicMock(spec=dspy.LM)
+    mock_extraction_lm.return_value = [
+        """
+[[ ## solution ## ]] result
+[[ ## answer ## ]] 12
+[[ ## completed ## ]]
+"""
+    ]
+    mock_extraction_lm.kwargs = {"temperature": 1.0}
+    mock_extraction_lm.model = "openai/gpt-4o"
+
+    dspy.configure(lm=mock_main_lm, adapter=dspy.TwoStepAdapter(extraction_model=mock_extraction_lm))
+
+    result = program(question="What is 5 + 7?")
+    
+    assert result.answer == 12
+
+    # main LM call
+    mock_main_lm.assert_called_once()
+    _, call_kwargs = mock_main_lm.call_args
+    assert len(call_kwargs["messages"]) == 2
+
+    # assert first message
+    assert call_kwargs["messages"][0]["role"] == "system"
+    content = call_kwargs["messages"][0]["content"]
+    assert "1. `question` (str)" in content
+    assert "1. `solution` (str)" in content
+    assert "2. `answer` (float)" in content
+
+    # assert second message
+    assert call_kwargs["messages"][1]["role"] == "user"
+    content = call_kwargs["messages"][1]["content"]
+    assert "question:" in content.lower()
+    assert "What is 5 + 7?" in content
+
+    # extraction LM call
+    mock_extraction_lm.assert_called_once()
+    _, call_kwargs = mock_extraction_lm.call_args
+    assert len(call_kwargs["messages"]) == 2
+
+    # assert first message
+    assert call_kwargs["messages"][0]["role"] == "system"
+    content = call_kwargs["messages"][0]["content"]
+    assert  "`text` (str)" in content
+    assert  "`solution` (str)" in content
+    assert  "`answer` (float)" in content
+
+    # assert second message
+    assert call_kwargs["messages"][1]["role"] == "user"
+    content = call_kwargs["messages"][1]["content"]
+    assert "text from main LM" in content
+
+
+def test_two_step_adapter_parse():
+    class ComplexSignature(dspy.Signature):
+        input_text: str = dspy.InputField()
+        tags: list[str] = dspy.OutputField(desc="List of relevant tags")
+        confidence: float = dspy.OutputField(desc="Confidence score")
+    
+    first_response = "main LM response"
+    
+    mock_extraction_lm = mock.MagicMock(spec=dspy.LM)
+    mock_extraction_lm.return_value = ["""
+        {
+            "tags": ["AI", "deep learning", "neural networks"],
+            "confidence": 0.87
+        }   
+    """]
+    mock_extraction_lm.kwargs = {"temperature": 1.0}
+    mock_extraction_lm.model = "openai/gpt-4o"
+    adapter = dspy.TwoStepAdapter(mock_extraction_lm)
+    dspy.configure(adapter=adapter, lm=mock_extraction_lm)
+
+    result = adapter.parse(ComplexSignature, first_response)
+    
+    assert result["tags"] == ["AI", "deep learning", "neural networks"]
+    assert result["confidence"] == 0.87
+
+
+def test_two_step_adapter_parse_errors():
+    class TestSignature(dspy.Signature):
+        question: str = dspy.InputField()
+        answer: str = dspy.OutputField()
+    
+    first_response = "main LM response"
+
+    mock_extraction_lm = mock.MagicMock(spec=dspy.LM)
+    mock_extraction_lm.return_value = ["invalid response"]
+    mock_extraction_lm.kwargs = {"temperature": 1.0}
+    mock_extraction_lm.model = "openai/gpt-4o"
+
+    adapter = dspy.TwoStepAdapter(mock_extraction_lm)
+    
+    with pytest.raises(ValueError, match="Failed to parse response"):
+        adapter.parse(TestSignature, first_response) 
diff --git a/tests/clients/test_lm.py b/tests/clients/test_lm.py
--- a/tests/clients/test_lm.py
+++ b/tests/clients/test_lm.py
@@ -199,12 +199,12 @@ def test_reasoning_model_token_parameter():
         lm = dspy.LM(
             model=model_name,
             temperature=1.0 if is_reasoning_model else 0.7,
-            max_tokens=5000 if is_reasoning_model else 1000,
+            max_tokens=20_000 if is_reasoning_model else 1000,
         )
         if is_reasoning_model:
             assert "max_completion_tokens" in lm.kwargs
             assert "max_tokens" not in lm.kwargs
-            assert lm.kwargs["max_completion_tokens"] == 5000
+            assert lm.kwargs["max_completion_tokens"] == 20_000
         else:
             assert "max_completion_tokens" not in lm.kwargs
             assert "max_tokens" in lm.kwargs
@@ -217,17 +217,17 @@ def test_reasoning_model_requirements():
         dspy.LM(
             model="openai/o1",
             temperature=0.7,  # Should be 1.0
-            max_tokens=1000,  # Should be >= 5000
+            max_tokens=1000,  # Should be >= 20_000
         )
-    assert "reasoning models require passing temperature=1.0 and max_tokens >= 5000" in str(exc_info.value)
+    assert "reasoning models require passing temperature=1.0 and max_tokens >= 20_000" in str(exc_info.value)
 
     # Should pass with correct parameters
     lm = dspy.LM(
         model="openai/o1",
         temperature=1.0,
-        max_tokens=5000,
+        max_tokens=20_000,
     )
-    assert lm.kwargs["max_completion_tokens"] == 5000
+    assert lm.kwargs["max_completion_tokens"] == 20_000
 
 
 def test_dump_state():
diff --git a/tests/reliability/conftest.py b/tests/reliability/conftest.py
--- a/tests/reliability/conftest.py
+++ b/tests/reliability/conftest.py
@@ -21,6 +21,7 @@
     "llama-3.1-70b-instruct",
     "llama-3.1-8b-instruct",
     "llama-3.2-3b-instruct",
+    "deepseek-r1",
 ]
 
 
diff --git a/tests/reliability/reliability_conf.yaml b/tests/reliability/reliability_conf.yaml
--- a/tests/reliability/reliability_conf.yaml
+++ b/tests/reliability/reliability_conf.yaml
@@ -73,3 +73,9 @@ model_list:
       # model: "<litellm_provider>/<litellm_model_name>"
       # api_key: "api key"
       # api_base: "<api_base>"
+  - model_name: "deepseek-r1"
+    litellm_params:
+      # model: "<litellm_provider>/<litellm_model_name>"
+      # api_key: "api key"
+      # max_tokens: 10000
+
diff --git a/tests/reliability/test_pydantic_models.py b/tests/reliability/test_pydantic_models.py
--- a/tests/reliability/test_pydantic_models.py
+++ b/tests/reliability/test_pydantic_models.py
@@ -90,18 +90,18 @@ class ExtractEntityFromDescription(dspy.Signature):
     assert_program_output_correct(
         program_input=description,
         program_output=extracted_entity.entity_hu,
-        grading_guidelines="The translation of the text into English should be equivalent to 'coffee'",
+        grading_guidelines="The translation of the extracted entity into English should be equivalent to 'coffee'",
     )
     assert_program_output_correct(
         program_input=description,
-        program_output=extracted_entity.entity_hu,
-        grading_guidelines="The text should be equivalent to 'coffee'",
+        program_output=extracted_entity.entity_en,
+        grading_guidelines="The extracted entity should be equivalent to 'coffee'",
     )
     assert_program_output_correct(
         program_input=description,
         program_output=extracted_entity.categories,
         grading_guidelines=(
-            "The text should contain English language categories that apply to the word 'coffee'."
+            "The extracted entity should be associated with English language categories that apply to the word 'coffee'."
             " The categories should be separated by the character '|'."
         ),
     )
EOF_114329324912

# Run target tests with pytest
# Using -xvs flags for better output
# Running in single-process mode for safety in virtualized environment
pytest -xvs tests/clients/test_lm.py tests/reliability/test_pydantic_models.py
rc=$?

# Required: echo test status for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 320ca3d407a00e14cef31f4dc8943c25ebc0527c "tests/clients/test_lm.py" "tests/reliability/conftest.py" "tests/reliability/reliability_conf.yaml" "tests/reliability/test_pydantic_models.py"

exit $rc