#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout c811792db1e262567ffa18bd9c23da5f6dfc8236 "tests/predict/test_rlm.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/predict/test_rlm.py b/tests/predict/test_rlm.py
--- a/tests/predict/test_rlm.py
+++ b/tests/predict/test_rlm.py
@@ -10,6 +10,7 @@
 
 import pytest
 
+from dspy.adapters.types.tool import Tool
 from dspy.predict.rlm import RLM
 from dspy.primitives.code_interpreter import CodeInterpreterError, FinalOutput
 from dspy.primitives.prediction import Prediction
@@ -143,7 +144,7 @@ def test_custom_tools(self):
         def custom_tool(x: str = "") -> str:
             return x.upper()
 
-        rlm = RLM("context -> answer", max_iterations=5, tools={"custom_tool": custom_tool})
+        rlm = RLM("context -> answer", max_iterations=5, tools=[custom_tool])
         assert "custom_tool" in rlm.tools
         assert len(rlm.tools) == 1  # Only user tools, not internal llm_query/llm_query_batched
 
@@ -153,23 +154,33 @@ def test_tool_validation_invalid_identifier(self, tool_name):
         def my_tool() -> str:
             return "result"
 
+        tool = Tool(my_tool, name=tool_name)
         with pytest.raises(ValueError, match="must be a valid Python identifier"):
-            RLM("context -> answer", tools={tool_name: my_tool})
+            RLM("context -> answer", tools=[tool])
 
     @pytest.mark.parametrize("tool_name", ["llm_query", "SUBMIT", "print"])
     def test_tool_validation_reserved_names(self, tool_name):
         """Test RLM rejects tool names that conflict with built-in functions."""
         def my_tool() -> str:
             return "result"
 
+        tool = Tool(my_tool, name=tool_name)
         with pytest.raises(ValueError, match="conflicts with built-in"):
-            RLM("context -> answer", tools={tool_name: my_tool})
+            RLM("context -> answer", tools=[tool])
 
     @pytest.mark.parametrize("invalid_value", ["not a function", 123])
     def test_tool_validation_not_callable(self, invalid_value):
         """Test RLM rejects tools that aren't callable."""
         with pytest.raises(TypeError, match="must be callable"):
-            RLM("context -> answer", tools={"my_tool": invalid_value})
+            RLM("context -> answer", tools=[invalid_value])
+
+    def test_tools_dict_rejected(self):
+        """Test RLM rejects dict format for tools with helpful error."""
+        def my_tool() -> str:
+            return "result"
+
+        with pytest.raises(TypeError, match="tools must be a list, not a dict"):
+            RLM("context -> answer", tools={"my_tool": my_tool})
 
     def test_optional_parameters(self):
         """Test RLM optional parameters and their defaults."""
@@ -488,7 +499,7 @@ def failing_tool() -> str:
             CodeInterpreterError("RuntimeError: Tool failed!"),
             FinalOutput({"answer": "recovered"}),
         ])
-        rlm = RLM("query -> answer", max_iterations=5, interpreter=mock, tools={"failing_tool": failing_tool})
+        rlm = RLM("query -> answer", max_iterations=5, interpreter=mock, tools=[failing_tool])
         rlm.generate_action = make_mock_predictor([
             {"reasoning": "Call tool", "code": "failing_tool()"},
             {"reasoning": "Recover", "code": 'SUBMIT("recovered")'},
@@ -584,6 +595,30 @@ def test_variable_injection(self):
             )
             assert "15" in result
 
+    def test_variable_injection_with_none_values(self):
+        """Test variable injection with None values in dicts/lists (JSON null -> Python None)."""
+        with PythonInterpreter(tools={}) as interp:
+            # Test None in dict
+            result = interp.execute(
+                "print(data['key'] is None)",
+                variables={"data": {"key": None, "other": "value"}}
+            )
+            assert "True" in result
+
+            # Test None in list
+            result = interp.execute(
+                "print(items[1] is None)",
+                variables={"items": [1, None, 3]}
+            )
+            assert "True" in result
+
+            # Test nested None
+            result = interp.execute(
+                "print(nested['inner']['value'] is None)",
+                variables={"nested": {"inner": {"value": None}}}
+            )
+            assert "True" in result
+
     def test_tool_call_kwargs(self):
         """Test tool call with keyword arguments."""
         def echo(message: str = "") -> str:
@@ -973,7 +1008,7 @@ def lookup(key: str) -> str:
         with dummy_lm_context([
             {"reasoning": "Look up the color of apple", "code": 'color = lookup(key="apple")\nSUBMIT(color)'},
         ]):
-            rlm = RLM("fruit -> color: str", max_iterations=3, tools={"lookup": lookup})
+            rlm = RLM("fruit -> color: str", max_iterations=3, tools=[lookup])
             result = rlm.forward(fruit="apple")
 
             assert result.color == "red"
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# -v for verbose output to help with debugging
# --tb=short for concise traceback on failures
# Note: Running without -m "not integration" to execute all tests unless they fail due to missing dependencies
pytest tests/predict/test_rlm.py -v --tb=short

# Capture exit code
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout c811792db1e262567ffa18bd9c23da5f6dfc8236 "tests/predict/test_rlm.py"

# Exit with the test result code
exit $rc