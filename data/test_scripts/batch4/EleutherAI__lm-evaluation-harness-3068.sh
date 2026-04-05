#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 584de690f3a753a00d27fd0bf97d2adc1f31b4e8 "tests/test_include_path.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_include_path.py b/tests/test_include_path.py
--- a/tests/test_include_path.py
+++ b/tests/test_include_path.py
@@ -1,93 +1,186 @@
 import os
 
-import pytest
-
-import lm_eval.api as api
-import lm_eval.evaluator as evaluator
 from lm_eval import tasks
 
 
-@pytest.mark.parametrize(
-    "limit,model,model_args",
-    [
-        (
-            10,
-            "hf",
-            "pretrained=EleutherAI/pythia-160m,dtype=float32,device=cpu",
-        ),
-    ],
-)
-def test_include_correctness(limit: int, model: str, model_args: str):
-    task_name = ["arc_easy"]
-
-    task_manager = tasks.TaskManager()
-    task_dict = tasks.get_task_dict(task_name, task_manager)
-
-    e1 = evaluator.simple_evaluate(
-        model=model,
-        tasks=task_name,
-        limit=limit,
-        model_args=model_args,
-    )
-    assert e1 is not None
-
-    # run with evaluate() and "arc_easy" test config (included from ./testconfigs path)
-    lm = api.registry.get_model(model).create_from_arg_string(
-        model_args,
-        {
-            "batch_size": None,
-            "max_batch_size": None,
-            "device": None,
-        },
-    )
-
-    task_name = ["arc_easy"]
-
-    task_manager = tasks.TaskManager(
-        include_path=os.path.dirname(os.path.abspath(__file__)) + "/testconfigs",
-        include_defaults=False,
-    )
-    task_dict = tasks.get_task_dict(task_name, task_manager)
-
-    e2 = evaluator.evaluate(
-        lm=lm,
-        task_dict=task_dict,
-        limit=limit,
-    )
-
-    assert e2 is not None
-    # check that caching is working
-
-    def r(x):
-        return x["results"]["arc_easy"]
-
-    assert all(
-        x == y
-        for x, y in zip([y for _, y in r(e1).items()], [y for _, y in r(e2).items()])
-    )
-
-
-# test that setting include_defaults = False works as expected and that include_path works
-def test_no_include_defaults():
-    task_name = ["arc_easy"]
-
-    task_manager = tasks.TaskManager(
-        include_path=os.path.dirname(os.path.abspath(__file__)) + "/testconfigs",
-        include_defaults=False,
-    )
-    # should succeed, because we've included an 'arc_easy' task from this dir
-    task_dict = tasks.get_task_dict(task_name, task_manager)
-
-    # should fail, since ./testconfigs has no arc_challenge task
-    task_name = ["arc_challenge"]
-    with pytest.raises(KeyError):
-        task_dict = tasks.get_task_dict(task_name, task_manager)  # noqa: F841
-
-
-# test that include_path containing a task shadowing another task's name fails
-# def test_shadowed_name_fails():
-
-#     task_name = ["arc_easy"]
-
-#     task_manager = tasks.TaskManager(include_path=os.path.dirname(os.path.abspath(__file__)) + "/testconfigs")
-#     task_dict = tasks.get_task_dict(task_name, task_manager)
+def test_include_path_precedence():
+    """Test that user-specified include paths take precedence over default paths when tasks have the same name."""
+    import tempfile
+
+    # Create a temporary directory for our custom task
+    with tempfile.TemporaryDirectory() as custom_dir:
+        # Create a custom arc_easy.yaml that has a different metric
+        custom_task_content = """task: arc_easy
+dataset_path: allenai/ai2_arc
+dataset_name: ARC-Easy
+output_type: multiple_choice
+training_split: train
+validation_split: validation
+test_split: test
+doc_to_text: "Custom Question: {{question}}\\nAnswer:"
+doc_to_target: "{{choices.label.index(answerKey)}}"
+doc_to_choice: "{{choices.text}}"
+metric_list:
+  - metric: f1
+    aggregation: mean
+    higher_is_better: true
+metadata:
+  version: 2.0
+  custom: true
+"""
+
+        # Write the custom task file
+        custom_task_path = os.path.join(custom_dir, "arc_easy.yaml")
+        with open(custom_task_path, "w") as f:
+            f.write(custom_task_content)
+
+        # Test 1: User path should override default when include_defaults=True
+        task_manager = tasks.TaskManager(include_defaults=True, include_path=custom_dir)
+
+        # Load the task
+        task_dict = task_manager.load_task_or_group(["arc_easy"])
+        arc_easy_task = task_dict["arc_easy"]
+
+        # Check that the custom version was loaded (has f1 metric and custom doc_to_text)
+        assert any(
+            metric["metric"] == "f1" for metric in arc_easy_task.config["metric_list"]
+        ), "Custom task should have f1 metric"
+        assert "Custom Question:" in arc_easy_task.config["doc_to_text"], (
+            "Custom task should have custom doc_to_text"
+        )
+        assert arc_easy_task.config["metadata"]["version"] == 2.0, (
+            "Custom task should have version 2.0"
+        )
+
+        # Test 2: Verify default is used when no custom path is provided
+        default_task_manager = tasks.TaskManager(include_defaults=True)
+        default_task_dict = default_task_manager.load_task_or_group(["arc_easy"])
+        default_arc_easy = default_task_dict["arc_easy"]
+
+        # Default should not have f1 metric or custom text
+        assert not any(
+            metric["metric"] == "f1"
+            for metric in default_arc_easy.config.get("metric_list", [])
+        ), "Default task should not have f1 metric"
+        assert "Custom Question:" not in default_arc_easy.config["doc_to_text"], (
+            "Default task should not have custom doc_to_text"
+        )
+
+
+def test_include_defaults_false_with_custom_path():
+    """Test that when include_defaults=False, only custom tasks are available."""
+    import tempfile
+
+    with tempfile.TemporaryDirectory() as custom_dir:
+        # Create a custom task using a real dataset
+        custom_task_content = """task: custom_arc_task
+dataset_path: allenai/ai2_arc
+dataset_name: ARC-Challenge
+output_type: multiple_choice
+training_split: train
+validation_split: validation
+test_split: test
+doc_to_text: "Q: {{question}}\nA:"
+doc_to_target: "{{choices.label.index(answerKey)}}"
+doc_to_choice: "{{choices.text}}"
+metric_list:
+  - metric: acc
+    aggregation: mean
+    higher_is_better: true
+metadata:
+  version: 1.0
+  custom: true
+"""
+
+        # Write the custom task file
+        custom_task_path = os.path.join(custom_dir, "custom_arc_task.yaml")
+        with open(custom_task_path, "w") as f:
+            f.write(custom_task_content)
+
+        # Initialize with include_defaults=False
+        task_manager = tasks.TaskManager(
+            include_defaults=False, include_path=custom_dir
+        )
+
+        # Custom task should be available
+        assert "custom_arc_task" in task_manager.all_tasks, (
+            "Custom task should be available when include_defaults=False"
+        )
+
+        # Default tasks should NOT be available
+        assert "arc_easy" not in task_manager.all_tasks, (
+            "Default arc_easy should not be available when include_defaults=False"
+        )
+        assert "arc_challenge" not in task_manager.all_tasks, (
+            "Default arc_challenge should not be available when include_defaults=False"
+        )
+
+        # Check that only our custom task is present
+        assert len(task_manager.all_tasks) == 1, (
+            f"Should only have 1 task, but found {len(task_manager.all_tasks)}"
+        )
+
+        # Check task metadata is correctly loaded
+        task_info = task_manager.task_index["custom_arc_task"]
+        assert task_info["type"] == "task"
+        assert custom_dir in task_info["yaml_path"]
+
+
+def test_include_defaults_true_with_new_tasks():
+    """Test that new tasks from include_path are added alongside default tasks."""
+    import tempfile
+
+    with tempfile.TemporaryDirectory() as custom_dir:
+        # Create a completely new task (not overriding any default)
+        new_task_content = """task: arc_custom_generation
+dataset_path: allenai/ai2_arc
+dataset_name: ARC-Easy
+output_type: generate_until
+training_split: train
+validation_split: validation
+test_split: test
+doc_to_text: "Question: {{question}}\nGenerate answer:"
+doc_to_target: "{{choices.text[choices.label.index(answerKey)]}}"
+generation_kwargs:
+  max_gen_toks: 50
+  temperature: 0.1
+  until:
+    - "\n"
+metric_list:
+  - metric: exact_match
+    aggregation: mean
+    higher_is_better: true
+metadata:
+  version: 1.0
+  custom_benchmark: true
+"""
+
+        # Write the new task file
+        new_task_path = os.path.join(custom_dir, "arc_custom_generation.yaml")
+        with open(new_task_path, "w") as f:
+            f.write(new_task_content)
+
+        # Initialize with include_defaults=True (default behavior)
+        task_manager = tasks.TaskManager(include_defaults=True, include_path=custom_dir)
+
+        # Both custom and default tasks should be available
+        assert "arc_custom_generation" in task_manager.all_tasks, (
+            "New custom task should be available"
+        )
+        assert "arc_easy" in task_manager.all_tasks, (
+            "Default arc_easy should still be available"
+        )
+        assert "arc_challenge" in task_manager.all_tasks, (
+            "Default arc_challenge should still be available"
+        )
+
+        # Check task metadata
+        custom_task_info = task_manager.task_index["arc_custom_generation"]
+        assert custom_task_info["type"] == "task"
+        assert custom_dir in custom_task_info["yaml_path"]
+
+        # Verify the counts - should have more tasks than just defaults
+        default_only_manager = tasks.TaskManager(include_defaults=True)
+        assert len(task_manager.all_tasks) > len(default_only_manager.all_tasks), (
+            "Should have more tasks when including custom path"
+        )
EOF_114329324912

# Run the target test file
pytest tests/test_include_path.py -v --tb=short --no-header -rA
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 584de690f3a753a00d27fd0bf97d2adc1f31b4e8 "tests/test_include_path.py"