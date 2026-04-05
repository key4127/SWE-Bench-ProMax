#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 07bb1647588a781e701257c4c379736537029ea0 \
    "tests/unittests/evaluation/test_final_response_match_v1.py" \
    "tests/unittests/evaluation/test_final_response_match_v2.py" \
    "tests/unittests/evaluation/test_metric_evaluator_registry.py" \
    "tests/unittests/evaluation/test_response_evaluator.py" \
    "tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py" \
    "tests/unittests/evaluation/test_safety_evaluator.py" \
    "tests/unittests/evaluation/test_trajectory_evaluator.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/evaluation/test_final_response_match_v1.py b/tests/unittests/evaluation/test_final_response_match_v1.py
--- a/tests/unittests/evaluation/test_final_response_match_v1.py
+++ b/tests/unittests/evaluation/test_final_response_match_v1.py
@@ -139,11 +139,3 @@ def test_rouge_evaluator_multiple_invocations(
       expected_score, rel=1e-3
   )
   assert evaluation_result.overall_eval_status == expected_status
-
-
-def test_get_metric_info():
-  """Test get_metric_info function for response match metric."""
-  metric_info = RougeEvaluator.get_metric_info()
-  assert metric_info.metric_name == PrebuiltMetrics.RESPONSE_MATCH_SCORE.value
-  assert metric_info.metric_value_info.interval.min_value == 0.0
-  assert metric_info.metric_value_info.interval.max_value == 1.0
diff --git a/tests/unittests/evaluation/test_final_response_match_v2.py b/tests/unittests/evaluation/test_final_response_match_v2.py
--- a/tests/unittests/evaluation/test_final_response_match_v2.py
+++ b/tests/unittests/evaluation/test_final_response_match_v2.py
@@ -486,13 +486,3 @@ def test_aggregate_invocation_results():
   # Only 4 / 8 invocations are evaluated, and 2 / 4 are valid.
   assert aggregated_result.overall_score == 0.5
   assert aggregated_result.overall_eval_status == EvalStatus.PASSED
-
-
-def test_get_metric_info():
-  """Test get_metric_info function for Final Response Match V2 metric."""
-  metric_info = FinalResponseMatchV2Evaluator.get_metric_info()
-  assert (
-      metric_info.metric_name == PrebuiltMetrics.FINAL_RESPONSE_MATCH_V2.value
-  )
-  assert metric_info.metric_value_info.interval.min_value == 0.0
-  assert metric_info.metric_value_info.interval.max_value == 1.0
diff --git a/tests/unittests/evaluation/test_metric_evaluator_registry.py b/tests/unittests/evaluation/test_metric_evaluator_registry.py
--- a/tests/unittests/evaluation/test_metric_evaluator_registry.py
+++ b/tests/unittests/evaluation/test_metric_evaluator_registry.py
@@ -19,102 +19,192 @@
 from google.adk.evaluation.eval_metrics import Interval
 from google.adk.evaluation.eval_metrics import MetricInfo
 from google.adk.evaluation.eval_metrics import MetricValueInfo
+from google.adk.evaluation.eval_metrics import PrebuiltMetrics
 from google.adk.evaluation.evaluator import Evaluator
+from google.adk.evaluation.metric_evaluator_registry import FinalResponseMatchV2EvaluatorMetricInfoProvider
+from google.adk.evaluation.metric_evaluator_registry import HallucinationsV1EvaluatorMetricInfoProvider
 from google.adk.evaluation.metric_evaluator_registry import MetricEvaluatorRegistry
+from google.adk.evaluation.metric_evaluator_registry import PerTurnUserSimulatorQualityV1MetricInfoProvider
+from google.adk.evaluation.metric_evaluator_registry import ResponseEvaluatorMetricInfoProvider
+from google.adk.evaluation.metric_evaluator_registry import RubricBasedFinalResponseQualityV1EvaluatorMetricInfoProvider
+from google.adk.evaluation.metric_evaluator_registry import RubricBasedToolUseV1EvaluatorMetricInfoProvider
+from google.adk.evaluation.metric_evaluator_registry import SafetyEvaluatorV1MetricInfoProvider
+from google.adk.evaluation.metric_evaluator_registry import TrajectoryEvaluatorMetricInfoProvider
 import pytest
 
 _DUMMY_METRIC_NAME = "dummy_metric_name"
+_DUMMY_METRIC_INFO = MetricInfo(
+    metric_name=_DUMMY_METRIC_NAME,
+    description="Dummy metric description",
+    metric_value_info=MetricValueInfo(
+        interval=Interval(min_value=0.0, max_value=1.0)
+    ),
+)
+_ANOTHER_DUMMY_METRIC_INFO = MetricInfo(
+    metric_name=_DUMMY_METRIC_NAME,
+    description="Another dummy metric description",
+    metric_value_info=MetricValueInfo(
+        interval=Interval(min_value=0.0, max_value=1.0)
+    ),
+)
 
 
-class TestMetricEvaluatorRegistry:
-  """Test cases for MetricEvaluatorRegistry."""
+class DummyEvaluator(Evaluator):
 
-  @pytest.fixture
-  def registry(self):
-    return MetricEvaluatorRegistry()
+  def __init__(self, eval_metric: EvalMetric):
+    self._eval_metric = eval_metric
 
-  class DummyEvaluator(Evaluator):
+  def evaluate_invocations(self, actual_invocations, expected_invocations):
+    return "dummy_result"
 
-    def __init__(self, eval_metric: EvalMetric):
-      self._eval_metric = eval_metric
 
-    def evaluate_invocations(self, actual_invocations, expected_invocations):
-      return "dummy_result"
+class AnotherDummyEvaluator(Evaluator):
 
-    @staticmethod
-    def get_metric_info() -> MetricInfo:
-      return MetricInfo(
-          metric_name=_DUMMY_METRIC_NAME,
-          description="Dummy metric description",
-          metric_value_info=MetricValueInfo(
-              interval=Interval(min_value=0.0, max_value=1.0)
-          ),
-      )
+  def __init__(self, eval_metric: EvalMetric):
+    self._eval_metric = eval_metric
 
-  class AnotherDummyEvaluator(Evaluator):
+  def evaluate_invocations(self, actual_invocations, expected_invocations):
+    return "another_dummy_result"
 
-    def __init__(self, eval_metric: EvalMetric):
-      self._eval_metric = eval_metric
 
-    def evaluate_invocations(self, actual_invocations, expected_invocations):
-      return "another_dummy_result"
+class TestMetricEvaluatorRegistry:
+  """Test cases for MetricEvaluatorRegistry."""
 
-    @staticmethod
-    def get_metric_info() -> MetricInfo:
-      return MetricInfo(
-          metric_name=_DUMMY_METRIC_NAME,
-          description="Another dummy metric description",
-          metric_value_info=MetricValueInfo(
-              interval=Interval(min_value=0.0, max_value=1.0)
-          ),
-      )
+  @pytest.fixture
+  def registry(self):
+    return MetricEvaluatorRegistry()
 
   def test_register_evaluator(self, registry):
-    metric_info = TestMetricEvaluatorRegistry.DummyEvaluator.get_metric_info()
     registry.register_evaluator(
-        metric_info,
-        TestMetricEvaluatorRegistry.DummyEvaluator,
+        _DUMMY_METRIC_INFO,
+        DummyEvaluator,
     )
     assert _DUMMY_METRIC_NAME in registry._registry
     assert registry._registry[_DUMMY_METRIC_NAME] == (
-        TestMetricEvaluatorRegistry.DummyEvaluator,
-        metric_info,
+        DummyEvaluator,
+        _DUMMY_METRIC_INFO,
     )
 
   def test_register_evaluator_updates_existing(self, registry):
-    metric_info = TestMetricEvaluatorRegistry.DummyEvaluator.get_metric_info()
     registry.register_evaluator(
-        metric_info,
-        TestMetricEvaluatorRegistry.DummyEvaluator,
+        _DUMMY_METRIC_INFO,
+        DummyEvaluator,
     )
 
     assert registry._registry[_DUMMY_METRIC_NAME] == (
-        TestMetricEvaluatorRegistry.DummyEvaluator,
-        metric_info,
+        DummyEvaluator,
+        _DUMMY_METRIC_INFO,
     )
 
-    metric_info = (
-        TestMetricEvaluatorRegistry.AnotherDummyEvaluator.get_metric_info()
-    )
     registry.register_evaluator(
-        metric_info, TestMetricEvaluatorRegistry.AnotherDummyEvaluator
+        _ANOTHER_DUMMY_METRIC_INFO, AnotherDummyEvaluator
     )
     assert registry._registry[_DUMMY_METRIC_NAME] == (
-        TestMetricEvaluatorRegistry.AnotherDummyEvaluator,
-        metric_info,
+        AnotherDummyEvaluator,
+        _ANOTHER_DUMMY_METRIC_INFO,
     )
 
   def test_get_evaluator(self, registry):
-    metric_info = TestMetricEvaluatorRegistry.DummyEvaluator.get_metric_info()
     registry.register_evaluator(
-        metric_info,
-        TestMetricEvaluatorRegistry.DummyEvaluator,
+        _DUMMY_METRIC_INFO,
+        DummyEvaluator,
     )
     eval_metric = EvalMetric(metric_name=_DUMMY_METRIC_NAME, threshold=0.5)
     evaluator = registry.get_evaluator(eval_metric)
-    assert isinstance(evaluator, TestMetricEvaluatorRegistry.DummyEvaluator)
+    assert isinstance(evaluator, DummyEvaluator)
 
   def test_get_evaluator_not_found(self, registry):
     eval_metric = EvalMetric(metric_name="non_existent_metric", threshold=0.5)
     with pytest.raises(NotFoundError):
       registry.get_evaluator(eval_metric)
+
+
+class TestMetricInfoProviders:
+  """Test cases for MetricInfoProviders."""
+
+  def test_trajectory_evaluator_metric_info_provider(self):
+    metric_info = TrajectoryEvaluatorMetricInfoProvider().get_metric_info()
+    assert (
+        metric_info.metric_name
+        == PrebuiltMetrics.TOOL_TRAJECTORY_AVG_SCORE.value
+    )
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_response_evaluator_metric_info_provider_eval_score(self):
+    metric_info = ResponseEvaluatorMetricInfoProvider(
+        PrebuiltMetrics.RESPONSE_EVALUATION_SCORE.value
+    ).get_metric_info()
+    assert (
+        metric_info.metric_name
+        == PrebuiltMetrics.RESPONSE_EVALUATION_SCORE.value
+    )
+    assert metric_info.metric_value_info.interval.min_value == 1.0
+    assert metric_info.metric_value_info.interval.max_value == 5.0
+
+  def test_response_evaluator_metric_info_provider_match_score(self):
+    metric_info = ResponseEvaluatorMetricInfoProvider(
+        PrebuiltMetrics.RESPONSE_MATCH_SCORE.value
+    ).get_metric_info()
+    assert metric_info.metric_name == PrebuiltMetrics.RESPONSE_MATCH_SCORE.value
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_safety_evaluator_v1_metric_info_provider(self):
+    metric_info = SafetyEvaluatorV1MetricInfoProvider().get_metric_info()
+    assert metric_info.metric_name == PrebuiltMetrics.SAFETY_V1.value
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_final_response_match_v2_evaluator_metric_info_provider(self):
+    metric_info = (
+        FinalResponseMatchV2EvaluatorMetricInfoProvider().get_metric_info()
+    )
+    assert (
+        metric_info.metric_name == PrebuiltMetrics.FINAL_RESPONSE_MATCH_V2.value
+    )
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_rubric_based_final_response_quality_v1_evaluator_metric_info_provider(
+      self,
+  ):
+    metric_info = (
+        RubricBasedFinalResponseQualityV1EvaluatorMetricInfoProvider().get_metric_info()
+    )
+    assert (
+        metric_info.metric_name
+        == PrebuiltMetrics.RUBRIC_BASED_FINAL_RESPONSE_QUALITY_V1.value
+    )
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_hallucinations_v1_evaluator_metric_info_provider(self):
+    metric_info = (
+        HallucinationsV1EvaluatorMetricInfoProvider().get_metric_info()
+    )
+    assert metric_info.metric_name == PrebuiltMetrics.HALLUCINATIONS_V1.value
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_rubric_based_tool_use_v1_evaluator_metric_info_provider(self):
+    metric_info = (
+        RubricBasedToolUseV1EvaluatorMetricInfoProvider().get_metric_info()
+    )
+    assert (
+        metric_info.metric_name
+        == PrebuiltMetrics.RUBRIC_BASED_TOOL_USE_QUALITY_V1.value
+    )
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
+
+  def test_per_turn_user_simulator_quality_v1_metric_info_provider(self):
+    metric_info = (
+        PerTurnUserSimulatorQualityV1MetricInfoProvider().get_metric_info()
+    )
+    assert (
+        metric_info.metric_name
+        == PrebuiltMetrics.PER_TURN_USER_SIMULATOR_QUALITY_V1.value
+    )
+    assert metric_info.metric_value_info.interval.min_value == 0.0
+    assert metric_info.metric_value_info.interval.max_value == 1.0
diff --git a/tests/unittests/evaluation/test_response_evaluator.py b/tests/unittests/evaluation/test_response_evaluator.py
--- a/tests/unittests/evaluation/test_response_evaluator.py
+++ b/tests/unittests/evaluation/test_response_evaluator.py
@@ -118,29 +118,3 @@ def test_evaluate_invocations_coherence_metric_passed(self, mocker):
     assert [m.name for m in mock_kwargs["metrics"]] == [
         vertexai_types.PrebuiltMetric.COHERENCE.name
     ]
-
-  def test_get_metric_info_response_evaluation_score(self):
-    """Test get_metric_info function for response evaluation metric."""
-    metric_info = ResponseEvaluator.get_metric_info(
-        PrebuiltMetrics.RESPONSE_EVALUATION_SCORE.value
-    )
-    assert (
-        metric_info.metric_name
-        == PrebuiltMetrics.RESPONSE_EVALUATION_SCORE.value
-    )
-    assert metric_info.metric_value_info.interval.min_value == 1.0
-    assert metric_info.metric_value_info.interval.max_value == 5.0
-
-  def test_get_metric_info_response_match_score(self):
-    """Test get_metric_info function for response match metric."""
-    metric_info = ResponseEvaluator.get_metric_info(
-        PrebuiltMetrics.RESPONSE_MATCH_SCORE.value
-    )
-    assert metric_info.metric_name == PrebuiltMetrics.RESPONSE_MATCH_SCORE.value
-    assert metric_info.metric_value_info.interval.min_value == 0.0
-    assert metric_info.metric_value_info.interval.max_value == 1.0
-
-  def test_get_metric_info_invalid(self):
-    """Test get_metric_info function for invalid metric."""
-    with pytest.raises(ValueError):
-      ResponseEvaluator.get_metric_info("invalid_metric")
diff --git a/tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py b/tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py
--- a/tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py
+++ b/tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py
@@ -136,15 +136,3 @@ def test_format_auto_rater_prompt_with_intermediate_data(
   assert '"name": "test_func"' in prompt
   assert '"tool_response":' in prompt
   assert '"result": "ok"' in prompt
-
-
-def test_get_metric_info(evaluator: RubricBasedToolUseV1Evaluator):
-  """Tests the get_metric_info method."""
-  metric_info = evaluator.get_metric_info()
-  assert (
-      metric_info.metric_name
-      == PrebuiltMetrics.RUBRIC_BASED_TOOL_USE_QUALITY_V1.value
-  )
-  assert "agent's usage of tools" in metric_info.description
-  assert metric_info.metric_value_info.interval.min_value == 0.0
-  assert metric_info.metric_value_info.interval.max_value == 1.0
diff --git a/tests/unittests/evaluation/test_safety_evaluator.py b/tests/unittests/evaluation/test_safety_evaluator.py
--- a/tests/unittests/evaluation/test_safety_evaluator.py
+++ b/tests/unittests/evaluation/test_safety_evaluator.py
@@ -76,10 +76,3 @@ def test_evaluate_invocations_coherence_metric_passed(self, mocker):
     assert [m.name for m in mock_kwargs["metrics"]] == [
         vertexai_types.PrebuiltMetric.SAFETY.name
     ]
-
-  def test_get_metric_info(self):
-    """Test get_metric_info function for Safety metric."""
-    metric_info = SafetyEvaluatorV1.get_metric_info()
-    assert metric_info.metric_name == PrebuiltMetrics.SAFETY_V1.value
-    assert metric_info.metric_value_info.interval.min_value == 0.0
-    assert metric_info.metric_value_info.interval.max_value == 1.0
diff --git a/tests/unittests/evaluation/test_trajectory_evaluator.py b/tests/unittests/evaluation/test_trajectory_evaluator.py
--- a/tests/unittests/evaluation/test_trajectory_evaluator.py
+++ b/tests/unittests/evaluation/test_trajectory_evaluator.py
@@ -30,16 +30,6 @@
 )
 
 
-def test_get_metric_info():
-  """Test get_metric_info function for tool trajectory avg metric."""
-  metric_info = TrajectoryEvaluator.get_metric_info()
-  assert (
-      metric_info.metric_name == PrebuiltMetrics.TOOL_TRAJECTORY_AVG_SCORE.value
-  )
-  assert metric_info.metric_value_info.interval.min_value == 0.0
-  assert metric_info.metric_value_info.interval.max_value == 1.0
-
-
 @pytest.fixture
 def evaluator() -> TrajectoryEvaluator:
   """Returns a TrajectoryEvaluator."""
EOF_114329324912

# Run the target test files
# Using single-process mode for stability in virtualized environment
# --no-header: cleaner output
# -rA: show summary of all test outcomes
# --tb=short: shorter traceback format for better readability
# -p no:cacheprovider: disable cache for clean test execution
pytest --no-header -rA --tb=short -p no:cacheprovider \
    tests/unittests/evaluation/test_final_response_match_v1.py \
    tests/unittests/evaluation/test_final_response_match_v2.py \
    tests/unittests/evaluation/test_metric_evaluator_registry.py \
    tests/unittests/evaluation/test_response_evaluator.py \
    tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py \
    tests/unittests/evaluation/test_safety_evaluator.py \
    tests/unittests/evaluation/test_trajectory_evaluator.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the test files to their original state
git checkout 07bb1647588a781e701257c4c379736537029ea0 \
    "tests/unittests/evaluation/test_final_response_match_v1.py" \
    "tests/unittests/evaluation/test_final_response_match_v2.py" \
    "tests/unittests/evaluation/test_metric_evaluator_registry.py" \
    "tests/unittests/evaluation/test_response_evaluator.py" \
    "tests/unittests/evaluation/test_rubric_based_tool_use_quality_v1.py" \
    "tests/unittests/evaluation/test_safety_evaluator.py" \
    "tests/unittests/evaluation/test_trajectory_evaluator.py"