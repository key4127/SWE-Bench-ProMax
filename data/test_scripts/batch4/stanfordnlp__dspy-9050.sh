#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout e2b9ef8671da6ee256d1f9d7f6833850c740dee5 "tests/teleprompt/test_gepa.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/teleprompt/test_gepa.py b/tests/teleprompt/test_gepa.py
--- a/tests/teleprompt/test_gepa.py
+++ b/tests/teleprompt/test_gepa.py
@@ -43,7 +43,16 @@ def bad_metric(example, prediction):
     return 0.0
 
 
-def test_gepa_adapter_disables_logging_during_trace_capture(monkeypatch):
+@pytest.mark.parametrize("reflection_minibatch_size, batch, expected_callback_metadata", [
+    (None, [], {"metric_key": "eval_full"}),
+    (None, [Example(input="What is the color of the sky?", output="blue")], {"metric_key": "eval_full"}),
+    (1, [], {"disable_logging": True}),
+    (1, [
+        Example(input="What is the color of the sky?", output="blue"),
+        Example(input="What does the fox say?", output="Ring-ding-ding-ding-dingeringeding!"),
+    ], {"metric_key": "eval_full"}),
+])
+def test_gepa_adapter_disables_logging_on_minibatch_eval(monkeypatch, reflection_minibatch_size, batch, expected_callback_metadata):
     from dspy.teleprompt import bootstrap_trace as bootstrap_trace_module
     from dspy.teleprompt.gepa import gepa_utils
 
@@ -57,6 +66,7 @@ def forward(self, **kwargs):  # pragma: no cover - stub forward
         metric_fn=simple_metric,
         feedback_map={},
         failure_score=0.0,
+        reflection_minibatch_size=reflection_minibatch_size,
     )
 
     captured_kwargs: dict[str, Any] = {}
@@ -72,9 +82,9 @@ def dummy_bootstrap_trace_data(*args, **kwargs):
         lambda self, candidate: DummyModule(),
     )
 
-    adapter.evaluate(batch=[], candidate={}, capture_traces=True)
+    adapter.evaluate(batch=batch, candidate={}, capture_traces=True)
 
-    assert captured_kwargs["callback_metadata"] == {"disable_logging": True}
+    assert captured_kwargs["callback_metadata"] == expected_callback_metadata
 
 
 @pytest.fixture
EOF_114329324912

# Run target tests with pytest
# Using -xvs flags for better output and debugging
# Running in single-process mode for safety in virtualized environment
pytest -xvs tests/teleprompt/test_gepa.py
rc=$?

# Required: echo test status for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout e2b9ef8671da6ee256d1f9d7f6833850c740dee5 "tests/teleprompt/test_gepa.py"

exit $rc