#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test files to ensure clean state
git checkout b1fa383e739d923399b3a23ca10435c0fba3460b "tests/unittests/agents/test_callback_context.py" "tests/unittests/auth/test_credential_manager.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/agents/test_callback_context.py b/tests/unittests/agents/test_callback_context.py
--- a/tests/unittests/agents/test_callback_context.py
+++ b/tests/unittests/agents/test_callback_context.py
@@ -16,9 +16,14 @@
 
 from unittest.mock import AsyncMock
 from unittest.mock import MagicMock
+from unittest.mock import Mock
 
 from google.adk.agents.callback_context import CallbackContext
+from google.adk.auth.auth_credential import AuthCredential
+from google.adk.auth.auth_credential import AuthCredentialTypes
+from google.adk.auth.auth_tool import AuthConfig
 from google.adk.tools.tool_context import ToolContext
+from google.genai.types import Part
 import pytest
 
 
@@ -32,6 +37,8 @@ def mock_invocation_context():
   mock_context.session.id = "test-session-id"
   mock_context.app_name = "test-app"
   mock_context.user_id = "test-user"
+  mock_context.artifact_service = None
+  mock_context.credential_service = None
   return mock_context
 
 
@@ -63,6 +70,21 @@ def callback_context_without_artifact_service(mock_invocation_context):
   return CallbackContext(mock_invocation_context)
 
 
+@pytest.fixture
+def mock_auth_config():
+  """Create a mock auth config for testing."""
+  mock_config = Mock(spec=AuthConfig)
+  return mock_config
+
+
+@pytest.fixture
+def mock_auth_credential():
+  """Create a mock auth credential for testing."""
+  mock_credential = Mock(spec=AuthCredential)
+  mock_credential.auth_type = AuthCredentialTypes.OAUTH2
+  return mock_credential
+
+
 class TestCallbackContextListArtifacts:
   """Test the list_artifacts method in CallbackContext."""
 
@@ -119,8 +141,8 @@ async def test_list_artifacts_passes_through_service_exceptions(
       await callback_context_with_artifact_service.list_artifacts()
 
 
-class TestToolContextListArtifacts:
-  """Test that list_artifacts is available in ToolContext through inheritance."""
+class TestCallbackContext:
+  """Test suite for CallbackContext."""
 
   @pytest.mark.asyncio
   async def test_tool_context_inherits_list_artifacts(
@@ -167,3 +189,134 @@ def test_tool_context_shares_same_list_artifacts_method_with_callback_context(
   ):
     """Test that ToolContext and CallbackContext share the same list_artifacts method."""
     assert ToolContext.list_artifacts is CallbackContext.list_artifacts
+
+  def test_initialization(self, mock_invocation_context):
+    """Test CallbackContext initialization."""
+    context = CallbackContext(mock_invocation_context)
+    assert context._invocation_context == mock_invocation_context
+    assert context._event_actions is not None
+    assert context._state is not None
+
+  @pytest.mark.asyncio
+  async def test_save_credential_with_service(
+      self, mock_invocation_context, mock_auth_config
+  ):
+    """Test save_credential when credential service is available."""
+    # Mock credential service
+    credential_service = AsyncMock()
+    mock_invocation_context.credential_service = credential_service
+
+    context = CallbackContext(mock_invocation_context)
+    await context.save_credential(mock_auth_config)
+
+    credential_service.save_credential.assert_called_once_with(
+        mock_auth_config, context
+    )
+
+  @pytest.mark.asyncio
+  async def test_save_credential_no_service(
+      self, mock_invocation_context, mock_auth_config
+  ):
+    """Test save_credential when credential service is not available."""
+    mock_invocation_context.credential_service = None
+
+    context = CallbackContext(mock_invocation_context)
+
+    with pytest.raises(
+        ValueError, match="Credential service is not initialized"
+    ):
+      await context.save_credential(mock_auth_config)
+
+  @pytest.mark.asyncio
+  async def test_load_credential_with_service(
+      self, mock_invocation_context, mock_auth_config, mock_auth_credential
+  ):
+    """Test load_credential when credential service is available."""
+    # Mock credential service
+    credential_service = AsyncMock()
+    credential_service.load_credential.return_value = mock_auth_credential
+    mock_invocation_context.credential_service = credential_service
+
+    context = CallbackContext(mock_invocation_context)
+    result = await context.load_credential(mock_auth_config)
+
+    credential_service.load_credential.assert_called_once_with(
+        mock_auth_config, context
+    )
+    assert result == mock_auth_credential
+
+  @pytest.mark.asyncio
+  async def test_load_credential_no_service(
+      self, mock_invocation_context, mock_auth_config
+  ):
+    """Test load_credential when credential service is not available."""
+    mock_invocation_context.credential_service = None
+
+    context = CallbackContext(mock_invocation_context)
+
+    with pytest.raises(
+        ValueError, match="Credential service is not initialized"
+    ):
+      await context.load_credential(mock_auth_config)
+
+  @pytest.mark.asyncio
+  async def test_load_credential_returns_none(
+      self, mock_invocation_context, mock_auth_config
+  ):
+    """Test load_credential returns None when credential not found."""
+    # Mock credential service
+    credential_service = AsyncMock()
+    credential_service.load_credential.return_value = None
+    mock_invocation_context.credential_service = credential_service
+
+    context = CallbackContext(mock_invocation_context)
+    result = await context.load_credential(mock_auth_config)
+
+    credential_service.load_credential.assert_called_once_with(
+        mock_auth_config, context
+    )
+    assert result is None
+
+  @pytest.mark.asyncio
+  async def test_save_artifact_integration(self, mock_invocation_context):
+    """Test save_artifact to ensure credential methods follow same pattern."""
+    # Mock artifact service
+    artifact_service = AsyncMock()
+    artifact_service.save_artifact.return_value = 1
+    mock_invocation_context.artifact_service = artifact_service
+
+    context = CallbackContext(mock_invocation_context)
+    test_artifact = Part.from_text(text="test content")
+
+    version = await context.save_artifact("test_file.txt", test_artifact)
+
+    artifact_service.save_artifact.assert_called_once_with(
+        app_name="test-app",
+        user_id="test-user",
+        session_id="test-session-id",
+        filename="test_file.txt",
+        artifact=test_artifact,
+    )
+    assert version == 1
+
+  @pytest.mark.asyncio
+  async def test_load_artifact_integration(self, mock_invocation_context):
+    """Test load_artifact to ensure credential methods follow same pattern."""
+    # Mock artifact service
+    artifact_service = AsyncMock()
+    test_artifact = Part.from_text(text="test content")
+    artifact_service.load_artifact.return_value = test_artifact
+    mock_invocation_context.artifact_service = artifact_service
+
+    context = CallbackContext(mock_invocation_context)
+
+    result = await context.load_artifact("test_file.txt")
+
+    artifact_service.load_artifact.assert_called_once_with(
+        app_name="test-app",
+        user_id="test-user",
+        session_id="test-session-id",
+        filename="test_file.txt",
+        version=None,
+    )
+    assert result == test_artifact
diff --git a/tests/unittests/auth/test_credential_manager.py b/tests/unittests/auth/test_credential_manager.py
--- a/tests/unittests/auth/test_credential_manager.py
+++ b/tests/unittests/auth/test_credential_manager.py
@@ -167,21 +167,19 @@ async def test_load_from_credential_service_with_service(self):
 
     # Mock credential service
     credential_service = Mock()
-    credential_service.load_credential = AsyncMock(return_value=mock_credential)
 
     # Mock invocation context
     invocation_context = Mock()
     invocation_context.credential_service = credential_service
 
     callback_context = Mock()
     callback_context._invocation_context = invocation_context
+    callback_context.load_credential = AsyncMock(return_value=mock_credential)
 
     manager = CredentialManager(auth_config)
     result = await manager._load_from_credential_service(callback_context)
 
-    credential_service.load_credential.assert_called_once_with(
-        auth_config, callback_context
-    )
+    callback_context.load_credential.assert_called_once_with(auth_config)
     assert result == mock_credential
 
   @pytest.mark.asyncio
@@ -216,13 +214,12 @@ async def test_save_credential_with_service(self):
 
     callback_context = Mock()
     callback_context._invocation_context = invocation_context
+    callback_context.save_credential = AsyncMock()
 
     manager = CredentialManager(auth_config)
     await manager._save_credential(callback_context, mock_credential)
 
-    credential_service.save_credential.assert_called_once_with(
-        auth_config, callback_context
-    )
+    callback_context.save_credential.assert_called_once_with(auth_config)
     assert auth_config.exchanged_auth_credential == mock_credential
 
   @pytest.mark.asyncio
@@ -242,9 +239,9 @@ async def test_save_credential_no_service(self):
     manager = CredentialManager(auth_config)
     await manager._save_credential(callback_context, mock_credential)
 
-    # Should not raise an error, and credential should not be set in auth_config
-    # when there's no credential service (according to implementation)
-    assert auth_config.exchanged_auth_credential is None
+    # Should not raise an error, and credential should be set in auth_config
+    # even when there's no credential service (config is updated regardless)
+    assert auth_config.exchanged_auth_credential == mock_credential
 
   @pytest.mark.asyncio
   async def test_refresh_credential_oauth2(self):
EOF_114329324912

# Run the target test files with pytest
# Using single-process mode for safety in virtualized environment
# Combining both test files into a single pytest command for efficiency
pytest tests/unittests/agents/test_callback_context.py tests/unittests/auth/test_credential_manager.py -v --no-header -rA --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
git checkout b1fa383e739d923399b3a23ca10435c0fba3460b "tests/unittests/agents/test_callback_context.py" "tests/unittests/auth/test_credential_manager.py"

# Exit with the captured return code
exit $rc