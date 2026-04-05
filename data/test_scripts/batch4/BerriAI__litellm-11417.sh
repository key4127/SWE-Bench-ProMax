#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 3cc94609226ae79572e1e8518fe561451eea63a7 "tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py b/tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py
--- a/tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py
+++ b/tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py
@@ -11,7 +11,7 @@
 
 from litellm.proxy._types import DefaultInternalUserParams, LitellmUserRoles
 from litellm.proxy.proxy_server import app
-from litellm.types.proxy.management_endpoints.ui_sso import DefaultTeamSSOParams
+from litellm.types.proxy.management_endpoints.ui_sso import DefaultTeamSSOParams, SSOConfig
 
 client = TestClient(app)
 
@@ -34,6 +34,16 @@ def mock_proxy_config(monkeypatch):
                 "tpm_limit": 100,
                 "rpm_limit": 10,
             },
+        },
+        "general_settings": {
+            "proxy_admin_email": "admin@example.com"
+        },
+        "environment_variables": {
+            "GOOGLE_CLIENT_ID": "test_google_client_id",
+            "GOOGLE_CLIENT_SECRET": "test_google_client_secret",
+            "MICROSOFT_CLIENT_ID": "test_microsoft_client_id",
+            "MICROSOFT_CLIENT_SECRET": "test_microsoft_client_secret",
+            "PROXY_BASE_URL": "https://example.com"
         }
     }
 
@@ -84,9 +94,9 @@ def test_get_internal_user_settings(self, mock_proxy_config, mock_auth):
         assert response.status_code == 200
         data = response.json()
 
-        # Check structure of response
+        # Check structure of response (updated to use field_schema)
         assert "values" in data
-        assert "schema" in data
+        assert "field_schema" in data
 
         # Check values match our mock config
         values = data["values"]
@@ -98,10 +108,10 @@ def test_get_internal_user_settings(self, mock_proxy_config, mock_auth):
         assert values["budget_duration"] == mock_params["budget_duration"]
         assert values["models"] == mock_params["models"]
 
-        # Check schema contains descriptions
-        assert "properties" in data["schema"]
-        assert "user_role" in data["schema"]["properties"]
-        assert "description" in data["schema"]["properties"]["user_role"]
+        # Check field_schema contains descriptions (updated from schema to field_schema)
+        assert "properties" in data["field_schema"]
+        assert "user_role" in data["field_schema"]["properties"]
+        assert "description" in data["field_schema"]["properties"]["user_role"]
 
     def test_update_internal_user_settings(
         self, mock_proxy_config, mock_auth, monkeypatch
@@ -153,9 +163,9 @@ def test_get_default_team_settings(self, mock_proxy_config, mock_auth):
         assert response.status_code == 200
         data = response.json()
 
-        # Check structure of response
+        # Check structure of response (updated to use field_schema)
         assert "values" in data
-        assert "schema" in data
+        assert "field_schema" in data
 
         # Check values match our mock config
         values = data["values"]
@@ -168,10 +178,10 @@ def test_get_default_team_settings(self, mock_proxy_config, mock_auth):
         assert values["tpm_limit"] == mock_params["tpm_limit"]
         assert values["rpm_limit"] == mock_params["rpm_limit"]
 
-        # Check schema contains descriptions
-        assert "properties" in data["schema"]
-        assert "models" in data["schema"]["properties"]
-        assert "description" in data["schema"]["properties"]["models"]
+        # Check field_schema contains descriptions (updated from schema to field_schema)
+        assert "properties" in data["field_schema"]
+        assert "models" in data["field_schema"]["properties"]
+        assert "description" in data["field_schema"]["properties"]["models"]
 
     def test_update_default_team_settings(
         self, mock_proxy_config, mock_auth, monkeypatch
@@ -218,3 +228,75 @@ def test_update_default_team_settings(
 
         # Verify save_config was called exactly once
         assert mock_proxy_config["save_call_count"]() == 1
+
+    def test_get_sso_settings(self, mock_proxy_config, mock_auth):
+        """Test getting the SSO settings"""
+        response = client.get("/get/sso_settings")
+
+        assert response.status_code == 200
+        data = response.json()
+
+        # Check structure of response
+        assert "values" in data
+        assert "field_schema" in data
+
+        # Check values contain SSO configuration
+        values = data["values"]
+        assert "google_client_id" in values
+        assert "google_client_secret" in values
+        assert "microsoft_client_id" in values
+        assert "microsoft_client_secret" in values
+        assert "proxy_base_url" in values
+        assert "user_email" in values
+
+        # Verify values match our mock config
+        assert values["google_client_id"] == "test_google_client_id"
+        assert values["google_client_secret"] == "test_google_client_secret"
+        assert values["microsoft_client_id"] == "test_microsoft_client_id"
+        assert values["microsoft_client_secret"] == "test_microsoft_client_secret"
+        assert values["proxy_base_url"] == "https://example.com"
+        assert values["user_email"] == "admin@example.com"
+
+        # Check field_schema contains descriptions
+        assert "properties" in data["field_schema"]
+        assert "google_client_id" in data["field_schema"]["properties"]
+        assert "description" in data["field_schema"]["properties"]["google_client_id"]
+
+    def test_update_sso_settings(self, mock_proxy_config, mock_auth):
+        """Test updating the SSO settings"""
+        # New SSO settings to update
+        new_sso_settings = {
+            "google_client_id": "new_google_client_id",
+            "google_client_secret": "new_google_client_secret",
+            "microsoft_client_id": "new_microsoft_client_id",
+            "microsoft_client_secret": "new_microsoft_client_secret",
+            "proxy_base_url": "https://newexample.com",
+            "user_email": "newadmin@example.com"
+        }
+
+        response = client.patch("/update/sso_settings", json=new_sso_settings)
+
+        assert response.status_code == 200
+        data = response.json()
+
+        # Check response structure
+        assert data["status"] == "success"
+        assert "settings" in data
+
+        # Verify settings were updated
+        settings = data["settings"]
+        assert settings["google_client_id"] == new_sso_settings["google_client_id"]
+        assert settings["google_client_secret"] == new_sso_settings["google_client_secret"]
+        assert settings["microsoft_client_id"] == new_sso_settings["microsoft_client_id"]
+        assert settings["microsoft_client_secret"] == new_sso_settings["microsoft_client_secret"]
+        assert settings["proxy_base_url"] == new_sso_settings["proxy_base_url"]
+        assert settings["user_email"] == new_sso_settings["user_email"]
+
+        # Verify the config was updated
+        updated_config = mock_proxy_config["config"]
+        assert updated_config["environment_variables"]["GOOGLE_CLIENT_ID"] == new_sso_settings["google_client_id"]
+        assert updated_config["environment_variables"]["GOOGLE_CLIENT_SECRET"] == new_sso_settings["google_client_secret"]
+        assert updated_config["general_settings"]["proxy_admin_email"] == new_sso_settings["user_email"]
+
+        # Verify save_config was called exactly once
+        assert mock_proxy_config["save_call_count"]() == 1
EOF_114329324912

# Ensure PYTHONPATH is set correctly
export PYTHONPATH=/testbed:$PYTHONPATH

# Run the target test file with pytest
# Using -v and --tb=short flags as specified in the context retrieval information
# -v: verbose output
# --tb=short: shorter traceback format
pytest -v --tb=short tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py

# Capture exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file to clean state
git checkout 3cc94609226ae79572e1e8518fe561451eea63a7 "tests/test_litellm/proxy/ui_crud_endpoints/test_proxy_setting_endpoints.py"

# Exit with the captured return code
exit $rc