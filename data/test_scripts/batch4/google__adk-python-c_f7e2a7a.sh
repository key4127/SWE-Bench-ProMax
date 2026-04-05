#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 48ddd078941f9240b10f052b6de171c310bc2bc6 "tests/unittests/sessions/test_vertex_ai_session_service.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/sessions/test_vertex_ai_session_service.py b/tests/unittests/sessions/test_vertex_ai_session_service.py
--- a/tests/unittests/sessions/test_vertex_ai_session_service.py
+++ b/tests/unittests/sessions/test_vertex_ai_session_service.py
@@ -235,22 +235,24 @@ def __init__(self) -> None:
     """Initializes MockClient."""
     self.session_dict: dict[str, Any] = {}
     self.event_dict: dict[str, Tuple[List[Any], Optional[str]]] = {}
-    self.agent_engines = mock.Mock()
-    self.agent_engines.sessions.get.side_effect = self._get_session
-    self.agent_engines.sessions.list.side_effect = self._list_sessions
-    self.agent_engines.sessions.delete.side_effect = self._delete_session
-    self.agent_engines.sessions.create.side_effect = self._create_session
-    self.agent_engines.sessions.events.list.side_effect = self._list_events
-    self.agent_engines.sessions.events.append.side_effect = self._append_event
+    self.aio = mock.Mock()
+    self.aio.agent_engines.sessions.get.side_effect = self._get_session
+    self.aio.agent_engines.sessions.list.side_effect = self._list_sessions
+    self.aio.agent_engines.sessions.delete.side_effect = self._delete_session
+    self.aio.agent_engines.sessions.create.side_effect = self._create_session
+    self.aio.agent_engines.sessions.events.list.side_effect = self._list_events
+    self.aio.agent_engines.sessions.events.append.side_effect = (
+        self._append_event
+    )
     self.last_create_session_config: dict[str, Any] = {}
 
-  def _get_session(self, name: str):
+  async def _get_session(self, name: str):
     session_id = name.split('/')[-1]
     if session_id in self.session_dict:
       return _convert_to_object(self.session_dict[session_id])
     raise api_core_exceptions.NotFound(f'Session not found: {session_id}')
 
-  def _list_sessions(self, name: str, config: dict[str, Any]):
+  async def _list_sessions(self, name: str, config: dict[str, Any]):
     filter_val = config.get('filter', '')
     user_id_match = re.search(r'user_id="([^"]+)"', filter_val)
     if user_id_match:
@@ -271,11 +273,13 @@ def _list_sessions(self, name: str, config: dict[str, Any]):
         _convert_to_object(session) for session in self.session_dict.values()
     ]
 
-  def _delete_session(self, name: str):
+  async def _delete_session(self, name: str):
     session_id = name.split('/')[-1]
     self.session_dict.pop(session_id)
 
-  def _create_session(self, name: str, user_id: str, config: dict[str, Any]):
+  async def _create_session(
+      self, name: str, user_id: str, config: dict[str, Any]
+  ):
     self.last_create_session_config = config
     new_session_id = '4'
     self.session_dict[new_session_id] = {
@@ -299,7 +303,7 @@ def _create_session(self, name: str, user_id: str, config: dict[str, Any]):
         'response': self.session_dict['4'],
     })
 
-  def _list_events(self, name: str, **kwargs):
+  async def _list_events(self, name: str, **kwargs):
     session_id = name.split('/')[-1]
     events = []
     if session_id in self.event_dict:
@@ -322,7 +326,7 @@ def _list_events(self, name: str, **kwargs):
         ]
     return [_convert_to_object(event) for event in events]
 
-  def _append_event(
+  async def _append_event(
       self,
       name: str,
       author: str,
EOF_114329324912

# Execute the target test file using pytest
# Running in single-process mode for safety in virtualized environment
pytest --no-header -rA --tb=short -p no:cacheprovider -v \
    tests/unittests/sessions/test_vertex_ai_session_service.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 48ddd078941f9240b10f052b6de171c310bc2bc6 "tests/unittests/sessions/test_vertex_ai_session_service.py"