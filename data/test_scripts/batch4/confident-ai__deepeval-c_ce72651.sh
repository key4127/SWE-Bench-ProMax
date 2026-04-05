#!/bin/bash
set -uxo pipefail
cd /testbed

# Ensure environment variables are set
export DEEPEVAL_TELEMETRY_OPT_OUT=1
export DEEPEVAL_DEBUG_ASYNC=1
export PYTHONFAULTHANDLER=1
export PYTHONASYNCIODEBUG=1
export PYTHONUNBUFFERED=1
export DEEPEVAL_DISABLE_DOTENV=1

# Checkout the original test files to ensure clean state
git checkout 372bf48c7780a48a046917db1ac2080ffe202aec "tests/test_core/test_models/test_amazon_bedrock_param_translation.py" "tests/test_core/test_models/test_bedrock_retry_config.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_core/test_models/test_amazon_bedrock_param_translation.py b/tests/test_core/test_models/test_amazon_bedrock_param_translation.py
--- a/tests/test_core/test_models/test_amazon_bedrock_param_translation.py
+++ b/tests/test_core/test_models/test_amazon_bedrock_param_translation.py
@@ -64,7 +64,7 @@ def test_various_generation_kwargs_passed_through(gen_kwargs):
         assert inf_cfg[key] == value
 
 
-def test_get_model_name_returns_model_id():
+def test_get_model_name_returns_name():
     model = _mk_model({})
-    model.model_id = "my-model"
+    model.name = "my-model"
     assert model.get_model_name() == "my-model"
diff --git a/tests/test_core/test_models/test_bedrock_retry_config.py b/tests/test_core/test_models/test_bedrock_retry_config.py
--- a/tests/test_core/test_models/test_bedrock_retry_config.py
+++ b/tests/test_core/test_models/test_bedrock_retry_config.py
@@ -1,3 +1,6 @@
+from types import SimpleNamespace
+from unittest.mock import patch
+
 import deepeval.models.llms.amazon_bedrock_model as mod
 
 
@@ -46,51 +49,70 @@ def test_bedrock_retry_predicate_present():
         make_is_transient,
     )
 
+    # If botocore isn't installed, the Bedrock policy is None and we skip.
     if BEDROCK_ERROR_POLICY is None:
-        return  # botocore not installed in this env, then skip
-    pred = make_is_transient(BEDROCK_ERROR_POLICY)
+        return
 
-    # throttling by message: should retry
-    class ClientError(Exception): ...
+    # Only import botocore when we know it's available.
+    from botocore.exceptions import ClientError
+
+    pred = make_is_transient(BEDROCK_ERROR_POLICY)
 
-    assert (
-        pred(
-            ClientError(
-                "An error occurred (ThrottlingException) when calling Converse: Rate exceeded"
-            )
-        )
-        is True
+    # ThrottlingException should be treated as retriable.
+    throttling_exc = ClientError(
+        error_response={
+            "Error": {
+                "Code": "ThrottlingException",
+                "Message": "Rate exceeded",
+            }
+        },
+        operation_name="Converse",
     )
-    # accessDenied: should NOT retry
-    assert (
-        pred(
-            ClientError(
-                "An error occurred (AccessDeniedException) when calling Converse: Access denied"
-            )
-        )
-        is False
+    assert pred(throttling_exc) is True
+
+    # AccessDeniedException: should not be retried.
+    access_denied_exc = ClientError(
+        error_response={
+            "Error": {
+                "Code": "AccessDeniedException",
+                "Message": "Access denied",
+            }
+        },
+        operation_name="Converse",
     )
+    assert pred(access_denied_exc) is False
 
 
-def test_bedrock_sdk_toggle(monkeypatch):
-    from deepeval.config.settings import get_settings
+@patch("deepeval.models.llms.amazon_bedrock_model.require_dependency")
+def test_bedrock_sdk_toggle(mock_require_dep, settings):
 
     # fake session instance so we can inspect its state
     sess = DummySession()
 
-    # fake aiobotocore availability and configure module to use our fakes
-    monkeypatch.setattr(mod, "aiobotocore_available", True)
-    monkeypatch.setattr(mod, "get_session", lambda: sess, raising=False)
-    monkeypatch.setattr(mod, "Config", DummyConfig, raising=False)
+    # Fake modules returned by require_dependency inside AmazonBedrockModel
+    fake_aiobotocore_session_module = SimpleNamespace(
+        get_session=lambda: sess,
+    )
+
+    class DummyBotocoreModule:
+        class config:
+            Config = DummyConfig
+
+    def fake_require_dependency(name, provider_label=None, install_hint=None):
+        if name == "aiobotocore.session":
+            return fake_aiobotocore_session_module
+        if name == "botocore":
+            return DummyBotocoreModule
+        raise AssertionError(f"Unexpected dependency requested: {name}")
 
-    # use settings.edit() so the runtime toggle takes effect
-    s = get_settings()
+    # Patch the require_dependency used by amazon_bedrock_model
+    mock_require_dep.side_effect = fake_require_dependency
 
     # SDK control ON means adaptive mode, max_attempts=5
-    with s.edit(persist=False):
-        s.DEEPEVAL_SDK_RETRY_PROVIDERS = ["bedrock"]
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_SDK_RETRY_PROVIDERS = ["bedrock"]
 
-    m = mod.AmazonBedrockModel(model_id="id", region_name="us-east-1")
+    m = mod.AmazonBedrockModel(model="id", region_name="us-east-1")
     # triggers client build
     m.generate("ping")
     assert m._sdk_retry_mode is True
@@ -99,8 +121,8 @@ def test_bedrock_sdk_toggle(monkeypatch):
     assert sess.last_config.retries.get("mode") == "adaptive"
 
     # flip to Tenacity control, expect max_attempts=1
-    with s.edit(persist=False):
-        s.DEEPEVAL_SDK_RETRY_PROVIDERS = []
+    with settings.edit(persist=False):
+        settings.DEEPEVAL_SDK_RETRY_PROVIDERS = []
 
     # Next call should rebuild the client with new retry config
     m.generate("ping2")
EOF_114329324912

# Run the target test files using poetry run pytest
# Using single-process mode for stability in virtualized environment
# Exclude tests marked with 'skip_test' marker as per project configuration
poetry run pytest -vv -rA --maxfail=1 --capture=tee-sys -m "not skip_test" \
    tests/test_core/test_models/test_amazon_bedrock_param_translation.py \
    tests/test_core/test_models/test_bedrock_retry_config.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 372bf48c7780a48a046917db1ac2080ffe202aec "tests/test_core/test_models/test_amazon_bedrock_param_translation.py" "tests/test_core/test_models/test_bedrock_retry_config.py"