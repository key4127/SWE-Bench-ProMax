#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 9cde97bb2a7f8e65d48ff380a4869a82b27ad99a ".github/workflows/full_test_core_for_pr.yml" "tests/test_core/conftest.py" "tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py" "tests/test_core/test_models/test_openai_retry_policy.py" "tests/test_core/test_retry_policy.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/.github/workflows/full_test_core_for_pr.yml b/.github/workflows/full_test_core_for_pr.yml
--- a/.github/workflows/full_test_core_for_pr.yml
+++ b/.github/workflows/full_test_core_for_pr.yml
@@ -29,7 +29,6 @@ jobs:
       DEEPEVAL_TELEMETRY_OPT_OUT: 1
       DEEPEVAL_DEBUG_ASYNC: 1
       LOG_LEVEL: "info"
-      DEEPEVAL_PER_TASK_TIMEOUT_SECONDS: 240
       DEEPEVAL_PER_TASK_TIMEOUT_SECONDS_OVERRIDE: 240
       PYTHONFAULTHANDLER: "1"
       PYTHONASYNCIODEBUG: "1"
diff --git a/tests/test_core/conftest.py b/tests/test_core/conftest.py
--- a/tests/test_core/conftest.py
+++ b/tests/test_core/conftest.py
@@ -11,6 +11,7 @@
 import tenacity
 
 from pathlib import Path
+from deepeval.config.settings import get_settings, reset_settings
 
 
 @pytest.fixture(autouse=True)
@@ -52,3 +53,19 @@ def hidden_store_dir(tmp_path: Path) -> Path:
 @pytest.fixture(autouse=True)
 def no_sleep(monkeypatch):
     monkeypatch.setattr(tenacity.nap, "sleep", lambda _: None, raising=True)
+
+
+@pytest.fixture()
+def settings():
+    settings = get_settings()
+    yield settings
+
+
+@pytest.fixture(autouse=True)
+def settings_reset():
+    reset_settings()
+
+
+@pytest.fixture()
+def settings_reload():
+    reset_settings(reload_dotenv=True)
diff --git a/tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py b/tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py
--- a/tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py
+++ b/tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py
@@ -6,62 +6,52 @@
     a_execute_agentic_test_cases,
 )
 from deepeval.dataset import Golden
-from deepeval.config.settings import get_settings
 
 
-def test_observed_callback_times_out_sync_path(monkeypatch):
+def test_observed_callback_times_out_sync_path(monkeypatch, settings):
     """
     Ensures async observed_callback in the sync path is bounded by
     DEEPEVAL_PER_TASK_TIMEOUT_SECONDS and raises asyncio.TimeoutError.
     """
-    settings = get_settings()
-    original = settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS
-    try:
+    with settings.edit(persist=False):
         # Make the timeout tiny so the test is fast
-        settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS = 1
+        settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS_OVERRIDE = 1
 
-        async def slow_callback(_):
-            # Sleep well past the configured timeout
-            await asyncio.sleep(5)
+    async def slow_callback(_):
+        # Sleep well past the configured timeout
+        await asyncio.sleep(5)
 
-        goldens = [Golden(input="hello")]
+    goldens = [Golden(input="hello")]
 
-        with pytest.raises(asyncio.TimeoutError):
-            execute_agentic_test_cases(
-                goldens=goldens,
-                observed_callback=slow_callback,
-            )
-    finally:
-        # restore global setting to avoid leaking to other tests
-        settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS = original
+    with pytest.raises(asyncio.TimeoutError):
+        execute_agentic_test_cases(
+            goldens=goldens,
+            observed_callback=slow_callback,
+        )
 
 
 @pytest.mark.asyncio
-async def test_observed_callback_times_out_async_path(monkeypatch):
+async def test_observed_callback_times_out_async_path(monkeypatch, settings):
     """
     Ensures async observed_callback in the async path is bounded by
     DEEPEVAL_PER_TASK_TIMEOUT_SECONDS and raises asyncio.TimeoutError.
     """
-    settings = get_settings()
-    original = settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS
-    try:
+
+    with settings.edit(persist=False):
         # Make the timeout tiny so the test is fast
-        settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS = 1
-
-        async def slow_callback(_):
-            # Sleep well past the configured timeout
-            await asyncio.sleep(5)
-
-        goldens = [Golden(input="hello")]
-
-        with pytest.raises(asyncio.TimeoutError):
-            await a_execute_agentic_test_cases(
-                goldens=goldens,
-                observed_callback=slow_callback,
-            )
-    finally:
-        # restore global setting to avoid leaking to other tests
-        settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS = original
+        settings.DEEPEVAL_PER_TASK_TIMEOUT_SECONDS_OVERRIDE = 1
+
+    async def slow_callback(_):
+        # Sleep well past the configured timeout
+        await asyncio.sleep(5)
+
+    goldens = [Golden(input="hello")]
+
+    with pytest.raises(asyncio.TimeoutError):
+        await a_execute_agentic_test_cases(
+            goldens=goldens,
+            observed_callback=slow_callback,
+        )
 
 
 def test_observed_callback_sync_callback_unaffected():
diff --git a/tests/test_core/test_models/test_openai_retry_policy.py b/tests/test_core/test_models/test_openai_retry_policy.py
--- a/tests/test_core/test_models/test_openai_retry_policy.py
+++ b/tests/test_core/test_models/test_openai_retry_policy.py
@@ -61,7 +61,7 @@ def _fake_loader(self, async_mode=False):
 
 
 @pytest.fixture
-def gpt_model_length_limit(monkeypatch):
+def gpt_model_length_limit(monkeypatch, settings):
     # Use a local dummy class to stand in for the SDK error (keeps test stable across SDK versions).
     class DummyLengthFinishReasonError(Exception):
         pass
@@ -85,18 +85,20 @@ class DummySchema(BaseModel):
     def _fake_loader(self, async_mode=False):
         return AlwaysLengthLimitClient(counter)
 
-    monkeypatch.setenv(
-        "DEEPEVAL_RETRY_MAX_ATTEMPTS", "5"
-    )  # big number to prove we don't retry
-    monkeypatch.setenv(
-        "DEEPEVAL_RETRY_CAP_SECONDS", "0"
-    )  # speed up, no waiting
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_RETRY_MAX_ATTEMPTS = 5
+        settings.DEEPEVAL_RETRY_CAP_SECONDS = 0
+
     monkeypatch.setattr(GPTModel, "load_model", _fake_loader, raising=True)
     return GPTModel(model="gpt-4o-mini"), counter
 
 
-def test_retry_respects_max_attempts(monkeypatch, gpt_model_retryable):
-    monkeypatch.setenv("DEEPEVAL_RETRY_MAX_ATTEMPTS", "4")
+def test_retry_respects_max_attempts(
+    monkeypatch, gpt_model_retryable, settings
+):
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_RETRY_MAX_ATTEMPTS = 4
+
     gpt, counter = gpt_model_retryable
 
     with pytest.raises(RetryError) as excinfo:
diff --git a/tests/test_core/test_retry_policy.py b/tests/test_core/test_retry_policy.py
--- a/tests/test_core/test_retry_policy.py
+++ b/tests/test_core/test_retry_policy.py
@@ -1,9 +1,10 @@
+import logging
 import pytest
 import tenacity
-import logging
+import time
+
 
 from deepeval.models import retry_policy as rp
-from deepeval.config.settings import get_settings
 from deepeval.models.retry_policy import (
     create_retry_decorator,
     dynamic_wait,
@@ -293,8 +294,10 @@ def test_dynamic_wait_callable(monkeypatch):
     assert callable(w)
 
 
-def test_dynamic_wait_zeros_with_env(monkeypatch):
-    monkeypatch.setenv("DEEPEVAL_RETRY_CAP_SECONDS", "0")
+def test_dynamic_wait_zeros_with_env(monkeypatch, settings):
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_RETRY_CAP_SECONDS = 0
+
     w = dynamic_wait()
 
     class RS:  # minimal retry state shape
@@ -313,7 +316,7 @@ def test_dynamic_stop_callable():
 ##############################################
 
 
-def test_retry_respects_max_attempts_env(monkeypatch, policy):
+def test_retry_respects_max_attempts_env(monkeypatch, policy, settings):
     slug = "max_attempts"
     monkeypatch.setitem(rp._POLICY_BY_SLUG, slug, policy)
     monkeypatch.setitem(
@@ -333,15 +336,20 @@ def flaky_twice_then_ok():
             raise NetTimeout()
         return "ok"
 
-    monkeypatch.setenv("DEEPEVAL_RETRY_MAX_ATTEMPTS", "2")
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_RETRY_MAX_ATTEMPTS = 2
+
     with pytest.raises(tenacity.RetryError):
         flaky_twice_then_ok()
     assert calls["n"] == 2  # stopped at the cap
 
     # Case 2
     # allow 3 attempts, now it can succeed on the 3rd call because cap was increased
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_RETRY_MAX_ATTEMPTS = 3
+
     calls["n"] = 0
-    monkeypatch.setenv("DEEPEVAL_RETRY_MAX_ATTEMPTS", "3")
+
     assert flaky_twice_then_ok() == "ok"
     assert calls["n"] == 3
 
@@ -422,11 +430,10 @@ def test_get_retry_policy_for_respects_sdk_retries_for(monkeypatch, policy):
     assert get_retry_policy_for(slug) is None
 
 
-def test_sdk_retries_for_wildcard(monkeypatch):
-    settings = get_settings()
-    monkeypatch.setattr(
-        settings, "DEEPEVAL_SDK_RETRY_PROVIDERS", ["*"], raising=False
-    )
+def test_sdk_retries_for_wildcard(monkeypatch, settings):
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_SDK_RETRY_PROVIDERS = ["*"]
+
     assert sdk_retries_for("anything") is True
     assert sdk_retries_for("azure") is True
 
@@ -511,12 +518,77 @@ def boom():
     assert calls["seen"] == 0  # never consulted
 
 
+def test_sync_timeout_is_retryable_and_capped(monkeypatch, policy, settings):
+    slug = "openai"
+    monkeypatch.setitem(rp._POLICY_BY_SLUG, slug, policy)
+    monkeypatch.setitem(
+        rp._STATIC_PRED_BY_SLUG, slug, make_is_transient(policy)
+    )
+
+    calls = {"n": 0}
+
+    @create_retry_decorator(slug)
+    def slow():
+        calls["n"] += 1
+        time.sleep(0.05)  # longer than per-attempt timeout
+
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_HTTP_TIMEOUT_SECONDS = (
+            0.01  # force per-attempt timeout
+        )
+        settings.DEEPEVAL_RETRY_MAX_ATTEMPTS = 3
+        settings.DEEPEVAL_RETRY_CAP_SECONDS = 0  # keep the test fast
+
+    with pytest.raises(tenacity.RetryError):
+        slow()
+
+    # We should have hit the cap: 1 initial + (max_attempts-1) retries => attempts == 3
+    assert calls["n"] == 3
+
+
+def test_dynamic_toggle_sdk_retries_runtime(monkeypatch, policy, settings):
+    slug = "openai"
+    # register policy + static predicate
+    monkeypatch.setitem(rp._POLICY_BY_SLUG, slug, policy)
+    monkeypatch.setitem(
+        rp._STATIC_PRED_BY_SLUG, slug, make_is_transient(policy)
+    )
+
+    calls = {"n": 0}
+
+    @create_retry_decorator(slug)
+    def flaky():
+        calls["n"] += 1
+        raise NetTimeout()
+
+    # SDK off -> Tenacity should retry up to cap
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_SDK_RETRY_PROVIDERS = []
+        settings.DEEPEVAL_RETRY_MAX_ATTEMPTS = 3
+        settings.DEEPEVAL_RETRY_CAP_SECONDS = 0
+
+    with pytest.raises(tenacity.RetryError):
+        flaky()
+    assert calls["n"] == 3
+
+    # SDK on -> no retries; same wrapped function
+    calls["n"] = 0
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_SDK_RETRY_PROVIDERS = ["openai"]  # on for this slug
+
+    with pytest.raises(NetTimeout):
+        flaky()
+    assert calls["n"] == 1
+
+
 ###############
 # Diagnostics #
 ###############
 
 
-def test_retry_logging_levels_change_at_runtime(monkeypatch, caplog, policy):
+def test_retry_logging_levels_change_at_runtime(
+    monkeypatch, caplog, policy, settings
+):
     slug = "log_levels"
     monkeypatch.setitem(rp._POLICY_BY_SLUG, slug, policy)
     monkeypatch.setitem(
@@ -528,8 +600,6 @@ def test_retry_logging_levels_change_at_runtime(monkeypatch, caplog, policy):
     def boom():
         raise NetTimeout()
 
-    settings = get_settings()
-
     # Before: WARNING for before-sleep, ERROR for after
     with settings.edit(persist=False):
         settings.DEEPEVAL_RETRY_BEFORE_LOG_LEVEL = logging.WARNING
@@ -568,9 +638,3 @@ def boom():
     assert not any(r.levelno >= logging.ERROR for r in caplog.records)
     assert not any(r.levelno == logging.WARNING for r in caplog.records)
     assert all(r.exc_info is None for r in caplog.records)
-
-    # turn the logging back down.
-    # TODO remove this once we can properly reset settings in tests
-    with settings.edit(persist=False):
-        settings.DEEPEVAL_RETRY_BEFORE_LOG_LEVEL = logging.WARNING
-        settings.DEEPEVAL_RETRY_AFTER_LOG_LEVEL = logging.ERROR
EOF_114329324912

# Activate Poetry virtual environment
source /testbed/.venv/bin/activate

# Verify environment is activated
which python
python --version
poetry --version

# Export all required environment variables (redundant but ensures they're set)
export OPENAI_API_KEY=dummy_key
export DEEPEVAL_TELEMETRY_OPT_OUT=1
export DEEPEVAL_DEBUG_ASYNC=1
export LOG_LEVEL=info
export DEEPEVAL_PER_TASK_TIMEOUT_SECONDS=240
export DEEPEVAL_PER_TASK_TIMEOUT_SECONDS_OVERRIDE=240
export PYTHONFAULTHANDLER=1
export PYTHONASYNCIODEBUG=1
export PYTHONUNBUFFERED=1

# Execute the target test files using Poetry
# Combining all test files into a single command for efficiency
# Using verbose flags and capturing detailed output
poetry run pytest \
    tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py \
    tests/test_core/test_models/test_openai_retry_policy.py \
    tests/test_core/test_retry_policy.py \
    -vv \
    -rA \
    --maxfail=1 \
    --capture=tee-sys \
    --durations=25 \
    -o log_cli=true \
    -o log_cli_level=INFO \
    --log-cli-format="%(asctime)s %(levelname)s [%(name)s] %(message)s"

# Capture the exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files to clean up
git checkout 9cde97bb2a7f8e65d48ff380a4869a82b27ad99a ".github/workflows/full_test_core_for_pr.yml" "tests/test_core/conftest.py" "tests/test_core/test_evaluation/test_execute/test_observed_callback_timeout.py" "tests/test_core/test_models/test_openai_retry_policy.py" "tests/test_core/test_retry_policy.py"

# Exit with the captured return code
exit $rc