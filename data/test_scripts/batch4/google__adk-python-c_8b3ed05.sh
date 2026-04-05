#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout cf3403231dfc77fb94d4dfa691486707af56cf75 "tests/unittests/sessions/test_session_service.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/sessions/test_session_service.py b/tests/unittests/sessions/test_session_service.py
--- a/tests/unittests/sessions/test_session_service.py
+++ b/tests/unittests/sessions/test_session_service.py
@@ -90,7 +90,7 @@ async def test_create_get_session(service_type):
       await session_service.get_session(
           app_name=app_name, user_id=user_id, session_id=session.id
       )
-      != session
+      is None
   )
 
 
@@ -151,20 +151,17 @@ async def test_list_sessions_all_users(service_type):
       state={'key': 'value2a'},
   )
 
-  # List sessions for user1
+  # List sessions for user1 - should contain merged state
   list_sessions_response_1 = await session_service.list_sessions(
       app_name=app_name, user_id=user_id_1
   )
   sessions_1 = list_sessions_response_1.sessions
   assert len(sessions_1) == 2
-  assert {s.id for s in sessions_1} == {'session1a', 'session1b'}
-  for session in sessions_1:
-    if session.id == 'session1a':
-      assert session.state == {'key': 'value1a'}
-    else:
-      assert session.state == {'key': 'value1b'}
-
-  # List sessions for user2
+  sessions_1_map = {s.id: s for s in sessions_1}
+  assert sessions_1_map['session1a'].state == {'key': 'value1a'}
+  assert sessions_1_map['session1b'].state == {'key': 'value1b'}
+
+  # List sessions for user2 - should contain merged state
   list_sessions_response_2 = await session_service.list_sessions(
       app_name=app_name, user_id=user_id_2
   )
@@ -173,151 +170,170 @@ async def test_list_sessions_all_users(service_type):
   assert sessions_2[0].id == 'session2a'
   assert sessions_2[0].state == {'key': 'value2a'}
 
-  # List sessions for all users
+  # List sessions for all users - should contain merged state
   list_sessions_response_all = await session_service.list_sessions(
       app_name=app_name, user_id=None
   )
   sessions_all = list_sessions_response_all.sessions
   assert len(sessions_all) == 3
-  assert {s.id for s in sessions_all} == {'session1a', 'session1b', 'session2a'}
+  sessions_all_map = {s.id: s for s in sessions_all}
+  assert sessions_all_map['session1a'].state == {'key': 'value1a'}
+  assert sessions_all_map['session1b'].state == {'key': 'value1b'}
+  assert sessions_all_map['session2a'].state == {'key': 'value2a'}
 
 
 @pytest.mark.asyncio
 @pytest.mark.parametrize(
     'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
 )
-async def test_session_state(service_type):
+async def test_app_state_is_shared_by_all_users_of_app(service_type):
   session_service = get_session_service(service_type)
   app_name = 'my_app'
-  user_id_1 = 'user1'
-  user_id_2 = 'user2'
-  user_id_malicious = 'malicious'
-  session_id_11 = 'session11'
-  session_id_12 = 'session12'
-  session_id_2 = 'session2'
-  state_11 = {'key11': 'value11'}
-  state_12 = {'key12': 'value12'}
-
-  session_11 = await session_service.create_session(
-      app_name=app_name,
-      user_id=user_id_1,
-      state=state_11,
-      session_id=session_id_11,
+  # User 1 creates a session, establishing app:k1
+  session1 = await session_service.create_session(
+      app_name=app_name, user_id='u1', session_id='s1', state={'app:k1': 'v1'}
   )
-  await session_service.create_session(
-      app_name=app_name,
-      user_id=user_id_1,
-      state=state_12,
-      session_id=session_id_12,
+  # User 1 appends an event to session1, establishing app:k2
+  event = Event(
+      invocation_id='inv1',
+      author='user',
+      actions=EventActions(state_delta={'app:k2': 'v2'}),
   )
-  await session_service.create_session(
-      app_name=app_name, user_id=user_id_2, session_id=session_id_2
+  await session_service.append_event(session=session1, event=event)
+
+  # User 2 creates a new session session2, it should see app:k1 and app:k2
+  session2 = await session_service.create_session(
+      app_name=app_name, user_id='u2', session_id='s2'
   )
+  assert session2.state == {'app:k1': 'v1', 'app:k2': 'v2'}
 
-  await session_service.create_session(
-      app_name=app_name, user_id=user_id_malicious, session_id=session_id_11
+  # If we get session session1 again, it should also see both
+  session1_got = await session_service.get_session(
+      app_name=app_name, user_id='u1', session_id='s1'
   )
+  assert session1_got.state.get('app:k1') == 'v1'
+  assert session1_got.state.get('app:k2') == 'v2'
 
-  assert session_11.state.get('key11') == 'value11'
 
+@pytest.mark.asyncio
+@pytest.mark.parametrize(
+    'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
+)
+async def test_user_state_is_shared_only_by_user_sessions(service_type):
+  session_service = get_session_service(service_type)
+  app_name = 'my_app'
+  # User 1 creates a session, establishing user:k1 for user 1
+  session1 = await session_service.create_session(
+      app_name=app_name, user_id='u1', session_id='s1', state={'user:k1': 'v1'}
+  )
+  # User 1 appends an event to session1, establishing user:k2 for user 1
   event = Event(
-      invocation_id='invocation',
+      invocation_id='inv1',
       author='user',
-      content=types.Content(role='user', parts=[types.Part(text='text')]),
-      actions=EventActions(
-          state_delta={
-              'app:key': 'value',
-              'user:key1': 'value1',
-              'temp:key': 'temp',
-              'key11': 'value11_new',
-          }
-      ),
+      actions=EventActions(state_delta={'user:k2': 'v2'}),
   )
-  await session_service.append_event(session=session_11, event=event)
-
-  # User and app state is stored, temp state is filtered.
-  assert session_11.state.get('app:key') == 'value'
-  assert session_11.state.get('key11') == 'value11_new'
-  assert session_11.state.get('user:key1') == 'value1'
-  assert not session_11.state.get('temp:key')
+  await session_service.append_event(session=session1, event=event)
 
-  session_12 = await session_service.get_session(
-      app_name=app_name, user_id=user_id_1, session_id=session_id_12
+  # Another session for User 1 should see user:k1 and user:k2
+  session1b = await session_service.create_session(
+      app_name=app_name, user_id='u1', session_id='s1b'
   )
-  # After getting a new instance, the session_12 got the user and app state,
-  # even append_event is not applied to it, temp state has no effect
-  assert session_12.state.get('key12') == 'value12'
-  assert not session_12.state.get('temp:key')
+  assert session1b.state == {'user:k1': 'v1', 'user:k2': 'v2'}
 
-  # The user1's state is not visible to user2, app state is visible
-  session_2 = await session_service.get_session(
-      app_name=app_name, user_id=user_id_2, session_id=session_id_2
+  # A session for User 2 should NOT see user:k1 or user:k2
+  session2 = await session_service.create_session(
+      app_name=app_name, user_id='u2', session_id='s2'
   )
-  assert session_2.state.get('app:key') == 'value'
-  assert not session_2.state.get('user:key1')
+  assert session2.state == {}
 
-  assert not session_2.state.get('user:key1')
 
-  # The change to session_11 is persisted
-  session_11 = await session_service.get_session(
-      app_name=app_name, user_id=user_id_1, session_id=session_id_11
+@pytest.mark.asyncio
+@pytest.mark.parametrize(
+    'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
+)
+async def test_session_state_is_not_shared(service_type):
+  session_service = get_session_service(service_type)
+  app_name = 'my_app'
+  # User 1 creates a session session1, establishing sk1 only for session1
+  session1 = await session_service.create_session(
+      app_name=app_name, user_id='u1', session_id='s1', state={'sk1': 'v1'}
   )
-  assert session_11.state.get('key11') == 'value11_new'
-  assert session_11.state.get('user:key1') == 'value1'
-  assert not session_11.state.get('temp:key')
+  # User 1 appends an event to session1, establishing sk2 only for session1
+  event = Event(
+      invocation_id='inv1',
+      author='user',
+      actions=EventActions(state_delta={'sk2': 'v2'}),
+  )
+  await session_service.append_event(session=session1, event=event)
 
-  # Make sure a malicious user cannot obtain a session and events not belonging to them
-  session_mismatch = await session_service.get_session(
-      app_name=app_name, user_id=user_id_malicious, session_id=session_id_11
+  # Getting session1 should show sk1 and sk2
+  session1_got = await session_service.get_session(
+      app_name=app_name, user_id='u1', session_id='s1'
   )
+  assert session1_got.state.get('sk1') == 'v1'
+  assert session1_got.state.get('sk2') == 'v2'
 
-  assert len(session_mismatch.events) == 0
+  # Creating another session session1b for User 1 should NOT see sk1 or sk2
+  session1b = await session_service.create_session(
+      app_name=app_name, user_id='u1', session_id='s1b'
+  )
+  assert session1b.state == {}
 
 
 @pytest.mark.asyncio
 @pytest.mark.parametrize(
     'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
 )
-async def test_create_new_session_will_merge_states(service_type):
+async def test_temp_state_is_not_persisted_in_state_or_events(service_type):
   session_service = get_session_service(service_type)
   app_name = 'my_app'
-  user_id = 'user'
-  session_id_1 = 'session1'
-  session_id_2 = 'session2'
-  state_1 = {'key1': 'value1'}
-
-  session_1 = await session_service.create_session(
-      app_name=app_name, user_id=user_id, state=state_1, session_id=session_id_1
+  user_id = 'u1'
+  session = await session_service.create_session(
+      app_name=app_name, user_id=user_id, session_id='s1'
   )
-
   event = Event(
-      invocation_id='invocation',
+      invocation_id='inv1',
       author='user',
-      content=types.Content(role='user', parts=[types.Part(text='text')]),
-      actions=EventActions(
-          state_delta={
-              'app:key': 'value',
-              'user:key1': 'value1',
-              'temp:key': 'temp',
-          }
-      ),
+      actions=EventActions(state_delta={'temp:k1': 'v1', 'sk': 'v2'}),
   )
-  await session_service.append_event(session=session_1, event=event)
+  await session_service.append_event(session=session, event=event)
+
+  # Refetch session and check state and event
+  session_got = await session_service.get_session(
+      app_name=app_name, user_id=user_id, session_id='s1'
+  )
+  # Check session state does not contain temp keys
+  assert session_got.state.get('sk') == 'v2'
+  assert 'temp:k1' not in session_got.state
+  # Check event as stored in session does not contain temp keys in state_delta
+  assert 'temp:k1' not in session_got.events[0].actions.state_delta
+  assert session_got.events[0].actions.state_delta.get('sk') == 'v2'
 
-  # User and app state is stored, temp state is filtered.
-  assert session_1.state.get('app:key') == 'value'
-  assert session_1.state.get('key1') == 'value1'
-  assert session_1.state.get('user:key1') == 'value1'
-  assert not session_1.state.get('temp:key')
 
-  session_2 = await session_service.create_session(
-      app_name=app_name, user_id=user_id, state={}, session_id=session_id_2
+@pytest.mark.asyncio
+@pytest.mark.parametrize(
+    'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
+)
+async def test_get_session_respects_user_id(service_type):
+  session_service = get_session_service(service_type)
+  app_name = 'my_app'
+  # u1 creates session 's1' and adds an event
+  session1 = await session_service.create_session(
+      app_name=app_name, user_id='u1', session_id='s1'
+  )
+  event = Event(invocation_id='inv1', author='user')
+  await session_service.append_event(session1, event)
+  # u2 creates a session with the same session_id 's1'
+  await session_service.create_session(
+      app_name=app_name, user_id='u2', session_id='s1'
+  )
+  # Check that getting s1 for u2 returns u2's session (with no events)
+  # not u1's session.
+  session2_got = await session_service.get_session(
+      app_name=app_name, user_id='u2', session_id='s1'
   )
-  # Session 2 has the persisted states
-  assert session_2.state.get('app:key') == 'value'
-  assert session_2.state.get('user:key1') == 'value1'
-  assert not session_2.state.get('key1')
-  assert not session_2.state.get('temp:key')
+  assert session2_got.user_id == 'u2'
+  assert len(session2_got.events) == 0
 
 
 @pytest.mark.asyncio
@@ -390,6 +406,9 @@ async def test_append_event_complete(service_type):
       error_code='error_code',
       error_message='error_message',
       interrupted=True,
+      grounding_metadata=types.GroundingMetadata(
+          web_search_queries=['query1'],
+      ),
       usage_metadata=types.GenerateContentResponseUsageMetadata(
           prompt_token_count=1, candidates_token_count=1, total_token_count=2
       ),
@@ -474,72 +493,20 @@ async def test_get_session_with_config(service_type):
 @pytest.mark.parametrize(
     'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
 )
-async def test_append_event_with_fields(service_type):
-  session_service = get_session_service(service_type)
-  app_name = 'my_app'
-  user_id = 'test_user'
-  session = await session_service.create_session(
-      app_name=app_name, user_id=user_id, state={}
-  )
-
-  event = Event(
-      invocation_id='invocation',
-      author='user',
-      content=types.Content(role='user', parts=[types.Part(text='text')]),
-      long_running_tool_ids={'tool1', 'tool2'},
-      partial=False,
-      turn_complete=True,
-      error_code='ERROR_CODE',
-      error_message='error message',
-      interrupted=True,
-      grounding_metadata=types.GroundingMetadata(
-          web_search_queries=['query1'],
-      ),
-      custom_metadata={'custom_key': 'custom_value'},
-  )
-  await session_service.append_event(session, event)
-
-  retrieved_session = await session_service.get_session(
-      app_name=app_name, user_id=user_id, session_id=session.id
-  )
-  assert retrieved_session
-  assert len(retrieved_session.events) == 1
-  retrieved_event = retrieved_session.events[0]
-
-  assert retrieved_event == event
-
-
-@pytest.mark.asyncio
-@pytest.mark.parametrize(
-    'service_type', [SessionServiceType.IN_MEMORY, SessionServiceType.DATABASE]
-)
-async def test_append_event_should_trim_temp_delta_state(service_type):
+async def test_partial_events_are_not_persisted(service_type):
   session_service = get_session_service(service_type)
   app_name = 'my_app'
   user_id = 'user'
-
   session = await session_service.create_session(
       app_name=app_name, user_id=user_id
   )
-
-  event = Event(
-      invocation_id='invocation',
-      author='user',
-      content=types.Content(role='user', parts=[types.Part(text='text')]),
-      actions=EventActions(
-          state_delta={
-              'app:key': 'app_value',
-              'temp:key': 'temp_value',
-          }
-      ),
-  )
-
+  event = Event(author='user', partial=True)
   await session_service.append_event(session, event)
 
-  updated_session = await session_service.get_session(
+  # Check in-memory session
+  assert len(session.events) == 0
+  # Check persisted session
+  session_got = await session_service.get_session(
       app_name=app_name, user_id=user_id, session_id=session.id
   )
-
-  last_event = updated_session.events[-1]
-  assert 'temp:key' not in last_event.actions.state_delta
-  assert last_event.actions.state_delta['app:key'] == 'app_value'
+  assert len(session_got.events) == 0
EOF_114329324912

# Run the specific test file
# Using pytest with single-process mode for safety in virtualized environment
# --no-header: suppress header information
# -rA: show all test outcomes (passed, failed, skipped, etc.)
# --tb=short: use short traceback format for cleaner output
# -p no:cacheprovider: disable cache for clean test execution
pytest --no-header -rA --tb=short -p no:cacheprovider tests/unittests/sessions/test_session_service.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout cf3403231dfc77fb94d4dfa691486707af56cf75 "tests/unittests/sessions/test_session_service.py"