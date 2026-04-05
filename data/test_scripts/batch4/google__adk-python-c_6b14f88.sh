#!/bin/bash
set -uxo pipefail
cd /testbed

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Checkout the original test file to ensure clean state
git checkout 42d4c4ed5ff292d54bc5382f9fb274ec98becaba "tests/unittests/plugins/test_bigquery_logging_plugin.py"

# Apply test patch to update target tests (this renames the file)
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/plugins/test_bigquery_logging_plugin.py b/tests/unittests/plugins/test_bigquery_agent_analytics_plugin.py
rename from tests/unittests/plugins/test_bigquery_logging_plugin.py
rename to tests/unittests/plugins/test_bigquery_agent_analytics_plugin.py
--- a/tests/unittests/plugins/test_bigquery_logging_plugin.py
+++ b/tests/unittests/plugins/test_bigquery_agent_analytics_plugin.py
@@ -12,8 +12,7 @@
 # See the License for the specific language governing permissions and
 # limitations under the License.
 
-from __future__ import annotations
-
+import asyncio
 import datetime
 import json
 import logging
@@ -25,7 +24,7 @@
 from google.adk.events import event as event_lib
 from google.adk.models import llm_request as llm_request_lib
 from google.adk.models import llm_response as llm_response_lib
-from google.adk.plugins import bigquery_logging_plugin
+from google.adk.plugins import bigquery_agent_analytics_plugin
 from google.adk.plugins import plugin_manager as plugin_manager_lib
 from google.adk.sessions import base_session_service as base_session_service_lib
 from google.adk.sessions import session as session_lib
@@ -35,11 +34,12 @@
 from google.auth import exceptions as auth_exceptions
 import google.auth.credentials
 from google.cloud import bigquery
+from google.cloud.bigquery_storage_v1 import types as bq_storage_types
 from google.genai import types
 import pyarrow as pa
 import pytest
 
-BigQueryLoggerConfig = bigquery_logging_plugin.BigQueryLoggerConfig
+BigQueryLoggerConfig = bigquery_agent_analytics_plugin.BigQueryLoggerConfig
 
 PROJECT_ID = "test-gcp-project"
 DATASET_ID = "adk_logs"
@@ -125,25 +125,28 @@ def mock_bq_client():
 @pytest.fixture
 def mock_write_client():
   with mock.patch.object(
-      bigquery_logging_plugin, "BigQueryWriteAsyncClient", autospec=True
+      bigquery_agent_analytics_plugin, "BigQueryWriteAsyncClient", autospec=True
   ) as mock_cls:
     mock_client = mock_cls.return_value
-    mock_append_rows_response = mock.MagicMock()
-    # Configure the 'row_errors' attribute on the mock object.
-    mock_append_rows_response.row_errors = []
-    mock_append_rows_response.error = mock.MagicMock()
-    mock_append_rows_response.error.code = 0  # OK status
-
-    mock_client.append_rows.return_value = _async_gen(mock_append_rows_response)
+    mock_client.transport = mock.AsyncMock()
+
+    async def fake_append_rows(requests, **kwargs):
+      # This function is now async, so `await client.append_rows` works.
+      mock_append_rows_response = mock.MagicMock()
+      mock_append_rows_response.row_errors = []
+      mock_append_rows_response.error = mock.MagicMock()
+      mock_append_rows_response.error.code = 0  # OK status
+      # This a gen is what's returned *after* the await.
+      return _async_gen(mock_append_rows_response)
+
+    mock_client.append_rows.side_effect = fake_append_rows
     yield mock_client
 
 
 @pytest.fixture
 def dummy_arrow_schema():
   return pa.schema([
-      pa.field(
-          "timestamp", pa.string()
-      ),  # Store as string for simplicity in test
+      pa.field("timestamp", pa.timestamp("us", tz="UTC")),
       pa.field("event_type", pa.string()),
       pa.field("agent", pa.string()),
       pa.field("session_id", pa.string()),
@@ -157,7 +160,7 @@ def dummy_arrow_schema():
 @pytest.fixture
 def mock_to_arrow_schema(dummy_arrow_schema):
   with mock.patch.object(
-      bigquery_logging_plugin,
+      bigquery_agent_analytics_plugin,
       "to_arrow_schema",
       autospec=True,
       return_value=dummy_arrow_schema,
@@ -177,19 +180,19 @@ async def fake_to_thread(func, *args, **kwargs):
 
 
 @pytest.fixture
-def bq_plugin_inst(
+async def bq_plugin_inst(
     mock_auth_default,
     mock_bq_client,
     mock_write_client,
     mock_to_arrow_schema,
+    mock_asyncio_to_thread,
 ):
-  plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+  plugin = bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
       project_id=PROJECT_ID,
       dataset_id=DATASET_ID,
       table_id=TABLE_ID,
   )
-  # Trigger lazy initialization
-  plugin._ensure_initialized_sync()
+  await plugin._ensure_init()  # Ensure clients are initialized
   mock_write_client.append_rows.reset_mock()
   return plugin
 
@@ -205,7 +208,8 @@ def _get_captured_event_dict(mock_write_client, expected_schema):
   """Helper to get the event_dict passed to append_rows."""
   mock_write_client.append_rows.assert_called_once()
   call_args = mock_write_client.append_rows.call_args
-  requests = call_args.kwargs["requests"]
+  requests_iter = call_args.args[0]
+  requests = list(requests_iter)
   assert len(requests) == 1
   request = requests[0]
   assert request.write_stream == DEFAULT_STREAM_NAME
@@ -228,7 +232,7 @@ def _assert_common_fields(log_entry, event_type, agent="MyTestAgent"):
   assert log_entry["invocation_id"] == "inv-789"
   assert log_entry["user_id"] == "user-456"
   assert "timestamp" in log_entry
-  assert isinstance(log_entry["timestamp"], str)
+  assert isinstance(log_entry["timestamp"], datetime.datetime)
 
 
 # --- Test Class ---
@@ -245,17 +249,17 @@ async def test_plugin_disabled(
       invocation_context,
   ):
     config = BigQueryLoggerConfig(enabled=False)
-    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+    plugin = bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
         project_id=PROJECT_ID,
         dataset_id=DATASET_ID,
         table_id=TABLE_ID,
         config=config,
     )
-    plugin._ensure_initialized_sync()  # Should do nothing
-    user_message = types.Content(parts=[types.Part(text="Test")])
+    # user_message = types.Content(parts=[types.Part(text="Test")])
 
     await plugin.on_user_message_callback(
-        invocation_context=invocation_context, user_message=user_message
+        invocation_context=invocation_context,
+        user_message=types.Content(parts=[types.Part(text="Test")]),
     )
     mock_auth_default.assert_not_called()
     mock_bq_client.assert_not_called()
@@ -271,12 +275,13 @@ async def test_event_allowlist(
       mock_bq_client,
       mock_to_arrow_schema,
       dummy_arrow_schema,
+      mock_asyncio_to_thread,
   ):
     config = BigQueryLoggerConfig(event_allowlist=["LLM_REQUEST"])
-    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+    plugin = bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
         PROJECT_ID, DATASET_ID, TABLE_ID, config
     )
-    plugin._ensure_initialized_sync()
+    await plugin._ensure_init()
     mock_write_client.append_rows.reset_mock()
 
     llm_request = llm_request_lib.LlmRequest(
@@ -286,13 +291,15 @@ async def test_event_allowlist(
     await plugin.before_model_callback(
         callback_context=callback_context, llm_request=llm_request
     )
+    await asyncio.sleep(0.01)  # Allow background task to run
     mock_write_client.append_rows.assert_called_once()
     mock_write_client.append_rows.reset_mock()
 
     user_message = types.Content(parts=[types.Part(text="What is up?")])
     await plugin.on_user_message_callback(
         invocation_context=invocation_context, user_message=user_message
     )
+    await asyncio.sleep(0.01)  # Allow background task to run
     mock_write_client.append_rows.assert_not_called()
 
   @pytest.mark.asyncio
@@ -304,21 +311,24 @@ async def test_event_denylist(
       mock_bq_client,
       mock_to_arrow_schema,
       dummy_arrow_schema,
+      mock_asyncio_to_thread,
   ):
     config = BigQueryLoggerConfig(event_denylist=["USER_MESSAGE_RECEIVED"])
-    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+    plugin = bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
         PROJECT_ID, DATASET_ID, TABLE_ID, config
     )
-    plugin._ensure_initialized_sync()
+    await plugin._ensure_init()
     mock_write_client.append_rows.reset_mock()
 
     user_message = types.Content(parts=[types.Part(text="What is up?")])
     await plugin.on_user_message_callback(
         invocation_context=invocation_context, user_message=user_message
     )
+    await asyncio.sleep(0.01)
     mock_write_client.append_rows.assert_not_called()
 
     await plugin.before_run_callback(invocation_context=invocation_context)
+    await asyncio.sleep(0.01)
     mock_write_client.append_rows.assert_called_once()
 
   @pytest.mark.asyncio
@@ -330,24 +340,26 @@ async def test_content_formatter(
       mock_bq_client,
       mock_to_arrow_schema,
       dummy_arrow_schema,
+      mock_asyncio_to_thread,
   ):
     def redact_content(content):
       return "[REDACTED]"
 
     config = BigQueryLoggerConfig(content_formatter=redact_content)
-    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+    plugin = bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
         PROJECT_ID, DATASET_ID, TABLE_ID, config
     )
-    plugin._ensure_initialized_sync()
+    await plugin._ensure_init()
     mock_write_client.append_rows.reset_mock()
 
     user_message = types.Content(parts=[types.Part(text="Secret message")])
     await plugin.on_user_message_callback(
         invocation_context=invocation_context, user_message=user_message
     )
+    await asyncio.sleep(0.01)
+    mock_write_client.append_rows.assert_called_once()
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
-    _assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
-    assert log_entry["content"] == "[REDACTED]"
+    assert log_entry["content"] == "User Content: [REDACTED]"
 
   @pytest.mark.asyncio
   async def test_content_formatter_error(
@@ -358,31 +370,26 @@ async def test_content_formatter_error(
       mock_bq_client,
       mock_to_arrow_schema,
       dummy_arrow_schema,
+      mock_asyncio_to_thread,
   ):
     def error_formatter(content):
       raise ValueError("Formatter failed")
 
     config = BigQueryLoggerConfig(content_formatter=error_formatter)
-    plugin = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
+    plugin = bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
         PROJECT_ID, DATASET_ID, TABLE_ID, config
     )
-    plugin._ensure_initialized_sync()
+    await plugin._ensure_init()
     mock_write_client.append_rows.reset_mock()
-    user_message = types.Content(parts=[types.Part(text="Test")])
-
-    with mock.patch.object(logging, "warning") as mock_log_warning:
-      await plugin.on_user_message_callback(
-          invocation_context=invocation_context, user_message=user_message
-      )
-      mock_log_warning.assert_called_once_with(
-          "Error applying custom content formatter for event type %s: %s",
-          "USER_MESSAGE_RECEIVED",
-          mock.ANY,
-      )
 
+    user_message = types.Content(parts=[types.Part(text="Secret message")])
+    await plugin.on_user_message_callback(
+        invocation_context=invocation_context, user_message=user_message
+    )
+    await asyncio.sleep(0.01)
+    mock_write_client.append_rows.assert_called_once()
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
-    _assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
-    assert "User Content: text: 'Test'" in log_entry["content"]
+    assert log_entry["content"] == "User Content: [FORMATTING FAILED]"
 
   @pytest.mark.asyncio
   async def test_on_user_message_callback_logs_correctly(
@@ -396,6 +403,7 @@ async def test_on_user_message_callback_logs_correctly(
     await bq_plugin_inst.on_user_message_callback(
         invocation_context=invocation_context, user_message=user_message
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "USER_MESSAGE_RECEIVED")
     assert log_entry["content"] == "User Content: text: 'What is up?'"
@@ -419,12 +427,13 @@ async def test_on_event_callback_tool_call(
     await bq_plugin_inst.on_event_callback(
         invocation_context=invocation_context, event=event
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
-    _assert_common_fields(log_entry, "TOOL_CALL")
-    logged_content = json.loads(log_entry["content"])
-    assert logged_content[0]["function_call"]["args"] == {"location": "Paris"}
-    assert logged_content[0]["function_call"]["name"] == "get_weather"
-    assert log_entry["timestamp"] == "2025-10-22T10:00:00+00:00"
+    _assert_common_fields(log_entry, "TOOL_CALL", agent="MyTestAgent")
+    assert '"name": "get_weather"' in log_entry["content"]
+    assert log_entry["timestamp"] == datetime.datetime(
+        2025, 10, 22, 10, 0, 0, tzinfo=datetime.timezone.utc
+    )
 
   @pytest.mark.asyncio
   async def test_on_event_callback_model_response(
@@ -444,57 +453,74 @@ async def test_on_event_callback_model_response(
     await bq_plugin_inst.on_event_callback(
         invocation_context=invocation_context, event=event
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
-    _assert_common_fields(log_entry, "MODEL_RESPONSE")
-    logged_content = json.loads(log_entry["content"])
-    assert logged_content[0]["text"] == "Hello there!"
-    assert log_entry["timestamp"] == "2025-10-22T11:00:00+00:00"
+    _assert_common_fields(log_entry, "MODEL_RESPONSE", agent="MyTestAgent")
+    assert '"text": "Hello there!"' in log_entry["content"]
+    assert log_entry["timestamp"] == datetime.datetime(
+        2025, 10, 22, 11, 0, 0, tzinfo=datetime.timezone.utc
+    )
 
   @pytest.mark.asyncio
   async def test_bigquery_client_initialization_failure(
-      self, mock_auth_default, mock_write_client, invocation_context
+      self,
+      mock_auth_default,
+      mock_write_client,
+      invocation_context,
+      mock_asyncio_to_thread,
   ):
     mock_auth_default.side_effect = auth_exceptions.GoogleAuthError(
         "Auth failed"
     )
-    plugin_with_fail = bigquery_logging_plugin.BigQueryAgentAnalyticsPlugin(
-        project_id=PROJECT_ID,
-        dataset_id=DATASET_ID,
-        table_id=TABLE_ID,
+    plugin_with_fail = (
+        bigquery_agent_analytics_plugin.BigQueryAgentAnalyticsPlugin(
+            project_id=PROJECT_ID,
+            dataset_id=DATASET_ID,
+            table_id=TABLE_ID,
+        )
     )
-    with mock.patch.object(logging, "exception") as mock_log_exception:
+    with mock.patch.object(logging, "error") as mock_log_error:
       await plugin_with_fail.on_user_message_callback(
           invocation_context=invocation_context,
           user_message=types.Content(parts=[types.Part(text="Test")]),
       )
-      mock_log_exception.assert_called_once_with(
-          "Failed to initialize BigQuery client or table: %s", mock.ANY
-      )
+      await asyncio.sleep(0.01)
+      mock_log_error.assert_any_call("BQ Init Failed: Auth failed")
     mock_write_client.append_rows.assert_not_called()
 
   @pytest.mark.asyncio
   async def test_bigquery_insert_error_does_not_raise(
       self, bq_plugin_inst, mock_write_client, invocation_context
   ):
-    mock_append_rows_response = mock.MagicMock()
-    mock_append_rows_response.row_errors = [mock.MagicMock()]
-    mock_append_rows_response.error = mock.MagicMock()
-    mock_append_rows_response.error.code = 0
-    mock_write_client.append_rows.return_value = _async_gen(
-        mock_append_rows_response
-    )
+
+    async def fake_append_rows_with_error(requests, **kwargs):
+      mock_append_rows_response = mock.MagicMock()
+      mock_append_rows_response.row_errors = []  # No row errors
+      mock_append_rows_response.error = mock.MagicMock()
+      mock_append_rows_response.error.code = 3  # INVALID_ARGUMENT
+      mock_append_rows_response.error.message = "Test BQ Error"
+      return _async_gen(mock_append_rows_response)
+
+    mock_write_client.append_rows.side_effect = fake_append_rows_with_error
 
     with mock.patch.object(logging, "error") as mock_log_error:
       await bq_plugin_inst.on_user_message_callback(
           invocation_context=invocation_context,
           user_message=types.Content(parts=[types.Part(text="Test")]),
       )
-      mock_log_error.assert_called_with(
-          "Errors occurred while writing to BigQuery (Storage Write API): %s",
-          mock_append_rows_response.row_errors,
-      )
+      await asyncio.sleep(0.01)
+      mock_log_error.assert_called_with("BQ Write Error: Test BQ Error")
     mock_write_client.append_rows.assert_called_once()
 
+  @pytest.mark.asyncio
+  async def test_shutdown(
+      self, bq_plugin_inst, mock_bq_client, mock_write_client
+  ):
+    await bq_plugin_inst.shutdown()
+    mock_write_client.transport.close.assert_called_once()
+    mock_bq_client.close.assert_called_once()
+
+  # ... other tests remain the same ...
   @pytest.mark.asyncio
   async def test_before_run_callback_logs_correctly(
       self,
@@ -506,6 +532,7 @@ async def test_before_run_callback_logs_correctly(
     await bq_plugin_inst.before_run_callback(
         invocation_context=invocation_context
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "INVOCATION_STARTING")
     assert log_entry["content"] is None
@@ -521,6 +548,7 @@ async def test_after_run_callback_logs_correctly(
     await bq_plugin_inst.after_run_callback(
         invocation_context=invocation_context
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "INVOCATION_COMPLETED")
     assert log_entry["content"] is None
@@ -537,6 +565,7 @@ async def test_before_agent_callback_logs_correctly(
     await bq_plugin_inst.before_agent_callback(
         agent=mock_agent, callback_context=callback_context
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "AGENT_STARTING")
     assert log_entry["content"] == "Agent Name: MyTestAgent"
@@ -553,6 +582,7 @@ async def test_after_agent_callback_logs_correctly(
     await bq_plugin_inst.after_agent_callback(
         agent=mock_agent, callback_context=callback_context
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "AGENT_COMPLETED")
     assert log_entry["content"] == "Agent Name: MyTestAgent"
@@ -568,32 +598,14 @@ async def test_before_model_callback_logs_correctly(
     llm_request = llm_request_lib.LlmRequest(
         model="gemini-pro",
         contents=[types.Content(parts=[types.Part(text="Prompt")])],
-        config=types.GenerateContentConfig(
-            temperature=0.5,
-            top_p=0.9,
-            max_output_tokens=100,
-            system_instruction=types.Content(
-                parts=[types.Part(text="Be helpful")]
-            ),
-        ),
-        tools_dict={
-            "my_tool": mock.create_autospec(
-                base_tool_lib.BaseTool, instance=True, spec_set=True
-            )
-        },
     )
     await bq_plugin_inst.before_model_callback(
         callback_context=callback_context, llm_request=llm_request
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "LLM_REQUEST")
-    assert "Model: gemini-pro" in log_entry["content"]
-    assert "System Prompt: Be helpful" in log_entry["content"]
-    assert (
-        "Params: {temperature=0.5, top_p=0.9, max_output_tokens=100}"
-        in log_entry["content"]
-    )
-    assert "Available Tools: ['my_tool']" in log_entry["content"]
+    assert log_entry["content"] == "Model: gemini-pro | System Prompt: Empty"
 
   @pytest.mark.asyncio
   async def test_after_model_callback_text_response(
@@ -612,13 +624,16 @@ async def test_after_model_callback_text_response(
     await bq_plugin_inst.after_model_callback(
         callback_context=callback_context, llm_response=llm_response
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "LLM_RESPONSE")
     assert (
         "Tool Name: text_response, text: 'Model response'"
         in log_entry["content"]
     )
-    assert "Token Usage: {prompt: 10," in log_entry["content"]
+    assert "Token Usage:" in log_entry["content"]
+    assert "prompt: 10" in log_entry["content"]
+    assert "total: 15" in log_entry["content"]
     assert log_entry["error_message"] is None
 
   @pytest.mark.asyncio
@@ -629,21 +644,24 @@ async def test_after_model_callback_tool_call(
       callback_context,
       dummy_arrow_schema,
   ):
+    tool_fc = types.FunctionCall(name="get_weather", args={"location": "Paris"})
     llm_response = llm_response_lib.LlmResponse(
-        content=types.Content(
-            parts=[
-                types.Part(
-                    function_call=types.FunctionCall(name="tool1", args={})
-                )
-            ]
+        content=types.Content(parts=[types.Part(function_call=tool_fc)]),
+        usage_metadata=types.UsageMetadata(
+            prompt_token_count=10, total_token_count=15
         ),
     )
     await bq_plugin_inst.after_model_callback(
         callback_context=callback_context, llm_response=llm_response
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "LLM_RESPONSE")
-    assert "Tool Name: tool1" in log_entry["content"]
+    assert "Tool Name: get_weather" in log_entry["content"]
+    assert "Token Usage:" in log_entry["content"]
+    assert "prompt: 10" in log_entry["content"]
+    assert "total: 15" in log_entry["content"]
+    assert log_entry["error_message"] is None
 
   @pytest.mark.asyncio
   async def test_before_tool_callback_logs_correctly(
@@ -653,16 +671,18 @@ async def test_before_tool_callback_logs_correctly(
         base_tool_lib.BaseTool, instance=True, spec_set=True
     )
     type(mock_tool).name = mock.PropertyMock(return_value="MyTool")
-    type(mock_tool).description = mock.PropertyMock(
-        return_value="Does something"
-    )
+    type(mock_tool).description = mock.PropertyMock(return_value="Description")
     await bq_plugin_inst.before_tool_callback(
         tool=mock_tool, tool_args={"param": "value"}, tool_context=tool_context
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "TOOL_STARTING")
-    assert "Tool Name: MyTool" in log_entry["content"]
-    assert "Arguments: {'param': 'value'}" in log_entry["content"]
+    assert (
+        log_entry["content"]
+        == 'Tool Name: MyTool, Description: Description, Arguments: {"param":'
+        ' "value"}'
+    )
 
   @pytest.mark.asyncio
   async def test_after_tool_callback_logs_correctly(
@@ -672,16 +692,20 @@ async def test_after_tool_callback_logs_correctly(
         base_tool_lib.BaseTool, instance=True, spec_set=True
     )
     type(mock_tool).name = mock.PropertyMock(return_value="MyTool")
+    type(mock_tool).description = mock.PropertyMock(return_value="Description")
     await bq_plugin_inst.after_tool_callback(
         tool=mock_tool,
         tool_args={},
         tool_context=tool_context,
         result={"status": "success"},
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "TOOL_COMPLETED")
-    assert "Tool Name: MyTool" in log_entry["content"]
-    assert "Result: {'status': 'success'}" in log_entry["content"]
+    assert (
+        log_entry["content"]
+        == 'Tool Name: MyTool, Result: {"status": "success"}'
+    )
 
   @pytest.mark.asyncio
   async def test_on_model_error_callback_logs_correctly(
@@ -699,6 +723,7 @@ async def test_on_model_error_callback_logs_correctly(
     await bq_plugin_inst.on_model_error_callback(
         callback_context=callback_context, llm_request=llm_request, error=error
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "LLM_ERROR")
     assert log_entry["content"] is None
@@ -712,15 +737,19 @@ async def test_on_tool_error_callback_logs_correctly(
         base_tool_lib.BaseTool, instance=True, spec_set=True
     )
     type(mock_tool).name = mock.PropertyMock(return_value="MyTool")
+    type(mock_tool).description = mock.PropertyMock(return_value="Description")
     error = TimeoutError("Tool timed out")
     await bq_plugin_inst.on_tool_error_callback(
         tool=mock_tool,
         tool_args={"param": "value"},
         tool_context=tool_context,
         error=error,
     )
+    await asyncio.sleep(0.01)
     log_entry = _get_captured_event_dict(mock_write_client, dummy_arrow_schema)
     _assert_common_fields(log_entry, "TOOL_ERROR")
-    assert "Tool Name: MyTool" in log_entry["content"]
-    assert "Arguments: {'param': 'value'}" in log_entry["content"]
+    assert (
+        log_entry["content"]
+        == 'Tool Name: MyTool, Arguments: {"param": "value"}'
+    )
     assert log_entry["error_message"] == "Tool timed out"
EOF_114329324912

# Run target test with pytest using the NEW filename after patch application
# Using single-process mode for safety in virtualized environment
# -v for verbose output, --tb=short for concise tracebacks
# --no-header and -rA for structured output
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/unittests/plugins/test_bigquery_agent_analytics_plugin.py

# Capture exit code
rc=$?

# Echo exit code for test log analysis agent
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file using its original name
git checkout 42d4c4ed5ff292d54bc5382f9fb274ec98becaba "tests/unittests/plugins/test_bigquery_logging_plugin.py"