#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 2513472b6e68fe16e420eae14f9c3fac667a5b47 "tests/callback/test_callback.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/callback/test_callback.py b/tests/callback/test_callback.py
--- a/tests/callback/test_callback.py
+++ b/tests/callback/test_callback.py
@@ -186,6 +186,38 @@ def test_callback_complex_module():
         "on_module_end",
     ]
 
+@pytest.mark.asyncio
+async def test_callback_async_module():
+    callback = MyCallback()
+    dspy.settings.configure(
+        lm=DummyLM({"How are you?": {"answer": "test output", "reasoning": "No more responses"}}),
+        callbacks=[callback],
+    )
+
+    cot = dspy.ChainOfThought("question -> answer", n=3)
+    result = await cot.acall(question="How are you?")
+    assert result["answer"] == "test output"
+    assert result["reasoning"] == "No more responses"
+
+    assert len(callback.calls) == 14
+    assert [call["handler"] for call in callback.calls] == [
+        "on_module_start",
+        "on_module_start",
+        "on_adapter_format_start",
+        "on_adapter_format_end",
+        "on_lm_start",
+        "on_lm_end",
+        # Parsing will run per output (n=3)
+        "on_adapter_parse_start",
+        "on_adapter_parse_end",
+        "on_adapter_parse_start",
+        "on_adapter_parse_end",
+        "on_adapter_parse_start",
+        "on_adapter_parse_end",
+        "on_module_end",
+        "on_module_end",
+    ]
+
 
 def test_tool_calls():
     callback = MyCallback()
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
pytest tests/callback/test_callback.py -v --tb=short

# Capture exit code
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout 2513472b6e68fe16e420eae14f9c3fac667a5b47 "tests/callback/test_callback.py"

# Exit with the test result code
exit $rc