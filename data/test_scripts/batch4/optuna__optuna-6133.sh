#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout cd2fc0b4c08c1e4053306309c6d59b2328af6ddf "tests/study_tests/test_optimize.py" "tests/study_tests/test_study.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/study_tests/test_optimize.py b/tests/study_tests/test_optimize.py
--- a/tests/study_tests/test_optimize.py
+++ b/tests/study_tests/test_optimize.py
@@ -39,19 +39,22 @@ def test_run_trial(storage_mode: str, caplog: LogCaptureFixture) -> None:
         study = create_study(storage=storage)
 
         caplog.clear()
-        frozen_trial = _optimize._run_trial(study, lambda _: 1.0, catch=())
+        frozen_trial_id = _optimize._run_trial(study, lambda _: 1.0, catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.COMPLETE
         assert frozen_trial.value == 1.0
         assert "Trial 0 finished with value: 1.0 and parameters" in caplog.text
 
         caplog.clear()
-        frozen_trial = _optimize._run_trial(study, lambda _: float("inf"), catch=())
+        frozen_trial_id = _optimize._run_trial(study, lambda _: float("inf"), catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.COMPLETE
         assert frozen_trial.value == float("inf")
         assert "Trial 1 finished with value: inf and parameters" in caplog.text
 
         caplog.clear()
-        frozen_trial = _optimize._run_trial(study, lambda _: -float("inf"), catch=())
+        frozen_trial_id = _optimize._run_trial(study, lambda _: -float("inf"), catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.COMPLETE
         assert frozen_trial.value == -float("inf")
         assert "Trial 2 finished with value: -inf and parameters" in caplog.text
@@ -62,19 +65,23 @@ def test_run_trial_automatically_fail(storage_mode: str, caplog: LogCaptureFixtu
     with StorageSupplier(storage_mode) as storage:
         study = create_study(storage=storage)
 
-        frozen_trial = _optimize._run_trial(study, lambda _: float("nan"), catch=())
+        frozen_trial_id = _optimize._run_trial(study, lambda _: float("nan"), catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.FAIL
         assert frozen_trial.value is None
 
-        frozen_trial = _optimize._run_trial(study, lambda _: None, catch=())  # type: ignore[arg-type,return-value] # noqa: E501
+        frozen_trial_id = _optimize._run_trial(study, lambda _: None, catch=())  # type: ignore[arg-type,return-value] # noqa: E501
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.FAIL
         assert frozen_trial.value is None
 
-        frozen_trial = _optimize._run_trial(study, lambda _: object(), catch=())  # type: ignore[arg-type,return-value] # noqa: E501
+        frozen_trial_id = _optimize._run_trial(study, lambda _: object(), catch=())  # type: ignore[arg-type,return-value] # noqa: E501
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.FAIL
         assert frozen_trial.value is None
 
-        frozen_trial = _optimize._run_trial(study, lambda _: [0, 1], catch=())
+        frozen_trial_id = _optimize._run_trial(study, lambda _: [0, 1], catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.FAIL
         assert frozen_trial.value is None
 
@@ -93,19 +100,24 @@ def func(trial: Trial) -> float:
         study = create_study(storage=storage)
 
         caplog.clear()
-        frozen_trial = _optimize._run_trial(study, gen_func(), catch=())
+        frozen_trial_id = _optimize._run_trial(study, gen_func(), catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.PRUNED
         assert frozen_trial.value is None
         assert "Trial 0 pruned." in caplog.text
 
         caplog.clear()
-        frozen_trial = _optimize._run_trial(study, gen_func(intermediate=1), catch=())
+        frozen_trial_id = _optimize._run_trial(study, gen_func(intermediate=1), catch=())
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.PRUNED
         assert frozen_trial.value == 1
         assert "Trial 1 pruned." in caplog.text
 
         caplog.clear()
-        frozen_trial = _optimize._run_trial(study, gen_func(intermediate=float("nan")), catch=())
+        frozen_trial_id = _optimize._run_trial(
+            study, gen_func(intermediate=float("nan")), catch=()
+        )
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.PRUNED
         assert frozen_trial.value is None
         assert "Trial 2 pruned." in caplog.text
@@ -115,7 +127,8 @@ def func(trial: Trial) -> float:
 def test_run_trial_catch_exception(storage_mode: str) -> None:
     with StorageSupplier(storage_mode) as storage:
         study = create_study(storage=storage)
-        frozen_trial = _optimize._run_trial(study, fail_objective, catch=(ValueError,))
+        frozen_trial_id = _optimize._run_trial(study, fail_objective, catch=(ValueError,))
+        frozen_trial = study._storage.get_trial(frozen_trial_id)
         assert frozen_trial.state == TrialState.FAIL
 
 
diff --git a/tests/study_tests/test_study.py b/tests/study_tests/test_study.py
--- a/tests/study_tests/test_study.py
+++ b/tests/study_tests/test_study.py
@@ -1150,17 +1150,17 @@ def test_log_completed_trial_skip_storage_access() -> None:
     storage = study._storage
 
     with patch.object(storage, "get_best_trial", wraps=storage.get_best_trial) as mock_object:
-        study._log_completed_trial(frozen_trial)
+        study._log_completed_trial(frozen_trial.values, frozen_trial.number, frozen_trial.params)
         assert mock_object.call_count == 1
 
     logging.set_verbosity(logging.WARNING)
     with patch.object(storage, "get_best_trial", wraps=storage.get_best_trial) as mock_object:
-        study._log_completed_trial(frozen_trial)
+        study._log_completed_trial(frozen_trial.values, frozen_trial.number, frozen_trial.params)
         assert mock_object.call_count == 0
 
     logging.set_verbosity(logging.DEBUG)
     with patch.object(storage, "get_best_trial", wraps=storage.get_best_trial) as mock_object:
-        study._log_completed_trial(frozen_trial)
+        study._log_completed_trial(frozen_trial.values, frozen_trial.number, frozen_trial.params)
         assert mock_object.call_count == 1
 
 
EOF_114329324912

# Set environment variable (already set in Dockerfile, but ensuring it's set)
export SQLALCHEMY_WARN_20=1

# Run the target test files
pytest tests/study_tests/test_optimize.py tests/study_tests/test_study.py -v --color=yes --tb=short
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout cd2fc0b4c08c1e4053306309c6d59b2328af6ddf "tests/study_tests/test_optimize.py" "tests/study_tests/test_study.py"