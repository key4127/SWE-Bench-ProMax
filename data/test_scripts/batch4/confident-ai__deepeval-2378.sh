#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files
git checkout 797a70d2e0d0639e53399d96fcab45ee2bde9808 "tests/test_core/test_models/test_azure_model.py" "tests/test_core/test_models/test_azure_retry_config.py" "tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_core/test_models/test_azure_model.py b/tests/test_core/test_models/test_azure_model.py
--- a/tests/test_core/test_models/test_azure_model.py
+++ b/tests/test_core/test_models/test_azure_model.py
@@ -90,7 +90,7 @@ def test_generate_with_generation_kwargs(self, mock_load_model):
             model="gpt-4.1",
             api_key="test-key",
             base_url="test-endpoint",
-            openai_api_version="2024-02-15-preview",
+            api_version="2024-02-15-preview",
             generation_kwargs={"max_tokens": 1000, "top_p": 0.9},
         )
 
@@ -130,7 +130,7 @@ def test_generate_without_generation_kwargs(self, mock_load_model):
             model="gpt-4.1",
             api_key="test-key",
             base_url="test-endpoint",
-            openai_api_version="2024-02-15-preview",
+            api_version="2024-02-15-preview",
         )
 
         # Call generate without generation_kwargs
@@ -160,7 +160,7 @@ def test_load_model_passes_kwargs_to_client(self, mock_azure_openai):
             model="gpt-4.1",
             api_key="test-key",
             base_url="test-endpoint",
-            openai_api_version="2024-02-15-preview",
+            api_version="2024-02-15-preview",
             timeout=30,
             max_retries=5,  # user-provided, but we should override it to 0
         )
@@ -326,7 +326,7 @@ def test_azure_openai_model_ctor_args_override_settings(monkeypatch, settings):
         deployment_name="ctor-deployment",
         model="ctor-model",
         api_key="ctor-secret-key",
-        openai_api_version="2099-01-01-preview",
+        api_version="2099-01-01-preview",
         base_url="https://ctor-endpoint",
     )
 
diff --git a/tests/test_core/test_models/test_azure_retry_config.py b/tests/test_core/test_models/test_azure_retry_config.py
--- a/tests/test_core/test_models/test_azure_retry_config.py
+++ b/tests/test_core/test_models/test_azure_retry_config.py
@@ -36,7 +36,7 @@ def test_azure_sdk_retries_disabled(monkeypatch):
         deployment_name="dummy",
         model="gpt-4o-mini",
         api_key="x",
-        openai_api_version="2024-02-01",
+        api_version="2024-02-01",
         base_url="https://example",
         max_retries=5,
     )
@@ -90,7 +90,7 @@ def test_azure_sdk_retries_opt_in_respects_user_max_retries(settings):
         deployment_name="dummy",
         model="gpt-4o-mini",
         api_key="x",
-        openai_api_version="2024-02-01",
+        api_version="2024-02-01",
         base_url="https://example",
         max_retries=5,  # should be honored when SDK retries are enabled
     )
diff --git a/tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py b/tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py
--- a/tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py
+++ b/tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py
@@ -40,7 +40,7 @@ def test_azure_embedding_model_uses_explicit_params_over_settings_and_strips_sec
     # Explicit ctor args should override everything from Settings
     model = AzureOpenAIEmbeddingModel(
         api_key="ctor-secret-key",
-        openai_api_version="2099-01-01-preview",
+        api_version="2099-01-01-preview",
         base_url="https://ctor-endpoint",
         deployment_name="ctor-deployment",
         model="ctor-model",
EOF_114329324912

# Ensure all required environment variables are set (already set in Dockerfile, but verify)
export DEEPEVAL_TELEMETRY_OPT_OUT=1
export DEEPEVAL_DISABLE_DOTENV=1
export AZURE_OPENAI_API_KEY=dummy_key
export AZURE_OPENAI_ENDPOINT=https://dummy.openai.azure.com/
export AZURE_DEPLOYMENT_NAME=dummy_deployment
export AZURE_EMBEDDING_DEPLOYMENT_NAME=dummy_embedding_deployment
export AZURE_MODEL_NAME=gpt-4
export OPENAI_API_VERSION=2024-02-15-preview

# Run the target test files using Poetry
# Using pytest with verbose output and single-process mode for stability
poetry run pytest -vv -rA --maxfail=1 --capture=tee-sys \
    tests/test_core/test_models/test_azure_model.py \
    tests/test_core/test_models/test_azure_retry_config.py \
    tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py

# Capture exit code
rc=$?

# Echo exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout 797a70d2e0d0639e53399d96fcab45ee2bde9808 "tests/test_core/test_models/test_azure_model.py" "tests/test_core/test_models/test_azure_retry_config.py" "tests/test_core/test_models/test_embedding_models/test_azure_embedding_model.py"