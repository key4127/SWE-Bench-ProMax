#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout ec1eff02a8b98851230b27c7b5351b857cf6ccb7 "tests/agents/test_crew_agent_parser.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/agents/test_crew_agent_parser.py b/tests/agents/test_crew_agent_parser.py
--- a/tests/agents/test_crew_agent_parser.py
+++ b/tests/agents/test_crew_agent_parser.py
@@ -5,25 +5,18 @@
     AgentFinish,
     OutputParserException,
 )
-from crewai.agents.parser import CrewAgentParser
+from crewai.agents import parser
 
 
-@pytest.fixture
-def parser():
-    agent = MockAgent()
-    p = CrewAgentParser(agent)
-    return p
-
-
-def test_valid_action_parsing_special_characters(parser):
+def test_valid_action_parsing_special_characters():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: what's the temperature in SF?"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what's the temperature in SF?"
 
 
-def test_valid_action_parsing_with_json_tool_input(parser):
+def test_valid_action_parsing_with_json_tool_input():
     text = """
     Thought: Let's find the information
     Action: query
@@ -36,173 +29,173 @@ def test_valid_action_parsing_with_json_tool_input(parser):
     assert result.tool_input == expected_tool_input
 
 
-def test_valid_action_parsing_with_quotes(parser):
+def test_valid_action_parsing_with_quotes():
     text = 'Thought: Let\'s find the temperature\nAction: search\nAction Input: "temperature in SF"'
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "temperature in SF"
 
 
-def test_valid_action_parsing_with_curly_braces(parser):
+def test_valid_action_parsing_with_curly_braces():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: {temperature in SF}"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "{temperature in SF}"
 
 
-def test_valid_action_parsing_with_angle_brackets(parser):
+def test_valid_action_parsing_with_angle_brackets():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: <temperature in SF>"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "<temperature in SF>"
 
 
-def test_valid_action_parsing_with_parentheses(parser):
+def test_valid_action_parsing_with_parentheses():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: (temperature in SF)"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "(temperature in SF)"
 
 
-def test_valid_action_parsing_with_mixed_brackets(parser):
+def test_valid_action_parsing_with_mixed_brackets():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: [temperature in {SF}]"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "[temperature in {SF}]"
 
 
-def test_valid_action_parsing_with_nested_quotes(parser):
+def test_valid_action_parsing_with_nested_quotes():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: \"what's the temperature in 'SF'?\""
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what's the temperature in 'SF'?"
 
 
-def test_valid_action_parsing_with_incomplete_json(parser):
+def test_valid_action_parsing_with_incomplete_json():
     text = 'Thought: Let\'s find the temperature\nAction: search\nAction Input: {"query": "temperature in SF"'
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == '{"query": "temperature in SF"}'
 
 
-def test_valid_action_parsing_with_special_characters(parser):
+def test_valid_action_parsing_with_special_characters():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: what is the temperature in SF? @$%^&*"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what is the temperature in SF? @$%^&*"
 
 
-def test_valid_action_parsing_with_combination(parser):
+def test_valid_action_parsing_with_combination():
     text = 'Thought: Let\'s find the temperature\nAction: search\nAction Input: "[what is the temperature in SF?]"'
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "[what is the temperature in SF?]"
 
 
-def test_valid_action_parsing_with_mixed_quotes(parser):
+def test_valid_action_parsing_with_mixed_quotes():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: \"what's the temperature in SF?\""
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what's the temperature in SF?"
 
 
-def test_valid_action_parsing_with_newlines(parser):
+def test_valid_action_parsing_with_newlines():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: what is\nthe temperature in SF?"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what is\nthe temperature in SF?"
 
 
-def test_valid_action_parsing_with_escaped_characters(parser):
+def test_valid_action_parsing_with_escaped_characters():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: what is the temperature in SF? \\n"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what is the temperature in SF? \\n"
 
 
-def test_valid_action_parsing_with_json_string(parser):
+def test_valid_action_parsing_with_json_string():
     text = 'Thought: Let\'s find the temperature\nAction: search\nAction Input: {"query": "temperature in SF"}'
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == '{"query": "temperature in SF"}'
 
 
-def test_valid_action_parsing_with_unbalanced_quotes(parser):
+def test_valid_action_parsing_with_unbalanced_quotes():
     text = "Thought: Let's find the temperature\nAction: search\nAction Input: \"what is the temperature in SF?"
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what is the temperature in SF?"
 
 
-def test_clean_action_no_formatting(parser):
+def test_clean_action_no_formatting():
     action = "Ask question to senior researcher"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_leading_asterisks(parser):
+def test_clean_action_with_leading_asterisks():
     action = "** Ask question to senior researcher"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_trailing_asterisks(parser):
+def test_clean_action_with_trailing_asterisks():
     action = "Ask question to senior researcher **"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_leading_and_trailing_asterisks(parser):
+def test_clean_action_with_leading_and_trailing_asterisks():
     action = "** Ask question to senior researcher **"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_multiple_leading_asterisks(parser):
+def test_clean_action_with_multiple_leading_asterisks():
     action = "**** Ask question to senior researcher"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_multiple_trailing_asterisks(parser):
+def test_clean_action_with_multiple_trailing_asterisks():
     action = "Ask question to senior researcher ****"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_spaces_and_asterisks(parser):
+def test_clean_action_with_spaces_and_asterisks():
     action = "  **  Ask question to senior researcher  **  "
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == "Ask question to senior researcher"
 
 
-def test_clean_action_with_only_asterisks(parser):
+def test_clean_action_with_only_asterisks():
     action = "****"
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == ""
 
 
-def test_clean_action_with_empty_string(parser):
+def test_clean_action_with_empty_string():
     action = ""
     cleaned_action = parser._clean_action(action)
     assert cleaned_action == ""
 
 
-def test_valid_final_answer_parsing(parser):
+def test_valid_final_answer_parsing():
     text = (
         "Thought: I found the information\nFinal Answer: The temperature is 100 degrees"
     )
@@ -211,7 +204,7 @@ def test_valid_final_answer_parsing(parser):
     assert result.output == "The temperature is 100 degrees"
 
 
-def test_missing_action_error(parser):
+def test_missing_action_error():
     text = "Thought: Let's find the temperature\nAction Input: what is the temperature in SF?"
     with pytest.raises(OutputParserException) as exc_info:
         parser.parse(text)
@@ -220,27 +213,27 @@ def test_missing_action_error(parser):
     )
 
 
-def test_missing_action_input_error(parser):
+def test_missing_action_input_error():
     text = "Thought: Let's find the temperature\nAction: search"
     with pytest.raises(OutputParserException) as exc_info:
         parser.parse(text)
     assert "I missed the 'Action Input:' after 'Action:'." in str(exc_info.value)
 
 
-def test_safe_repair_json(parser):
+def test_safe_repair_json():
     invalid_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": Senior Researcher'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_unrepairable(parser):
+def test_safe_repair_json_unrepairable():
     invalid_json = "{invalid_json"
     result = parser._safe_repair_json(invalid_json)
     assert result == invalid_json  # Should return the original if unrepairable
 
 
-def test_safe_repair_json_missing_quotes(parser):
+def test_safe_repair_json_missing_quotes():
     invalid_json = (
         '{task: "Research XAI", context: "Explainable AI", coworker: Senior Researcher}'
     )
@@ -249,93 +242,93 @@ def test_safe_repair_json_missing_quotes(parser):
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_unclosed_brackets(parser):
+def test_safe_repair_json_unclosed_brackets():
     invalid_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_extra_commas(parser):
+def test_safe_repair_json_extra_commas():
     invalid_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher",}'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_trailing_commas(parser):
+def test_safe_repair_json_trailing_commas():
     invalid_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher",}'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_single_quotes(parser):
+def test_safe_repair_json_single_quotes():
     invalid_json = "{'task': 'Research XAI', 'context': 'Explainable AI', 'coworker': 'Senior Researcher'}"
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_mixed_quotes(parser):
+def test_safe_repair_json_mixed_quotes():
     invalid_json = "{'task': \"Research XAI\", 'context': \"Explainable AI\", 'coworker': 'Senior Researcher'}"
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_unescaped_characters(parser):
+def test_safe_repair_json_unescaped_characters():
     invalid_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher\n"}'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_missing_colon(parser):
+def test_safe_repair_json_missing_colon():
     invalid_json = '{"task" "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_missing_comma(parser):
+def test_safe_repair_json_missing_comma():
     invalid_json = '{"task": "Research XAI" "context": "Explainable AI", "coworker": "Senior Researcher"}'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_unexpected_trailing_characters(parser):
+def test_safe_repair_json_unexpected_trailing_characters():
     invalid_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"} random text'
     expected_repaired_json = '{"task": "Research XAI", "context": "Explainable AI", "coworker": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_safe_repair_json_special_characters_key(parser):
+def test_safe_repair_json_special_characters_key():
     invalid_json = '{"task!@#": "Research XAI", "context$%^": "Explainable AI", "coworker&*()": "Senior Researcher"}'
     expected_repaired_json = '{"task!@#": "Research XAI", "context$%^": "Explainable AI", "coworker&*()": "Senior Researcher"}'
     result = parser._safe_repair_json(invalid_json)
     assert result == expected_repaired_json
 
 
-def test_parsing_with_whitespace(parser):
+def test_parsing_with_whitespace():
     text = " Thought: Let's find the temperature \n Action: search \n Action Input: what is the temperature in SF? "
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what is the temperature in SF?"
 
 
-def test_parsing_with_special_characters(parser):
+def test_parsing_with_special_characters():
     text = 'Thought: Let\'s find the temperature\nAction: search\nAction Input: "what is the temperature in SF?"'
     result = parser.parse(text)
     assert isinstance(result, AgentAction)
     assert result.tool == "search"
     assert result.tool_input == "what is the temperature in SF?"
 
 
-def test_integration_valid_and_invalid(parser):
+def test_integration_valid_and_invalid():
     text = """
     Thought: Let's find the temperature
     Action: search
@@ -365,9 +358,4 @@ def test_integration_valid_and_invalid(parser):
     assert isinstance(results[3], OutputParserException)
 
 
-class MockAgent:
-    def increment_formatting_errors(self):
-        pass
-
-
 # TODO: ADD TEST TO MAKE SURE ** REMOVAL DOESN'T MESS UP ANYTHING
EOF_114329324912

# Set environment variables to disable telemetry
export OTEL_SDK_DISABLED=true
export PYTHONUNBUFFERED=1

# Run the target test file using uv
# Using single-process mode for safety in virtualized environment
uv run pytest --no-header -rA --tb=short -p no:cacheprovider tests/agents/test_crew_agent_parser.py

# Capture exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout ec1eff02a8b98851230b27c7b5351b857cf6ccb7 "tests/agents/test_crew_agent_parser.py"