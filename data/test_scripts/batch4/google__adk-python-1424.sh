#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout 476805d5b9e6d598ca8bb71488a4923c162cfdbc "tests/unittests/auth/test_auth_handler.py" "tests/unittests/auth/test_oauth2_credential_fetcher.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/auth/test_auth_handler.py b/tests/unittests/auth/test_auth_handler.py
--- a/tests/unittests/auth/test_auth_handler.py
+++ b/tests/unittests/auth/test_auth_handler.py
@@ -538,7 +538,7 @@ def test_credentials_with_token(
     assert result == oauth2_credentials_with_token
 
   @patch(
-      "google.adk.auth.oauth2_credential_fetcher.OAuth2Session",
+      "google.adk.auth.oauth2_credential_util.OAuth2Session",
       MockOAuth2Session,
   )
   def test_successful_token_exchange(self, auth_config_with_auth_code):
diff --git a/tests/unittests/auth/test_oauth2_credential_fetcher.py b/tests/unittests/auth/test_oauth2_credential_fetcher.py
--- a/tests/unittests/auth/test_oauth2_credential_fetcher.py
+++ b/tests/unittests/auth/test_oauth2_credential_fetcher.py
@@ -14,7 +14,6 @@
 
 import time
 from unittest.mock import Mock
-from unittest.mock import patch
 
 from authlib.oauth2.rfc6749 import OAuth2Token
 from fastapi.openapi.models import OAuth2
@@ -24,38 +23,15 @@
 from google.adk.auth.auth_credential import AuthCredentialTypes
 from google.adk.auth.auth_credential import OAuth2Auth
 from google.adk.auth.auth_schemes import OpenIdConnectWithConfig
-from google.adk.auth.oauth2_credential_fetcher import OAuth2CredentialFetcher
+from google.adk.auth.oauth2_credential_util import create_oauth2_session
+from google.adk.auth.oauth2_credential_util import update_credential_with_tokens
 
 
-class TestOAuth2CredentialFetcher:
-  """Test suite for OAuth2CredentialFetcher."""
+class TestOAuth2CredentialUtil:
+  """Test suite for OAuth2 credential utility functions."""
 
-  def test_init(self):
-    """Test OAuth2CredentialFetcher initialization."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid", "profile"],
-    )
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            redirect_uri="https://example.com/callback",
-        ),
-    )
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    assert fetcher._auth_scheme == scheme
-    assert fetcher._auth_credential == credential
-
-  def test_oauth2_session_openid_connect(self):
-    """Test _oauth2_session with OpenID Connect scheme."""
+  def test_create_oauth2_session_openid_connect(self):
+    """Test create_oauth2_session with OpenID Connect scheme."""
     scheme = OpenIdConnectWithConfig(
         type_="openIdConnect",
         openId_connect_url=(
@@ -75,16 +51,15 @@ def test_oauth2_session_openid_connect(self):
         ),
     )
 
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    client, token_endpoint = fetcher._oauth2_session()
+    client, token_endpoint = create_oauth2_session(scheme, credential)
 
     assert client is not None
     assert token_endpoint == "https://example.com/token"
     assert client.client_id == "test_client_id"
     assert client.client_secret == "test_client_secret"
 
-  def test_oauth2_session_oauth2_scheme(self):
-    """Test _oauth2_session with OAuth2 scheme."""
+  def test_create_oauth2_session_oauth2_scheme(self):
+    """Test create_oauth2_session with OAuth2 scheme."""
     flows = OAuthFlows(
         authorizationCode=OAuthFlowAuthorizationCode(
             authorizationUrl="https://example.com/auth",
@@ -102,14 +77,13 @@ def test_oauth2_session_oauth2_scheme(self):
         ),
     )
 
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    client, token_endpoint = fetcher._oauth2_session()
+    client, token_endpoint = create_oauth2_session(scheme, credential)
 
     assert client is not None
     assert token_endpoint == "https://example.com/token"
 
-  def test_oauth2_session_invalid_scheme(self):
-    """Test _oauth2_session with invalid scheme."""
+  def test_create_oauth2_session_invalid_scheme(self):
+    """Test create_oauth2_session with invalid scheme."""
     scheme = Mock()  # Invalid scheme type
     credential = AuthCredential(
         auth_type=AuthCredentialTypes.OAUTH2,
@@ -119,14 +93,13 @@ def test_oauth2_session_invalid_scheme(self):
         ),
     )
 
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    client, token_endpoint = fetcher._oauth2_session()
+    client, token_endpoint = create_oauth2_session(scheme, credential)
 
     assert client is None
     assert token_endpoint is None
 
-  def test_oauth2_session_missing_credentials(self):
-    """Test _oauth2_session with missing credentials."""
+  def test_create_oauth2_session_missing_credentials(self):
+    """Test create_oauth2_session with missing credentials."""
     scheme = OpenIdConnectWithConfig(
         type_="openIdConnect",
         openId_connect_url=(
@@ -144,23 +117,13 @@ def test_oauth2_session_missing_credentials(self):
         ),
     )
 
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    client, token_endpoint = fetcher._oauth2_session()
+    client, token_endpoint = create_oauth2_session(scheme, credential)
 
     assert client is None
     assert token_endpoint is None
 
-  def test_update_credential(self):
-    """Test _update_credential method."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
+  def test_update_credential_with_tokens(self):
+    """Test update_credential_with_tokens function."""
     credential = AuthCredential(
         auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
         oauth2=OAuth2Auth(
@@ -169,273 +132,16 @@ def test_update_credential(self):
         ),
     )
 
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
     tokens = OAuth2Token({
         "access_token": "new_access_token",
         "refresh_token": "new_refresh_token",
         "expires_at": int(time.time()) + 3600,
         "expires_in": 3600,
     })
 
-    fetcher._update_credential(tokens)
+    update_credential_with_tokens(credential, tokens)
 
     assert credential.oauth2.access_token == "new_access_token"
     assert credential.oauth2.refresh_token == "new_refresh_token"
     assert credential.oauth2.expires_at == int(time.time()) + 3600
     assert credential.oauth2.expires_in == 3600
-
-  def test_exchange_with_existing_token(self):
-    """Test exchange method when access token already exists."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            access_token="existing_token",
-        ),
-    )
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.exchange()
-
-    assert result == credential
-    assert result.oauth2.access_token == "existing_token"
-
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Session")
-  def test_exchange_success(self, mock_oauth2_session):
-    """Test successful token exchange."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            auth_response_uri=(
-                "https://example.com/callback?code=auth_code&state=test_state"
-            ),
-        ),
-    )
-
-    # Mock the OAuth2Session
-    mock_client = Mock()
-    mock_oauth2_session.return_value = mock_client
-    mock_tokens = {
-        "access_token": "new_access_token",
-        "refresh_token": "new_refresh_token",
-        "expires_at": int(time.time()) + 3600,
-        "expires_in": 3600,
-    }
-    mock_client.fetch_token.return_value = mock_tokens
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.exchange()
-
-    assert result.oauth2.access_token == "new_access_token"
-    assert result.oauth2.refresh_token == "new_refresh_token"
-    mock_client.fetch_token.assert_called_once()
-
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Session")
-  def test_exchange_with_auth_code(self, mock_oauth2_session):
-    """Test token exchange with auth code."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            auth_code="test_auth_code",
-        ),
-    )
-
-    mock_client = Mock()
-    mock_oauth2_session.return_value = mock_client
-    mock_tokens = {
-        "access_token": "new_access_token",
-        "refresh_token": "new_refresh_token",
-    }
-    mock_client.fetch_token.return_value = mock_tokens
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.exchange()
-
-    assert result.oauth2.access_token == "new_access_token"
-    mock_client.fetch_token.assert_called_once()
-
-  def test_exchange_no_session(self):
-    """Test exchange when OAuth2Session cannot be created."""
-    scheme = Mock()  # Invalid scheme
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            auth_response_uri="https://example.com/callback?code=auth_code",
-        ),
-    )
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.exchange()
-
-    assert result == credential
-    assert result.oauth2.access_token is None
-
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Token")
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Session")
-  def test_refresh_token_not_expired(
-      self, mock_oauth2_session, mock_oauth2_token
-  ):
-    """Test refresh when token is not expired."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            access_token="current_token",
-            refresh_token="refresh_token",
-            expires_at=int(time.time()) + 3600,
-            expires_in=3600,
-        ),
-    )
-
-    # Mock token not expired
-    mock_token_instance = Mock()
-    mock_token_instance.is_expired.return_value = False
-    mock_oauth2_token.return_value = mock_token_instance
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.refresh()
-
-    assert result == credential
-    assert result.oauth2.access_token == "current_token"
-    mock_oauth2_session.assert_not_called()
-
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Token")
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Session")
-  def test_refresh_token_expired_success(
-      self, mock_oauth2_session, mock_oauth2_token
-  ):
-    """Test successful token refresh when token is expired."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            access_token="expired_token",
-            refresh_token="refresh_token",
-            expires_at=int(time.time()) - 3600,  # Expired
-            expires_in=3600,
-        ),
-    )
-
-    # Mock token expired
-    mock_token_instance = Mock()
-    mock_token_instance.is_expired.return_value = True
-    mock_oauth2_token.return_value = mock_token_instance
-
-    # Mock refresh token response
-    mock_client = Mock()
-    mock_oauth2_session.return_value = mock_client
-    mock_tokens = {
-        "access_token": "refreshed_access_token",
-        "refresh_token": "new_refresh_token",
-        "expires_at": int(time.time()) + 3600,
-        "expires_in": 3600,
-    }
-    mock_client.refresh_token.return_value = mock_tokens
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.refresh()
-
-    assert result.oauth2.access_token == "refreshed_access_token"
-    assert result.oauth2.refresh_token == "new_refresh_token"
-    mock_client.refresh_token.assert_called_once_with(
-        url="https://example.com/token",
-        refresh_token="refresh_token",
-    )
-
-  def test_refresh_no_oauth2_credential(self):
-    """Test refresh when oauth2 credential is missing."""
-    scheme = OpenIdConnectWithConfig(
-        type_="openIdConnect",
-        openId_connect_url=(
-            "https://example.com/.well-known/openid_configuration"
-        ),
-        authorization_endpoint="https://example.com/auth",
-        token_endpoint="https://example.com/token",
-        scopes=["openid"],
-    )
-    credential = AuthCredential(auth_type=AuthCredentialTypes.HTTP)  # No oauth2
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.refresh()
-
-    assert result == credential
-
-  @patch("google.adk.auth.oauth2_credential_fetcher.OAuth2Token")
-  def test_refresh_no_session(self, mock_oauth2_token):
-    """Test refresh when OAuth2Session cannot be created."""
-    scheme = Mock()  # Invalid scheme
-    credential = AuthCredential(
-        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
-        oauth2=OAuth2Auth(
-            client_id="test_client_id",
-            client_secret="test_client_secret",
-            access_token="expired_token",
-            refresh_token="refresh_token",
-            expires_at=int(time.time()) - 3600,
-        ),
-    )
-
-    # Mock token expired
-    mock_token_instance = Mock()
-    mock_token_instance.is_expired.return_value = True
-    mock_oauth2_token.return_value = mock_token_instance
-
-    fetcher = OAuth2CredentialFetcher(scheme, credential)
-    result = fetcher.refresh()
-
-    assert result == credential
-    assert result.oauth2.access_token == "expired_token"  # Unchanged
diff --git a/tests/unittests/auth/test_oauth2_credential_util.py b/tests/unittests/auth/test_oauth2_credential_util.py
new file mode 100644
--- /dev/null
+++ b/tests/unittests/auth/test_oauth2_credential_util.py
@@ -0,0 +1,147 @@
+# Copyright 2025 Google LLC
+#
+# Licensed under the Apache License, Version 2.0 (the "License");
+# you may not use this file except in compliance with the License.
+# You may obtain a copy of the License at
+#
+#     http://www.apache.org/licenses/LICENSE-2.0
+#
+# Unless required by applicable law or agreed to in writing, software
+# distributed under the License is distributed on an "AS IS" BASIS,
+# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
+# See the License for the specific language governing permissions and
+# limitations under the License.
+
+import time
+from unittest.mock import Mock
+
+from authlib.oauth2.rfc6749 import OAuth2Token
+from fastapi.openapi.models import OAuth2
+from fastapi.openapi.models import OAuthFlowAuthorizationCode
+from fastapi.openapi.models import OAuthFlows
+from google.adk.auth.auth_credential import AuthCredential
+from google.adk.auth.auth_credential import AuthCredentialTypes
+from google.adk.auth.auth_credential import OAuth2Auth
+from google.adk.auth.auth_schemes import OpenIdConnectWithConfig
+from google.adk.auth.oauth2_credential_util import create_oauth2_session
+from google.adk.auth.oauth2_credential_util import update_credential_with_tokens
+
+
+class TestOAuth2CredentialUtil:
+  """Test suite for OAuth2 credential utility functions."""
+
+  def test_create_oauth2_session_openid_connect(self):
+    """Test create_oauth2_session with OpenID Connect scheme."""
+    scheme = OpenIdConnectWithConfig(
+        type_="openIdConnect",
+        openId_connect_url=(
+            "https://example.com/.well-known/openid_configuration"
+        ),
+        authorization_endpoint="https://example.com/auth",
+        token_endpoint="https://example.com/token",
+        scopes=["openid", "profile"],
+    )
+    credential = AuthCredential(
+        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
+        oauth2=OAuth2Auth(
+            client_id="test_client_id",
+            client_secret="test_client_secret",
+            redirect_uri="https://example.com/callback",
+            state="test_state",
+        ),
+    )
+
+    client, token_endpoint = create_oauth2_session(scheme, credential)
+
+    assert client is not None
+    assert token_endpoint == "https://example.com/token"
+    assert client.client_id == "test_client_id"
+    assert client.client_secret == "test_client_secret"
+
+  def test_create_oauth2_session_oauth2_scheme(self):
+    """Test create_oauth2_session with OAuth2 scheme."""
+    flows = OAuthFlows(
+        authorizationCode=OAuthFlowAuthorizationCode(
+            authorizationUrl="https://example.com/auth",
+            tokenUrl="https://example.com/token",
+            scopes={"read": "Read access", "write": "Write access"},
+        )
+    )
+    scheme = OAuth2(type_="oauth2", flows=flows)
+    credential = AuthCredential(
+        auth_type=AuthCredentialTypes.OAUTH2,
+        oauth2=OAuth2Auth(
+            client_id="test_client_id",
+            client_secret="test_client_secret",
+            redirect_uri="https://example.com/callback",
+        ),
+    )
+
+    client, token_endpoint = create_oauth2_session(scheme, credential)
+
+    assert client is not None
+    assert token_endpoint == "https://example.com/token"
+
+  def test_create_oauth2_session_invalid_scheme(self):
+    """Test create_oauth2_session with invalid scheme."""
+    scheme = Mock()  # Invalid scheme type
+    credential = AuthCredential(
+        auth_type=AuthCredentialTypes.OAUTH2,
+        oauth2=OAuth2Auth(
+            client_id="test_client_id",
+            client_secret="test_client_secret",
+        ),
+    )
+
+    client, token_endpoint = create_oauth2_session(scheme, credential)
+
+    assert client is None
+    assert token_endpoint is None
+
+  def test_create_oauth2_session_missing_credentials(self):
+    """Test create_oauth2_session with missing credentials."""
+    scheme = OpenIdConnectWithConfig(
+        type_="openIdConnect",
+        openId_connect_url=(
+            "https://example.com/.well-known/openid_configuration"
+        ),
+        authorization_endpoint="https://example.com/auth",
+        token_endpoint="https://example.com/token",
+        scopes=["openid"],
+    )
+    credential = AuthCredential(
+        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
+        oauth2=OAuth2Auth(
+            client_id="test_client_id",
+            # Missing client_secret
+        ),
+    )
+
+    client, token_endpoint = create_oauth2_session(scheme, credential)
+
+    assert client is None
+    assert token_endpoint is None
+
+  def test_update_credential_with_tokens(self):
+    """Test update_credential_with_tokens function."""
+    credential = AuthCredential(
+        auth_type=AuthCredentialTypes.OPEN_ID_CONNECT,
+        oauth2=OAuth2Auth(
+            client_id="test_client_id",
+            client_secret="test_client_secret",
+        ),
+    )
+
+    tokens = OAuth2Token({
+        "access_token": "new_access_token",
+        "refresh_token": "new_refresh_token",
+        "expires_at": int(time.time()) + 3600,
+        "expires_in": 3600,
+    })
+
+    update_credential_with_tokens(credential, tokens)
+
+    assert credential.oauth2.access_token == "new_access_token"
+    assert credential.oauth2.refresh_token == "new_refresh_token"
+    assert credential.oauth2.expires_at == int(time.time()) + 3600
+    assert credential.oauth2.expires_in == 3600
EOF_114329324912

# Run target tests with pytest
# Using single-process mode for safety in virtualized environment
# -v for verbose output, --tb=short for concise tracebacks
# --no-header and -rA for structured output
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/unittests/auth/test_auth_handler.py \
    tests/unittests/auth/test_oauth2_credential_fetcher.py

# Capture exit code
rc=$?

# Echo exit code for test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test files
git checkout 476805d5b9e6d598ca8bb71488a4923c162cfdbc "tests/unittests/auth/test_auth_handler.py" "tests/unittests/auth/test_oauth2_credential_fetcher.py"