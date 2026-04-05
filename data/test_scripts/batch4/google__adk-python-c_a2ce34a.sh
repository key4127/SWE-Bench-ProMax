#!/bin/bash
set -uxo pipefail
cd /testbed

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Checkout the original test file to ensure clean state
git checkout fa5c546a554954c3d9025f52fb99e71649776d7f "tests/unittests/plugins/test_bigquery_logging_plugin.py"

# Apply test patch to update target tests
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/plugins/test_bigquery_logging_plugin.py b/tests/unittests/plugins/test_bigquery_logging_plugin.py
--- a/tests/unittests/plugins/test_bigquery_logging_plugin.py
+++ b/tests/unittests/plugins/test_bigquery_logging_plugin.py
@@ -14,7 +14,6 @@
 
 from __future__ import annotations
 
-import asyncio
 import datetime
 import json
 import logging
@@ -34,219 +33,381 @@
 from google.adk.tools import tool_context as tool_context_lib
 import google.auth
 from google.auth import exceptions as auth_exceptions
+import google.auth.credentials
 from google.cloud import bigquery
 from google.genai import types
+import pyarrow as pa
 import pytest
 
 BigQueryLoggerConfig = bigquery_logging_plugin.BigQueryLoggerConfig
 
+PROJECT_ID = "test-gcp-project"
+DATASET_ID = "adk_logs"
+TABLE_ID = "agent_events"
+DEFAULT_STREAM_NAME = (
+    f"projects/{PROJECT_ID}/datasets/{DATASET_ID}/tables/{TABLE_ID}/_default"
+)
+
+# --- Pytest Fixtures ---
+
+
+@pytest.fixture
+def mock_session():
+  mock_s = mock.create_autospec(
+      session_lib.Session, instance=True, spec_set=True
+  )
+  type(mock_s).id = mock.PropertyMock(return_value="session-123")
+  type(mock_s).user_id = mock.PropertyMock(return_value="user-456")
+  type(mock_s).app_name = mock.PropertyMock(return_value="test_app")
+  type(mock_s).state = mock.PropertyMock(return_value={})
+  return mock_s
+
+
+@pytest.fixture
+def mock_agent():
+  mock_a = mock.create_autospec(
+      base_agent.BaseAgent, instance=True, spec_set=True
+  )
+  # Mock the 'name' property
+  type(mock_a).name = mock.PropertyMock(return_value="MyTestAgent")
+  return mock_a
+
+
+@pytest.fixture
+def invocation_context(mock_agent, mock_session):
+  mock_session_service = mock.create_autospec(
+      base_session_service_lib.BaseSessionService, instance=True, spec_set=True
+  )
+  mock_plugin_manager = mock.create_autospec(
+      plugin_manager_lib.PluginManager, instance=True, spec_set=True
+  )
+  return invocation_context_lib.InvocationContext(
+      agent=mock_agent,
+      session=mock_session,
+      invocation_id="inv-789",
+      session_service=mock_session_service,
+      plugin_manager=mock_plugin_manager,
+  )
+
+
+@pytest.fixture
+def callback_context(invocation_context):
+  return callback_context_lib.CallbackContext(
+      invocation_context=invocation_context
+  )
+
+
+@pytest.fixture
+def tool_context(invocation_context):
+  return tool_context_lib.ToolContext(invocation_context=invocation_context)
+
+
+@pytest.fixture
+def mock_auth_default():
+  mock_creds = mock.create_autospec(
+      google.auth.credentials.Credentials, instance=True, spec_set=True
+  )
+  with mock.patch.object(
+      google.auth,
+      "default",
+      autospec=True,
+      return_value=(mock_creds, PROJECT_ID),
+  ) as mock_auth:
+    yield mock_auth
+
+
+@pytest.fixture
+def mock_bq_client():
+  with mock.patch.object(bigquery, "Client", autospec=True) as mock_cls:
+    yield mock_cls.return_value
+
+
+@pytest.fixture
+def mock_write_client():
+  with mock.patch.object(
+      bigquery_logging_plugin, "BigQueryWriteAsyncClient", autospec=True
+  ) as mock_cls:
+    mock_client = mock_cls.return_value
+    mock_append_rows_response = mock.MagicMock()
+    # Configure the 'row_errors' attribute on the mock object.
+    mock_append_rows_response.row_errors = []
+    mock_append_rows_response.error = mock.MagicMock()
+    mock_append_rows_response.error.code = 0  # OK status
+
+    mock_client.append_rows.return_value = _async_gen(mock_append_rows_response)
+    yield mock_client
+
+
+@pytest.fixture
+def dummy_arrow_schema():
+  return pa.schema([
+      pa.field(
+          "timestamp", pa.string()
+      ),  # Store as string for simplicity in test
+      pa.field("event_type", pa.string()),
+      pa.field("agent", pa.string()),
+      pa.field("session_id", pa.string()),
+      pa.field("invocation_id", pa.string()),
+      pa.field("user_id", pa.string()),
+      pa.field("content", pa.string()),
+      pa.field("error_message", pa.string()),
+  ])
+
+
+@pytest.fixture
+def mock_to_arrow_schema(dummy_arrow_schema):
+  with mock.patch.object(
+      bigquery_logging_plugin,
+      "to_arrow_schema",
+      autospec=True,
+      return_value=dummy_arrow_schema,
+  ) as mock_func:
+    yield mock_func
+
+
+@pytest.fixture
+def mock_asyncio_to_thread():
+  async def fake_to_thread(func, *args, **kwargs):
+    return func(*args, **kwargs)
+
+  with mock.patch(
+      "asyncio.to_thread", side_effect=fake_to_thread
+  ) as mock_async:
+    yield mock_async
+
+
+@pytest.fixture
+def bq_plugin_inst(
+    mock_auth_default,
+    mock_bq_client,
+    mock_write_client,
+    mock_to_arrow_schema,
+):
+  plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+      project_id=PROJECT_ID,
+      dataset_id=DATASET_ID,
+      table_id=TABLE_ID,
+  )
+  # Trigger lazy initialization
+  plugin._ensure_initialized_sync()
+  mock_write_client.append_rows.reset_mock()
+  return plugin
+
+
+# --- Helper Functions ---
+
+
+async def _async_gen(val):
+  yield val
+
+
+def _get_captured_event_dict(mock_write_client, expected_schema):
+  """Helper to get the event_dict passed to append_rows."""
+  mock_write_client.append_rows.assert_called_once()
+  call_args = mock_write_client.append_rows.call_args
+  requests = call_args.kwargs["requests"]
+  assert len(requests) == 1
+  request = requests[0]
+  assert request.write_stream == DEFAULT_STREAM_NAME
+
+  arrow_rows = request.arrow_rows
+  message = pa.ipc.read_message(arrow_rows.rows.serialized_record_batch)
+  batch = pa.ipc.read_record_batch(message, schema=expected_schema)
+  table = pa.Table.from_batches([batch])
+  assert table.schema.equals(
+      expected_schema
+  ), f"Schema mismatch: Expected {expected_schema}, got {table.schema}"
+  pydict = table.to_pydict()
+  return {k: v[0] for k, v in pydict.items()}
+
+
+def _assert_common_fields(log_entry, event_type, agent="MyTestAgent"):
+  assert log_entry["event_type"] == event_type
+  assert log_entry["agent"] == agent
+  assert log_entry["session_id"] == "session-123"
+  assert log_entry["invocation_id"] == "inv-789"
+  assert log_entry["user_id"] == "user-456"
+  assert "timestamp" in log_entry
+  assert isinstance(log_entry["timestamp"], str)
+
+
+# --- Test Class ---
+
+
+class TestBigQueryAgentAnalyticsPlugin:
 
-class PluginTestBase:
-  """Base class for plugin tests with common context setup."""
-
-  def setup_method(self, method):
-    self.mock_session = mock.create_autospec(session_lib.Session, instance=True)
-    self.mock_session.id = "session-123"
-    self.mock_session.user_id = "user-456"
-    self.mock_session.app_name = "test_app"
-    self.mock_session.state = {}
-    self.mock_agent = mock.create_autospec(base_agent.BaseAgent, instance=True)
-    self.mock_agent.name = "MyTestAgent"
-    mock_session_service = mock.create_autospec(
-        base_session_service_lib.BaseSessionService, instance=True
-    )
-    mock_plugin_manager = mock.create_autospec(
-        plugin_manager_lib.PluginManager, instance=True
-    )
-    self.invocation_context = invocation_context_lib.InvocationContext(
-        agent=self.mock_agent,
-        session=self.mock_session,
-        invocation_id="inv-789",
-        session_service=mock_session_service,
-        plugin_manager=mock_plugin_manager,
-    )
-    self.callback_context = callback_context_lib.CallbackContext(
-        invocation_context=self.invocation_context
-    )
-    self.tool_context = tool_context_lib.ToolContext(
-        invocation_context=self.invocation_context
-    )
-
-  def teardown_method(self, method):
-    mock.patch.stopall()
-
-
-class TestBigQueryAgentAnalyticsPlugin(PluginTestBase):
-  """Tests for the BigQueryAgentAnalyticsPlugin."""
-
-  def setup_method(self, method):
-    super().setup_method(method)
-    self.project_id = "test-gcp-project"
-    self.dataset_id = "adk_logs"
-    self.table_id = "agent_events"
-
-    # Mock Google Auth default credentials
-    self._auth_patch = mock.patch.object(google.auth, "default", autospec=True)
-    self.mock_auth_default = self._auth_patch.start()
-    self.mock_auth_default.return_value = (mock.Mock(), self.project_id)
-
-    # Mock BigQuery Client class
-    self._bq_client_patch = mock.patch.object(bigquery, "Client", autospec=True)
-    self.mock_bq_client_cls = self._bq_client_patch.start()
-    self.mock_bq_client = self.mock_bq_client_cls.return_value
-    self.mock_bq_client.create_dataset.return_value = None
-    self.mock_bq_client.create_table.return_value = None
-    self.mock_bq_client.insert_rows_json.return_value = []  # No errors
-    self.mock_table_ref = mock.Mock()
-    self.mock_table_ref.dataset_id = self.dataset_id
-    self.mock_table_ref.table_id = self.table_id
-    self.mock_dataset_ref = mock.Mock()
-    self.mock_dataset_ref.table.return_value = self.mock_table_ref
-    self.mock_bq_client.dataset.return_value = self.mock_dataset_ref
-
-    # Patch asyncio.to_thread to run the function synchronously
-    self._asyncio_to_thread_patch = mock.patch(
-        "asyncio.to_thread",
-        side_effect=lambda func, *args, **kwargs: func(*args, **kwargs),
-    )
-    self._asyncio_to_thread_patch.start()
-
-    self.plugin = asyncio.run(self._create_plugin())
-
-  async def _create_plugin(self, config=None):
+  @pytest.mark.asyncio
+  async def test_plugin_disabled(
+      self,
+      mock_auth_default,
+      mock_bq_client,
+      mock_write_client,
+      invocation_context,
+  ):
+    config = BigQueryLoggerConfig(enabled=False)
     plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
-        project_id=self.project_id,
-        dataset_id=self.dataset_id,
-        table_id=self.table_id,
+        project_id=PROJECT_ID,
+        dataset_id=DATASET_ID,
+        table_id=TABLE_ID,
         config=config,
     )
-    if config is None or config.enabled:
-      # Trigger lazy initialization by calling an async method once.
-      await plugin._log_to_bigquery_async({"event_type": "INIT"})
-      self.mock_bq_client.insert_rows_json.reset_mock()
-    return plugin
-
-  def _get_logged_entry(self):
-    """Helper to get the single logged entry from the mocked client."""
-    self.mock_bq_client.insert_rows_json.assert_called_once()
-    args, _ = self.mock_bq_client.insert_rows_json.call_args
-    rows = args[1]
-    assert len(rows) == 1
-    return rows[0]
-
-  def _assert_common_fields(self, log_entry, event_type):
-    assert log_entry["event_type"] == event_type
-    assert log_entry["agent"] == "MyTestAgent"
-    assert log_entry["session_id"] == "session-123"
-    assert log_entry["invocation_id"] == "inv-789"
-    assert log_entry["user_id"] == "user-456"
-    assert log_entry["timestamp"] is not None
-
-  @pytest.mark.asyncio
-  async def test_plugin_disabled(self):
-    self.mock_bq_client_cls.reset_mock()
-    config = BigQueryLoggerConfig(enabled=False)
-    plugin = await self._create_plugin(config)
+    plugin._ensure_initialized_sync()  # Should do nothing
     user_message = types.Content(parts=[types.Part(text="Test")])
+
     await plugin.on_user_message_callback(
-        invocation_context=self.invocation_context, user_message=user_message
+        invocation_context=invocation_context, user_message=user_message
     )
-    self.mock_bq_client_cls.assert_not_called()
-    self.mock_bq_client.insert_rows_json.assert_not_called()
+    mock_auth_default.assert_not_called()
+    mock_bq_client.assert_not_called()
+    mock_write_client.append_rows.assert_not_called()
 
   @pytest.mark.asyncio
-  async def test_event_allowlist(self):
+  async def test_event_allowlist(
+      self,
+      mock_write_client,
+      callback_context,
+      invocation_context,
+      mock_auth_default,
+      mock_bq_client,
+      mock_to_arrow_schema,
+      dummy_arrow_schema,
+  ):
     config = BigQueryLoggerConfig(event_allowlist=["LLM_REQUEST"])
-    plugin = await self._create_plugin(config)
+    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+        PROJECT_ID, DATASET_ID, TABLE_ID, config
+    )
+    plugin._ensure_initialized_sync()
+    mock_write_client.append_rows.reset_mock()
 
-    # This should be logged
     llm_request = llm_request_lib.LlmRequest(
         model="gemini-pro",
         contents=[types.Content(parts=[types.Part(text="Prompt")])],
     )
     await plugin.before_model_callback(
-        callback_context=self.callback_context, llm_request=llm_request
+        callback_context=callback_context, llm_request=llm_request
     )
-    self.mock_bq_client.insert_rows_json.assert_called_once()
-    self.mock_bq_client.insert_rows_json.reset_mock()
+    mock_write_client.append_rows.assert_called_once()
+    mock_write_client.append_rows.reset_mock()
 
-    # This should NOT be logged
     user_message = types.Content(parts=[types.Part(text="What is up?")])
     await plugin.on_user_message_callback(
-        invocation_context=self.invocation_context, user_message=user_message
+        invocation_context=invocation_context, user_message=user_message
     )
-    self.mock_bq_client.insert_rows_json.assert_not_called()
+    mock_write_client.append_rows.assert_not_called()
 
   @pytest.mark.asyncio
-  async def test_event_denylist(self):
+  async def test_event_denylist(
+      self,
+      mock_write_client,
+      invocation_context,
+      mock_auth_default,
+      mock_bq_client,
+      mock_to_arrow_schema,
+      dummy_arrow_schema,
+  ):
     config = BigQueryLoggerConfig(event_denylist=["USER_MESSAGE_RECEIVED"])
-    plugin = await self._create_plugin(config)
+    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+        PROJECT_ID, DATASET_ID, TABLE_ID, config
+    )
+    plugin._ensure_initialized_sync()
+    mock_write_client.append_rows.reset_mock()
 
-    # This should NOT be logged
     user_message = types.Content(parts=[types.Part(text="What is up?")])
     await plugin.on_user_message_callback(
-        invocation_context=self.invocation_context, user_message=user_message
+        invocation_context=invocation_context, user_message=user_message
     )
-    self.mock_bq_client.insert_rows_json.assert_not_called()
+    mock_write_client.append_rows.assert_not_called()
 
-    # This should be logged
-    await plugin.before_run_callback(invocation_context=self.invocation_context)
-    self.mock_bq_client.insert_rows_json.assert_called_once()
+    await plugin.before_run_callback(invocation_context=invocation_context)
+    mock_write_client.append_rows.assert_called_once()
 
   @pytest.mark.asyncio
-  async def test_content_formatter(self):
+  async def test_content_formatter(
+      self,
+      mock_write_client,
+      invocation_context,
+      mock_auth_default,
+      mock_bq_client,
+      mock_to_arrow_schema,
+      dummy_arrow_schema,
+  ):
     def redact_content(content):
       return "[REDACTED]"
 
     config = BigQueryLoggerConfig(content_formatter=redact_content)
-    plugin = await self._create_plugin(config)
+    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+        PROJECT_ID, DATASET_ID, TABLE_ID, config
+    )
+    plugin._ensure_initialized_sync()
+    mock_write_client.append_rows.reset_mock()
 
     user_message = types.Content(parts=[types.Part(text="Secret message")])
     await plugin.on_user_message_callback(
-        invocation_context=self.invocation_context, user_message=user_message
+        invocation_context=invocation_context, user_message=user_message
     )
-
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
     assert log_entry["content"] == "[REDACTED]"
 
   @pytest.mark.asyncio
-  async def test_content_formatter_error(self):
+  async def test_content_formatter_error(
+      self,
+      mock_write_client,
+      invocation_context,
+      mock_auth_default,
+      mock_bq_client,
+      mock_to_arrow_schema,
+      dummy_arrow_schema,
+  ):
     def error_formatter(content):
       raise ValueError("Formatter failed")
 
     config = BigQueryLoggerConfig(content_formatter=error_formatter)
-    plugin = await self._create_plugin(config)
-
+    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+        PROJECT_ID, DATASET_ID, TABLE_ID, config
+    )
+    plugin._ensure_initialized_sync()
+    mock_write_client.append_rows.reset_mock()
     user_message = types.Content(parts=[types.Part(text="Test")])
+
     with mock.patch.object(logging, "warning") as mock_log_warning:
       await plugin.on_user_message_callback(
-          invocation_context=self.invocation_context, user_message=user_message
+          invocation_context=invocation_context, user_message=user_message
       )
       mock_log_warning.assert_called_once_with(
           "Error applying custom content formatter for event type %s: %s",
           "USER_MESSAGE_RECEIVED",
           mock.ANY,
       )
 
-    log_entry = self._get_logged_entry()
-    # Content should be a string, even if formatter failed
-    assert isinstance(log_entry["content"], str)
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
     assert "User Content: text: 'Test'" in log_entry["content"]
 
   @pytest.mark.asyncio
-  async def test_on_user_message_callback_logs_correctly(self):
+  async def test_on_user_message_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      invocation_context,
+      dummy_arrow_schema,
+  ):
     user_message = types.Content(parts=[types.Part(text="What is up?")])
-    await self.plugin.on_user_message_callback(
-        invocation_context=self.invocation_context, user_message=user_message
+    await bq_plugin_inst.on_user_message_callback(
+        invocation_context=invocation_context, user_message=user_message
     )
-
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
     assert log_entry["content"] == "User Content: text: 'What is up?'"
 
   @pytest.mark.asyncio
-  async def test_on_event_callback_tool_call(self):
+  async def test_on_event_callback_tool_call(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      invocation_context,
+      dummy_arrow_schema,
+  ):
     tool_fc = types.FunctionCall(name="get_weather", args={"location": "Paris"})
     event = event_lib.Event(
         author="MyTestAgent",
@@ -255,140 +416,177 @@ async def test_on_event_callback_tool_call(self):
             2025, 10, 22, 10, 0, 0, tzinfo=datetime.timezone.utc
         ).timestamp(),
     )
-    await self.plugin.on_event_callback(
-        invocation_context=self.invocation_context, event=event
+    await bq_plugin_inst.on_event_callback(
+        invocation_context=invocation_context, event=event
     )
-
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "TOOL_CALL")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "TOOL_CALL")
     logged_content = json.loads(log_entry["content"])
     assert logged_content[0]["function_call"]["args"] == {"location": "Paris"}
     assert logged_content[0]["function_call"]["name"] == "get_weather"
     assert log_entry["timestamp"] == "2025-10-22T10:00:00+00:00"
 
   @pytest.mark.asyncio
-  async def test_on_event_callback_model_response(self):
+  async def test_on_event_callback_model_response(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      invocation_context,
+      dummy_arrow_schema,
+  ):
     event = event_lib.Event(
         author="MyTestAgent",
         content=types.Content(parts=[types.Part(text="Hello there!")]),
         timestamp=datetime.datetime(
             2025, 10, 22, 11, 0, 0, tzinfo=datetime.timezone.utc
         ).timestamp(),
     )
-    await self.plugin.on_event_callback(
-        invocation_context=self.invocation_context, event=event
+    await bq_plugin_inst.on_event_callback(
+        invocation_context=invocation_context, event=event
     )
-
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "MODEL_RESPONSE")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "MODEL_RESPONSE")
     logged_content = json.loads(log_entry["content"])
     assert logged_content[0]["text"] == "Hello there!"
     assert log_entry["timestamp"] == "2025-10-22T11:00:00+00:00"
 
   @pytest.mark.asyncio
-  async def test_bigquery_client_initialization_failure(self):
-    # Simulate auth failure
-    self.mock_auth_default.side_effect = auth_exceptions.GoogleAuthError(
+  async def test_bigquery_client_initialization_failure(
+      self, mock_auth_default, mock_write_client, invocation_context
+  ):
+    mock_auth_default.side_effect = auth_exceptions.GoogleAuthError(
         "Auth failed"
     )
-    self.mock_bq_client.insert_rows_json.reset_mock()
-
-    # Re-instantiate the plugin so init is re-attempted
     plugin_with_fail = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
-        project_id=self.project_id,
-        dataset_id=self.dataset_id,
-        table_id=self.table_id,
+        project_id=PROJECT_ID,
+        dataset_id=DATASET_ID,
+        table_id=TABLE_ID,
     )
-
-    # Trigger a callback; initialization happens lazily
     with mock.patch.object(logging, "exception") as mock_log_exception:
-      await plugin_with_fail.before_run_callback(
-          invocation_context=self.invocation_context
+      await plugin_with_fail.on_user_message_callback(
+          invocation_context=invocation_context,
+          user_message=types.Content(parts=[types.Part(text="Test")]),
       )
-      mock_log_exception.assert_called_once()
-
-    # Ensure insert_rows_json was never called because init failed
-    self.mock_bq_client.insert_rows_json.assert_not_called()
+      mock_log_exception.assert_called_once_with(
+          "Failed to initialize BigQuery client or table: %s", mock.ANY
+      )
+    mock_write_client.append_rows.assert_not_called()
 
   @pytest.mark.asyncio
-  async def test_bigquery_insert_error_does_not_raise(self):
-    # Simulate an insert error in the future result
-    self.mock_bq_client.insert_rows_json.return_value = [{"errors": ["error"]}]
+  async def test_bigquery_insert_error_does_not_raise(
+      self, bq_plugin_inst, mock_write_client, invocation_context
+  ):
+    mock_append_rows_response = mock.MagicMock()
+    mock_append_rows_response.row_errors = [mock.MagicMock()]
+    mock_append_rows_response.error = mock.MagicMock()
+    mock_append_rows_response.error.code = 0
+    mock_write_client.append_rows.return_value = _async_gen(
+        mock_append_rows_response
+    )
 
     with mock.patch.object(logging, "error") as mock_log_error:
-      await self.plugin.on_user_message_callback(
-          invocation_context=self.invocation_context,
+      await bq_plugin_inst.on_user_message_callback(
+          invocation_context=invocation_context,
           user_message=types.Content(parts=[types.Part(text="Test")]),
       )
-      # The plugin should handle the error internally without raising
       mock_log_error.assert_called_with(
-          "Errors occurred while inserting to BigQuery table %s.%s: %s",
-          self.dataset_id,
-          self.table_id,
-          [{"errors": ["error"]}],
+          "Errors occurred while writing to BigQuery (Storage Write API): %s",
+          mock_append_rows_response.row_errors,
       )
-
-    self.mock_bq_client.insert_rows_json.assert_called_once()
+    mock_write_client.append_rows.assert_called_once()
 
   @pytest.mark.asyncio
-  async def test_before_run_callback_logs_correctly(self):
-    await self.plugin.before_run_callback(
-        invocation_context=self.invocation_context
-    )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "INVOCATION_STARTING")
+  async def test_before_run_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      invocation_context,
+      dummy_arrow_schema,
+  ):
+    await bq_plugin_inst.before_run_callback(
+        invocation_context=invocation_context
+    )
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "INVOCATION_STARTING")
     assert log_entry["content"] is None
 
   @pytest.mark.asyncio
-  async def test_after_run_callback_logs_correctly(self):
-    await self.plugin.after_run_callback(
-        invocation_context=self.invocation_context
-    )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "INVOCATION_COMPLETED")
+  async def test_after_run_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      invocation_context,
+      dummy_arrow_schema,
+  ):
+    await bq_plugin_inst.after_run_callback(
+        invocation_context=invocation_context
+    )
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "INVOCATION_COMPLETED")
     assert log_entry["content"] is None
 
   @pytest.mark.asyncio
-  async def test_before_agent_callback_logs_correctly(self):
-    await self.plugin.before_agent_callback(
-        agent=self.mock_agent, callback_context=self.callback_context
-    )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "AGENT_STARTING")
+  async def test_before_agent_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      mock_agent,
+      callback_context,
+      dummy_arrow_schema,
+  ):
+    await bq_plugin_inst.before_agent_callback(
+        agent=mock_agent, callback_context=callback_context
+    )
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "AGENT_STARTING")
     assert log_entry["content"] == "Agent Name: MyTestAgent"
 
   @pytest.mark.asyncio
-  async def test_after_agent_callback_logs_correctly(self):
-    await self.plugin.after_agent_callback(
-        agent=self.mock_agent, callback_context=self.callback_context
-    )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "AGENT_COMPLETED")
+  async def test_after_agent_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      mock_agent,
+      callback_context,
+      dummy_arrow_schema,
+  ):
+    await bq_plugin_inst.after_agent_callback(
+        agent=mock_agent, callback_context=callback_context
+    )
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "AGENT_COMPLETED")
     assert log_entry["content"] == "Agent Name: MyTestAgent"
 
   @pytest.mark.asyncio
-  async def test_before_model_callback_logs_correctly(self):
+  async def test_before_model_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      callback_context,
+      dummy_arrow_schema,
+  ):
     llm_request = llm_request_lib.LlmRequest(
         model="gemini-pro",
         contents=[types.Content(parts=[types.Part(text="Prompt")])],
         config=types.GenerateContentConfig(
             temperature=0.5,
             top_p=0.9,
             max_output_tokens=100,
-            system_instruction="Be helpful",
+            system_instruction=types.Content(
+                parts=[types.Part(text="Be helpful")]
+            ),
         ),
         tools_dict={
             "my_tool": mock.create_autospec(
-                base_tool_lib.BaseTool, instance=True
+                base_tool_lib.BaseTool, instance=True, spec_set=True
             )
-        },  # Fixed mock
+        },
     )
-
-    await self.plugin.before_model_callback(
-        callback_context=self.callback_context, llm_request=llm_request
+    await bq_plugin_inst.before_model_callback(
+        callback_context=callback_context, llm_request=llm_request
     )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "LLM_REQUEST")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "LLM_REQUEST")
     assert "Model: gemini-pro" in log_entry["content"]
     assert "System Prompt: Be helpful" in log_entry["content"]
     assert (
@@ -398,29 +596,39 @@ async def test_before_model_callback_logs_correctly(self):
     assert "Available Tools: ['my_tool']" in log_entry["content"]
 
   @pytest.mark.asyncio
-  async def test_after_model_callback_text_response(self):
+  async def test_after_model_callback_text_response(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      callback_context,
+      dummy_arrow_schema,
+  ):
     llm_response = llm_response_lib.LlmResponse(
         content=types.Content(parts=[types.Part(text="Model response")]),
         usage_metadata=types.UsageMetadata(
-            prompt_token_count=10,
-            total_token_count=15,
+            prompt_token_count=10, total_token_count=15
         ),
     )
-    await self.plugin.after_model_callback(
-        callback_context=self.callback_context, llm_response=llm_response
+    await bq_plugin_inst.after_model_callback(
+        callback_context=callback_context, llm_response=llm_response
     )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "LLM_RESPONSE")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "LLM_RESPONSE")
     assert (
         "Tool Name: text_response, text: 'Model response'"
         in log_entry["content"]
     )
-    # Adjusted assertion to expect None for candidates
-    assert "Token Usage: {prompt: 10" in log_entry["content"]
+    assert "Token Usage: {prompt: 10," in log_entry["content"]
     assert log_entry["error_message"] is None
 
   @pytest.mark.asyncio
-  async def test_after_model_callback_tool_call(self):
+  async def test_after_model_callback_tool_call(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      callback_context,
+      dummy_arrow_schema,
+  ):
     llm_response = llm_response_lib.LlmResponse(
         content=types.Content(
             parts=[
@@ -430,79 +638,89 @@ async def test_after_model_callback_tool_call(self):
             ]
         ),
     )
-    await self.plugin.after_model_callback(
-        callback_context=self.callback_context, llm_response=llm_response
+    await bq_plugin_inst.after_model_callback(
+        callback_context=callback_context, llm_response=llm_response
     )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "LLM_RESPONSE")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "LLM_RESPONSE")
     assert "Tool Name: tool1" in log_entry["content"]
 
   @pytest.mark.asyncio
-  async def test_before_tool_callback_logs_correctly(self):
-    mock_tool = mock.create_autospec(base_tool_lib.BaseTool, instance=True)
-    mock_tool.name = "MyTool"
-    mock_tool.description = "Does something"
-    tool_args = {"param": "value"}
-    await self.plugin.before_tool_callback(
-        tool=mock_tool, tool_args=tool_args, tool_context=self.tool_context
-    )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "TOOL_STARTING")
+  async def test_before_tool_callback_logs_correctly(
+      self, bq_plugin_inst, mock_write_client, tool_context, dummy_arrow_schema
+  ):
+    mock_tool = mock.create_autospec(
+        base_tool_lib.BaseTool, instance=True, spec_set=True
+    )
+    type(mock_tool).name = mock.PropertyMock(return_value="MyTool")
+    type(mock_tool).description = mock.PropertyMock(
+        return_value="Does something"
+    )
+    await bq_plugin_inst.before_tool_callback(
+        tool=mock_tool, tool_args={"param": "value"}, tool_context=tool_context
+    )
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "TOOL_STARTING")
     assert "Tool Name: MyTool" in log_entry["content"]
-    assert "Description: Does something" in log_entry["content"]
     assert "Arguments: {'param': 'value'}" in log_entry["content"]
 
   @pytest.mark.asyncio
-  async def test_after_tool_callback_logs_correctly(self):
-    mock_tool = mock.create_autospec(base_tool_lib.BaseTool, instance=True)
-    mock_tool.name = "MyTool"
-    tool_args = {"param": "value"}
-    result = {"status": "success"}
-    await self.plugin.after_tool_callback(
+  async def test_after_tool_callback_logs_correctly(
+      self, bq_plugin_inst, mock_write_client, tool_context, dummy_arrow_schema
+  ):
+    mock_tool = mock.create_autospec(
+        base_tool_lib.BaseTool, instance=True, spec_set=True
+    )
+    type(mock_tool).name = mock.PropertyMock(return_value="MyTool")
+    await bq_plugin_inst.after_tool_callback(
         tool=mock_tool,
-        tool_args=tool_args,
-        tool_context=self.tool_context,
-        result=result,
+        tool_args={},
+        tool_context=tool_context,
+        result={"status": "success"},
     )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "TOOL_COMPLETED")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "TOOL_COMPLETED")
     assert "Tool Name: MyTool" in log_entry["content"]
     assert "Result: {'status': 'success'}" in log_entry["content"]
 
   @pytest.mark.asyncio
-  async def test_on_model_error_callback_logs_correctly(self):
+  async def test_on_model_error_callback_logs_correctly(
+      self,
+      bq_plugin_inst,
+      mock_write_client,
+      callback_context,
+      dummy_arrow_schema,
+  ):
     llm_request = llm_request_lib.LlmRequest(
         model="gemini-pro",
         contents=[types.Content(parts=[types.Part(text="Prompt")])],
     )
     error = ValueError("LLM failed")
-    await self.plugin.on_model_error_callback(
-        callback_context=self.callback_context,
-        llm_request=llm_request,
-        error=error,
-    )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "LLM_ERROR")
-    assert (
-        log_entry["content"] is None
-        or "Request Content: " in log_entry["content"]
+    await bq_plugin_inst.on_model_error_callback(
+        callback_context=callback_context, llm_request=llm_request, error=error
     )
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "LLM_ERROR")
+    assert log_entry["content"] is None
     assert log_entry["error_message"] == "LLM failed"
 
   @pytest.mark.asyncio
-  async def test_on_tool_error_callback_logs_correctly(self):
-    mock_tool = mock.create_autospec(base_tool_lib.BaseTool, instance=True)
-    mock_tool.name = "MyTool"
-    tool_args = {"param": "value"}
+  async def test_on_tool_error_callback_logs_correctly(
+      self, bq_plugin_inst, mock_write_client, tool_context, dummy_arrow_schema
+  ):
+    mock_tool = mock.create_autospec(
+        base_tool_lib.BaseTool, instance=True, spec_set=True
+    )
+    type(mock_tool).name = mock.PropertyMock(return_value="MyTool")
     error = TimeoutError("Tool timed out")
-    await self.plugin.on_tool_error_callback(
+    await bq_plugin_inst.on_tool_error_callback(
         tool=mock_tool,
-        tool_args=tool_args,
-        tool_context=self.tool_context,
+        tool_args={"param": "value"},
+        tool_context=tool_context,
         error=error,
     )
-    log_entry = self._get_logged_entry()
-    self._assert_common_fields(log_entry, "TOOL_ERROR")
+    log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
+    _assert_common_fields(log_entry, "TOOL_ERROR")
     assert "Tool Name: MyTool" in log_entry["content"]
     assert "Arguments: {'param': 'value'}" in log_entry["content"]
     assert log_entry["error_message"] == "Tool timed out"
EOF_114329324912

# Run target test with pytest
# Using single-process mode for safety in virtualized environment
# -v for verbose output, --tb=short for concise tracebacks
# --no-header and -rA for structured output
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/unittests/plugins/test_bigquery_logging_plugin.py

# Capture exit code
rc=$?

# Echo exit code for test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout fa5c546a554954c3d9025f52fb99e71649776d7f "tests/unittests/plugins/test_bigquery_logging_plugin.py"