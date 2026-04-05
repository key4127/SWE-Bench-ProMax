#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure virtual environment is activated
source /testbed/.venv/bin/activate

# Checkout the target test files to ensure clean state
git checkout 342a9d65f6e3d07c8ef0bc933da8e56e4593d151 "tests/evaluate/test_evaluate.py" "tests/primitives/test_example.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/evaluate/test_evaluate.py b/tests/evaluate/test_evaluate.py
--- a/tests/evaluate/test_evaluate.py
+++ b/tests/evaluate/test_evaluate.py
@@ -1,4 +1,6 @@
+import json
 import signal
+import tempfile
 import threading
 from unittest.mock import patch
 
@@ -261,3 +263,136 @@ def on_evaluate_end(
 def test_evaluation_result_repr():
     result = EvaluationResult(score=100.0, results=[(new_example("What is 1+1?", "2"), {"answer": "2"}, 100.0)])
     assert repr(result) == "EvaluationResult(score=100.0, results=<list of 1 results>)"
+
+
+def test_evaluate_save_as_json_with_history():
+    """Test that save_as_json works with Examples containing dspy.History objects."""
+    # Setup
+    dspy.settings.configure(
+        lm=DummyLM(
+            {
+                "What is 1+1?": {"answer": "2"},
+                "What is 2+2?": {"answer": "4"},
+            }
+        )
+    )
+
+    # Create history objects
+    history1 = dspy.History(
+        messages=[
+            {"question": "Previous Q1", "answer": "Previous A1"},
+        ]
+    )
+    history2 = dspy.History(
+        messages=[
+            {"question": "Previous Q2", "answer": "Previous A2"},
+            {"question": "Previous Q3", "answer": "Previous A3"},
+        ]
+    )
+
+    # Create examples with history
+    devset = [
+        dspy.Example(question="What is 1+1?", answer="2", history=history1).with_inputs("question"),
+        dspy.Example(question="What is 2+2?", answer="4", history=history2).with_inputs("question"),
+    ]
+
+    program = Predict("question -> answer")
+
+    # Create evaluator with save_as_json
+    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
+        temp_json = f.name
+
+    try:
+        evaluator = Evaluate(
+            devset=devset,
+            metric=answer_exact_match,
+            display_progress=False,
+            save_as_json=temp_json,
+        )
+
+        result = evaluator(program)
+        assert result.score == 100.0
+
+        # Verify JSON file was created and is valid
+        with open(temp_json) as f:
+            data = json.load(f)
+
+        assert len(data) == 2
+
+        # Verify history was properly serialized in first record
+        assert "history" in data[0]
+        assert isinstance(data[0]["history"], dict)
+        assert "messages" in data[0]["history"]
+        assert len(data[0]["history"]["messages"]) == 1
+        assert data[0]["history"]["messages"][0] == {"question": "Previous Q1", "answer": "Previous A1"}
+
+        # Verify history was properly serialized in second record
+        assert "history" in data[1]
+        assert isinstance(data[1]["history"], dict)
+        assert "messages" in data[1]["history"]
+        assert len(data[1]["history"]["messages"]) == 2
+        assert data[1]["history"]["messages"][0] == {"question": "Previous Q2", "answer": "Previous A2"}
+        assert data[1]["history"]["messages"][1] == {"question": "Previous Q3", "answer": "Previous A3"}
+
+    finally:
+        import os
+        if os.path.exists(temp_json):
+            os.unlink(temp_json)
+
+
+def test_evaluate_save_as_csv_with_history():
+    """Test that save_as_csv works with Examples containing dspy.History objects."""
+    # Setup
+    dspy.settings.configure(
+        lm=DummyLM(
+            {
+                "What is 1+1?": {"answer": "2"},
+            }
+        )
+    )
+
+    # Create history object
+    history = dspy.History(
+        messages=[
+            {"question": "Previous Q", "answer": "Previous A"},
+        ]
+    )
+
+    # Create example with history
+    devset = [
+        dspy.Example(question="What is 1+1?", answer="2", history=history).with_inputs("question"),
+    ]
+
+    program = Predict("question -> answer")
+
+    # Create evaluator with save_as_csv
+    with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False) as f:
+        temp_csv = f.name
+
+    try:
+        evaluator = Evaluate(
+            devset=devset,
+            metric=answer_exact_match,
+            display_progress=False,
+            save_as_csv=temp_csv,
+        )
+
+        result = evaluator(program)
+        assert result.score == 100.0
+
+        # Verify CSV file was created
+        import csv
+        with open(temp_csv) as f:
+            reader = csv.DictReader(f)
+            rows = list(reader)
+
+        assert len(rows) == 1
+        assert "history" in rows[0]
+        # CSV will have string representation of the dict
+        assert "messages" in rows[0]["history"]
+
+    finally:
+        import os
+        if os.path.exists(temp_csv):
+            os.unlink(temp_csv)
+
diff --git a/tests/primitives/test_example.py b/tests/primitives/test_example.py
--- a/tests/primitives/test_example.py
+++ b/tests/primitives/test_example.py
@@ -123,3 +123,34 @@ def test_example_copy_without():
 def test_example_to_dict():
     example = Example(a=1, b=2)
     assert example.toDict() == {"a": 1, "b": 2}
+
+
+def test_example_to_dict_with_history():
+    """Test that Example.toDict() properly serializes dspy.History objects."""
+    history = dspy.History(
+        messages=[
+            {"question": "What is the capital of France?", "answer": "Paris"},
+            {"question": "What is the capital of Germany?", "answer": "Berlin"},
+        ]
+    )
+    example = Example(question="Test question", history=history, answer="Test answer")
+
+    result = example.toDict()
+
+    # Verify the result is a dictionary
+    assert isinstance(result, dict)
+    assert "history" in result
+
+    # Verify history is serialized to a dict (not a History object)
+    assert isinstance(result["history"], dict)
+    assert "messages" in result["history"]
+    assert result["history"]["messages"] == [
+        {"question": "What is the capital of France?", "answer": "Paris"},
+        {"question": "What is the capital of Germany?", "answer": "Berlin"},
+    ]
+
+    # Verify JSON serialization works
+    import json
+    json_str = json.dumps(result)
+    restored = json.loads(json_str)
+    assert restored["history"]["messages"] == result["history"]["messages"]
EOF_114329324912

# Run target tests with pytest
# Using --extra flag as required for tests/evaluate/test_evaluate.py
# Using -xvs flags for better output and single-process mode for safety
pytest -xvs --extra tests/evaluate/test_evaluate.py tests/primitives/test_example.py
rc=$?

# Required: echo test status for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 342a9d65f6e3d07c8ef0bc933da8e56e4593d151 "tests/evaluate/test_evaluate.py" "tests/primitives/test_example.py"

exit $rc