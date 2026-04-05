#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the target commit
git checkout 0ccc155457500278e5287dbdd7ba5ae80bbe08f4

# Checkout the specific test file to ensure clean state
git checkout 0ccc155457500278e5287dbdd7ba5ae80bbe08f4 "conftest.py"

# Apply test patch to add/modify test files
git apply -v - <<'EOF_114329324912'
diff --git a/conftest.py b/conftest.py
--- a/conftest.py
+++ b/conftest.py
@@ -120,6 +120,8 @@ def setup_test_environment() -> Generator[None, Any, None]:
     "accept-encoding": "ACCEPT-ENCODING-XXX",
     "x-amzn-requestid": "X-AMZN-REQUESTID-XXX",
     "x-amzn-RequestId": "X-AMZN-REQUESTID-XXX",
+    "x-a2a-notification-token": "X-A2A-NOTIFICATION-TOKEN-XXX",
+    "x-a2a-version": "X-A2A-VERSION-XXX",
 }
 
 
diff --git a/lib/crewai/tests/a2a/test_a2a_integration.py b/lib/crewai/tests/a2a/test_a2a_integration.py
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/a2a/test_a2a_integration.py
@@ -0,0 +1,323 @@
+from __future__ import annotations
+
+import os
+import uuid
+
+import pytest
+import pytest_asyncio
+
+from a2a.client import ClientFactory
+from a2a.types import AgentCard, Message, Part, Role, TaskState, TextPart
+
+from crewai.a2a.updates.polling.handler import PollingHandler
+from crewai.a2a.updates.streaming.handler import StreamingHandler
+
+
+A2A_TEST_ENDPOINT = os.getenv("A2A_TEST_ENDPOINT", "http://localhost:9999")
+
+
+@pytest_asyncio.fixture
+async def a2a_client():
+    """Create A2A client for test server."""
+    client = await ClientFactory.connect(A2A_TEST_ENDPOINT)
+    yield client
+    await client.close()
+
+
+@pytest.fixture
+def test_message() -> Message:
+    """Create a simple test message."""
+    return Message(
+        role=Role.user,
+        parts=[Part(root=TextPart(text="What is 2 + 2?"))],
+        message_id=str(uuid.uuid4()),
+    )
+
+
+@pytest_asyncio.fixture
+async def agent_card(a2a_client) -> AgentCard:
+    """Fetch the real agent card from the server."""
+    return await a2a_client.get_card()
+
+
+class TestA2AAgentCardFetching:
+    """Integration tests for agent card fetching."""
+
+    @pytest.mark.vcr()
+    @pytest.mark.asyncio
+    async def test_fetch_agent_card(self, a2a_client) -> None:
+        """Test fetching an agent card from the server."""
+        card = await a2a_client.get_card()
+
+        assert card is not None
+        assert card.name == "GPT Assistant"
+        assert card.url is not None
+        assert card.capabilities is not None
+        assert card.capabilities.streaming is True
+
+
+class TestA2APollingIntegration:
+    """Integration tests for A2A polling handler."""
+
+    @pytest.mark.vcr()
+    @pytest.mark.asyncio
+    async def test_polling_completes_task(
+        self,
+        a2a_client,
+        test_message: Message,
+        agent_card: AgentCard,
+    ) -> None:
+        """Test that polling handler completes a task successfully."""
+        new_messages: list[Message] = []
+
+        result = await PollingHandler.execute(
+            client=a2a_client,
+            message=test_message,
+            new_messages=new_messages,
+            agent_card=agent_card,
+            polling_interval=0.5,
+            polling_timeout=30.0,
+        )
+
+        assert isinstance(result, dict)
+        assert result["status"] == TaskState.completed
+        assert result.get("result") is not None
+        assert "4" in result["result"]
+
+
+class TestA2AStreamingIntegration:
+    """Integration tests for A2A streaming handler."""
+
+    @pytest.mark.vcr()
+    @pytest.mark.asyncio
+    async def test_streaming_completes_task(
+        self,
+        a2a_client,
+        test_message: Message,
+        agent_card: AgentCard,
+    ) -> None:
+        """Test that streaming handler completes a task successfully."""
+        new_messages: list[Message] = []
+
+        result = await StreamingHandler.execute(
+            client=a2a_client,
+            message=test_message,
+            new_messages=new_messages,
+            agent_card=agent_card,
+        )
+
+        assert isinstance(result, dict)
+        assert result["status"] == TaskState.completed
+        assert result.get("result") is not None
+
+
+class TestA2ATaskOperations:
+    """Integration tests for task operations."""
+
+    @pytest.mark.vcr()
+    @pytest.mark.asyncio
+    async def test_send_message_and_get_response(
+        self,
+        a2a_client,
+        test_message: Message,
+    ) -> None:
+        """Test sending a message and getting a response."""
+        from a2a.types import Task
+
+        final_task: Task | None = None
+        async for event in a2a_client.send_message(test_message):
+            if isinstance(event, tuple) and len(event) >= 1:
+                task, _ = event
+                if isinstance(task, Task):
+                    final_task = task
+
+        assert final_task is not None
+        assert final_task.id is not None
+        assert final_task.status is not None
+        assert final_task.status.state == TaskState.completed
+
+
+class TestA2APushNotificationHandler:
+    """Tests for push notification handler.
+
+    These tests use mocks for the result store since webhook callbacks
+    are incoming requests that can't be recorded with VCR.
+    """
+
+    @pytest.fixture
+    def mock_agent_card(self) -> AgentCard:
+        """Create a minimal valid agent card for testing."""
+        from a2a.types import AgentCapabilities
+
+        return AgentCard(
+            name="Test Agent",
+            description="Test agent for push notification tests",
+            url="http://localhost:9999",
+            version="1.0.0",
+            capabilities=AgentCapabilities(streaming=True, push_notifications=True),
+            default_input_modes=["text"],
+            default_output_modes=["text"],
+            skills=[],
+        )
+
+    @pytest.fixture
+    def mock_task(self) -> "Task":
+        """Create a minimal valid task for testing."""
+        from a2a.types import Task, TaskStatus
+
+        return Task(
+            id="task-123",
+            context_id="ctx-123",
+            status=TaskStatus(state=TaskState.working),
+        )
+
+    @pytest.mark.asyncio
+    async def test_push_handler_waits_for_result(
+        self,
+        mock_agent_card: AgentCard,
+        mock_task,
+    ) -> None:
+        """Test that push handler waits for result from store."""
+        from unittest.mock import AsyncMock, MagicMock
+
+        from a2a.types import Task, TaskStatus
+        from pydantic import AnyHttpUrl
+
+        from crewai.a2a.updates.push_notifications.config import PushNotificationConfig
+        from crewai.a2a.updates.push_notifications.handler import PushNotificationHandler
+
+        completed_task = Task(
+            id="task-123",
+            context_id="ctx-123",
+            status=TaskStatus(state=TaskState.completed),
+            history=[],
+        )
+
+        mock_store = MagicMock()
+        mock_store.wait_for_result = AsyncMock(return_value=completed_task)
+
+        async def mock_send_message(*args, **kwargs):
+            yield (mock_task, None)
+
+        mock_client = MagicMock()
+        mock_client.send_message = mock_send_message
+
+        config = PushNotificationConfig(
+            url=AnyHttpUrl("http://localhost:8080/a2a/callback"),
+            token="secret-token",
+            result_store=mock_store,
+        )
+
+        test_msg = Message(
+            role=Role.user,
+            parts=[Part(root=TextPart(text="What is 2+2?"))],
+            message_id="msg-001",
+        )
+
+        new_messages: list[Message] = []
+
+        result = await PushNotificationHandler.execute(
+            client=mock_client,
+            message=test_msg,
+            new_messages=new_messages,
+            agent_card=mock_agent_card,
+            config=config,
+            result_store=mock_store,
+            polling_timeout=30.0,
+            polling_interval=1.0,
+        )
+
+        mock_store.wait_for_result.assert_called_once_with(
+            task_id="task-123",
+            timeout=30.0,
+            poll_interval=1.0,
+        )
+
+        assert result["status"] == TaskState.completed
+
+    @pytest.mark.asyncio
+    async def test_push_handler_returns_failure_on_timeout(
+        self,
+        mock_agent_card: AgentCard,
+    ) -> None:
+        """Test that push handler returns failure when result store times out."""
+        from unittest.mock import AsyncMock, MagicMock
+
+        from a2a.types import Task, TaskStatus
+        from pydantic import AnyHttpUrl
+
+        from crewai.a2a.updates.push_notifications.config import PushNotificationConfig
+        from crewai.a2a.updates.push_notifications.handler import PushNotificationHandler
+
+        mock_store = MagicMock()
+        mock_store.wait_for_result = AsyncMock(return_value=None)
+
+        working_task = Task(
+            id="task-456",
+            context_id="ctx-456",
+            status=TaskStatus(state=TaskState.working),
+        )
+
+        async def mock_send_message(*args, **kwargs):
+            yield (working_task, None)
+
+        mock_client = MagicMock()
+        mock_client.send_message = mock_send_message
+
+        config = PushNotificationConfig(
+            url=AnyHttpUrl("http://localhost:8080/a2a/callback"),
+            token="token",
+            result_store=mock_store,
+        )
+
+        test_msg = Message(
+            role=Role.user,
+            parts=[Part(root=TextPart(text="test"))],
+            message_id="msg-002",
+        )
+
+        new_messages: list[Message] = []
+
+        result = await PushNotificationHandler.execute(
+            client=mock_client,
+            message=test_msg,
+            new_messages=new_messages,
+            agent_card=mock_agent_card,
+            config=config,
+            result_store=mock_store,
+            polling_timeout=5.0,
+            polling_interval=0.5,
+        )
+
+        assert result["status"] == TaskState.failed
+        assert "timeout" in result.get("error", "").lower()
+
+    @pytest.mark.asyncio
+    async def test_push_handler_requires_config(
+        self,
+        mock_agent_card: AgentCard,
+    ) -> None:
+        """Test that push handler fails gracefully without config."""
+        from unittest.mock import MagicMock
+
+        from crewai.a2a.updates.push_notifications.handler import PushNotificationHandler
+
+        mock_client = MagicMock()
+
+        test_msg = Message(
+            role=Role.user,
+            parts=[Part(root=TextPart(text="test"))],
+            message_id="msg-003",
+        )
+
+        new_messages: list[Message] = []
+
+        result = await PushNotificationHandler.execute(
+            client=mock_client,
+            message=test_msg,
+            new_messages=new_messages,
+            agent_card=mock_agent_card,
+        )
+
+        assert result["status"] == TaskState.failed
+        assert "config" in result.get("error", "").lower()
diff --git a/lib/crewai/tests/cassettes/a2a/TestA2AAgentCardFetching.test_fetch_agent_card.yaml b/lib/crewai/tests/cassettes/a2a/TestA2AAgentCardFetching.test_fetch_agent_card.yaml
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/cassettes/a2a/TestA2AAgentCardFetching.test_fetch_agent_card.yaml
@@ -0,0 +1,44 @@
+interactions:
+- request:
+    body: ''
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      connection:
+      - keep-alive
+      host:
+      - localhost:9999
+    method: GET
+    uri: http://localhost:9999/.well-known/agent-card.json
+  response:
+    body:
+      string: '{"capabilities":{"streaming":true},"defaultInputModes":["text"],"defaultOutputModes":["text"],"description":"An
+        AI assistant powered by OpenAI GPT with calculator and time tools. Ask questions,
+        perform calculations, or get the current time in any timezone.","name":"GPT
+        Assistant","preferredTransport":"JSONRPC","protocolVersion":"0.3.0","skills":[{"description":"Have
+        a general conversation with the AI assistant. Ask questions, get explanations,
+        or just chat.","examples":["Hello, how are you?","Explain quantum computing
+        in simple terms","What can you help me with?"],"id":"conversation","name":"General
+        Conversation","tags":["chat","conversation","general"]},{"description":"Perform
+        mathematical calculations including arithmetic, exponents, and more.","examples":["What
+        is 25 * 17?","Calculate 2^10","What''s (100 + 50) / 3?"],"id":"calculator","name":"Calculator","tags":["math","calculator","arithmetic"]},{"description":"Get
+        the current date and time in any timezone.","examples":["What time is it?","What''s
+        the current time in Tokyo?","What''s today''s date in New York?"],"id":"time","name":"Current
+        Time","tags":["time","date","timezone"]}],"url":"http://localhost:9999/","version":"1.0.0"}'
+    headers:
+      content-length:
+      - '1198'
+      content-type:
+      - application/json
+      date:
+      - Tue, 06 Jan 2026 14:17:00 GMT
+      server:
+      - uvicorn
+    status:
+      code: 200
+      message: OK
+version: 1
diff --git a/lib/crewai/tests/cassettes/a2a/TestA2APollingIntegration.test_polling_completes_task.yaml b/lib/crewai/tests/cassettes/a2a/TestA2APollingIntegration.test_polling_completes_task.yaml
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/cassettes/a2a/TestA2APollingIntegration.test_polling_completes_task.yaml
@@ -0,0 +1,126 @@
+interactions:
+- request:
+    body: ''
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      connection:
+      - keep-alive
+      host:
+      - localhost:9999
+    method: GET
+    uri: http://localhost:9999/.well-known/agent-card.json
+  response:
+    body:
+      string: '{"capabilities":{"streaming":true},"defaultInputModes":["text"],"defaultOutputModes":["text"],"description":"An
+        AI assistant powered by OpenAI GPT with calculator and time tools. Ask questions,
+        perform calculations, or get the current time in any timezone.","name":"GPT
+        Assistant","preferredTransport":"JSONRPC","protocolVersion":"0.3.0","skills":[{"description":"Have
+        a general conversation with the AI assistant. Ask questions, get explanations,
+        or just chat.","examples":["Hello, how are you?","Explain quantum computing
+        in simple terms","What can you help me with?"],"id":"conversation","name":"General
+        Conversation","tags":["chat","conversation","general"]},{"description":"Perform
+        mathematical calculations including arithmetic, exponents, and more.","examples":["What
+        is 25 * 17?","Calculate 2^10","What''s (100 + 50) / 3?"],"id":"calculator","name":"Calculator","tags":["math","calculator","arithmetic"]},{"description":"Get
+        the current date and time in any timezone.","examples":["What time is it?","What''s
+        the current time in Tokyo?","What''s today''s date in New York?"],"id":"time","name":"Current
+        Time","tags":["time","date","timezone"]}],"url":"http://localhost:9999/","version":"1.0.0"}'
+    headers:
+      content-length:
+      - '1198'
+      content-type:
+      - application/json
+      date:
+      - Tue, 06 Jan 2026 14:16:58 GMT
+      server:
+      - uvicorn
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"id":"e5ac2160-ae9b-4bf9-aad7-14bf0d53d6d9","jsonrpc":"2.0","method":"message/stream","params":{"configuration":{"acceptedOutputModes":[],"blocking":true},"message":{"kind":"message","messageId":"e1e63c75-3ea0-49fb-b512-5128a2476416","parts":[{"kind":"text","text":"What
+      is 2 + 2?"}],"role":"user"}}}'
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*, text/event-stream'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      cache-control:
+      - no-store
+      connection:
+      - keep-alive
+      content-length:
+      - '301'
+      content-type:
+      - application/json
+      host:
+      - localhost:9999
+    method: POST
+    uri: http://localhost:9999/
+  response:
+    body:
+      string: "data: {\"id\":\"e5ac2160-ae9b-4bf9-aad7-14bf0d53d6d9\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"b9e14c1b-734d-4d1e-864a-e6dda5231d71\",\"final\":false,\"kind\":\"status-update\",\"status\":{\"state\":\"submitted\"},\"taskId\":\"0dd4d3af-f35d-409d-9462-01218e5641f9\"}}\r\n\r\ndata:
+        {\"id\":\"e5ac2160-ae9b-4bf9-aad7-14bf0d53d6d9\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"b9e14c1b-734d-4d1e-864a-e6dda5231d71\",\"final\":false,\"kind\":\"status-update\",\"status\":{\"state\":\"working\"},\"taskId\":\"0dd4d3af-f35d-409d-9462-01218e5641f9\"}}\r\n\r\ndata:
+        {\"id\":\"e5ac2160-ae9b-4bf9-aad7-14bf0d53d6d9\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"b9e14c1b-734d-4d1e-864a-e6dda5231d71\",\"final\":true,\"kind\":\"status-update\",\"status\":{\"message\":{\"kind\":\"message\",\"messageId\":\"54bb7ff3-f2c0-4eb3-b427-bf1c8cf90832\",\"parts\":[{\"kind\":\"text\",\"text\":\"\\n[Tool:
+        calculator] 2 + 2 = 4\\n2 + 2 equals 4.\"}],\"role\":\"agent\"},\"state\":\"completed\"},\"taskId\":\"0dd4d3af-f35d-409d-9462-01218e5641f9\"}}\r\n\r\n"
+    headers:
+      Transfer-Encoding:
+      - chunked
+      cache-control:
+      - no-store
+      connection:
+      - keep-alive
+      content-type:
+      - text/event-stream; charset=utf-8
+      date:
+      - Tue, 06 Jan 2026 14:16:58 GMT
+      server:
+      - uvicorn
+      x-accel-buffering:
+      - 'no'
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"id":"cb1e4af3-d2d0-4848-96b8-7082ee6171d1","jsonrpc":"2.0","method":"tasks/get","params":{"historyLength":100,"id":"0dd4d3af-f35d-409d-9462-01218e5641f9"}}'
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      connection:
+      - keep-alive
+      content-length:
+      - '157'
+      content-type:
+      - application/json
+      host:
+      - localhost:9999
+    method: POST
+    uri: http://localhost:9999/
+  response:
+    body:
+      string: '{"id":"cb1e4af3-d2d0-4848-96b8-7082ee6171d1","jsonrpc":"2.0","result":{"contextId":"b9e14c1b-734d-4d1e-864a-e6dda5231d71","history":[{"contextId":"b9e14c1b-734d-4d1e-864a-e6dda5231d71","kind":"message","messageId":"e1e63c75-3ea0-49fb-b512-5128a2476416","parts":[{"kind":"text","text":"What
+        is 2 + 2?"}],"role":"user","taskId":"0dd4d3af-f35d-409d-9462-01218e5641f9"}],"id":"0dd4d3af-f35d-409d-9462-01218e5641f9","kind":"task","status":{"message":{"kind":"message","messageId":"54bb7ff3-f2c0-4eb3-b427-bf1c8cf90832","parts":[{"kind":"text","text":"\n[Tool:
+        calculator] 2 + 2 = 4\n2 + 2 equals 4."}],"role":"agent"},"state":"completed"}}}'
+    headers:
+      content-length:
+      - '635'
+      content-type:
+      - application/json
+      date:
+      - Tue, 06 Jan 2026 14:17:00 GMT
+      server:
+      - uvicorn
+    status:
+      code: 200
+      message: OK
+version: 1
diff --git a/lib/crewai/tests/cassettes/a2a/TestA2AStreamingIntegration.test_streaming_completes_task.yaml b/lib/crewai/tests/cassettes/a2a/TestA2AStreamingIntegration.test_streaming_completes_task.yaml
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/cassettes/a2a/TestA2AStreamingIntegration.test_streaming_completes_task.yaml
@@ -0,0 +1,90 @@
+interactions:
+- request:
+    body: ''
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      connection:
+      - keep-alive
+      host:
+      - localhost:9999
+    method: GET
+    uri: http://localhost:9999/.well-known/agent-card.json
+  response:
+    body:
+      string: '{"capabilities":{"streaming":true},"defaultInputModes":["text"],"defaultOutputModes":["text"],"description":"An
+        AI assistant powered by OpenAI GPT with calculator and time tools. Ask questions,
+        perform calculations, or get the current time in any timezone.","name":"GPT
+        Assistant","preferredTransport":"JSONRPC","protocolVersion":"0.3.0","skills":[{"description":"Have
+        a general conversation with the AI assistant. Ask questions, get explanations,
+        or just chat.","examples":["Hello, how are you?","Explain quantum computing
+        in simple terms","What can you help me with?"],"id":"conversation","name":"General
+        Conversation","tags":["chat","conversation","general"]},{"description":"Perform
+        mathematical calculations including arithmetic, exponents, and more.","examples":["What
+        is 25 * 17?","Calculate 2^10","What''s (100 + 50) / 3?"],"id":"calculator","name":"Calculator","tags":["math","calculator","arithmetic"]},{"description":"Get
+        the current date and time in any timezone.","examples":["What time is it?","What''s
+        the current time in Tokyo?","What''s today''s date in New York?"],"id":"time","name":"Current
+        Time","tags":["time","date","timezone"]}],"url":"http://localhost:9999/","version":"1.0.0"}'
+    headers:
+      content-length:
+      - '1198'
+      content-type:
+      - application/json
+      date:
+      - Tue, 06 Jan 2026 14:17:02 GMT
+      server:
+      - uvicorn
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"id":"8cf25b61-8884-4246-adce-fccb32e176ab","jsonrpc":"2.0","method":"message/stream","params":{"configuration":{"acceptedOutputModes":[],"blocking":true},"message":{"kind":"message","messageId":"c145297f-7331-4835-adcc-66b51de92a2b","parts":[{"kind":"text","text":"What
+      is 2 + 2?"}],"role":"user"}}}'
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*, text/event-stream'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      cache-control:
+      - no-store
+      connection:
+      - keep-alive
+      content-length:
+      - '301'
+      content-type:
+      - application/json
+      host:
+      - localhost:9999
+    method: POST
+    uri: http://localhost:9999/
+  response:
+    body:
+      string: "data: {\"id\":\"8cf25b61-8884-4246-adce-fccb32e176ab\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"30601267-ab3b-48ef-afc8-916c37a18651\",\"final\":false,\"kind\":\"status-update\",\"status\":{\"state\":\"submitted\"},\"taskId\":\"3083d3da-4739-4f4f-a4e8-7c048ea819c1\"}}\r\n\r\ndata:
+        {\"id\":\"8cf25b61-8884-4246-adce-fccb32e176ab\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"30601267-ab3b-48ef-afc8-916c37a18651\",\"final\":false,\"kind\":\"status-update\",\"status\":{\"state\":\"working\"},\"taskId\":\"3083d3da-4739-4f4f-a4e8-7c048ea819c1\"}}\r\n\r\ndata:
+        {\"id\":\"8cf25b61-8884-4246-adce-fccb32e176ab\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"30601267-ab3b-48ef-afc8-916c37a18651\",\"final\":true,\"kind\":\"status-update\",\"status\":{\"message\":{\"kind\":\"message\",\"messageId\":\"25f81e3c-b7e8-48b5-a98a-4066f3637a13\",\"parts\":[{\"kind\":\"text\",\"text\":\"\\n[Tool:
+        calculator] 2 + 2 = 4\\n2 + 2 equals 4.\"}],\"role\":\"agent\"},\"state\":\"completed\"},\"taskId\":\"3083d3da-4739-4f4f-a4e8-7c048ea819c1\"}}\r\n\r\n"
+    headers:
+      Transfer-Encoding:
+      - chunked
+      cache-control:
+      - no-store
+      connection:
+      - keep-alive
+      content-type:
+      - text/event-stream; charset=utf-8
+      date:
+      - Tue, 06 Jan 2026 14:17:02 GMT
+      server:
+      - uvicorn
+      x-accel-buffering:
+      - 'no'
+    status:
+      code: 200
+      message: OK
+version: 1
diff --git a/lib/crewai/tests/cassettes/a2a/TestA2ATaskOperations.test_send_message_and_get_response.yaml b/lib/crewai/tests/cassettes/a2a/TestA2ATaskOperations.test_send_message_and_get_response.yaml
new file mode 100644
--- /dev/null
+++ b/lib/crewai/tests/cassettes/a2a/TestA2ATaskOperations.test_send_message_and_get_response.yaml
@@ -0,0 +1,90 @@
+interactions:
+- request:
+    body: ''
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      connection:
+      - keep-alive
+      host:
+      - localhost:9999
+    method: GET
+    uri: http://localhost:9999/.well-known/agent-card.json
+  response:
+    body:
+      string: '{"capabilities":{"streaming":true},"defaultInputModes":["text"],"defaultOutputModes":["text"],"description":"An
+        AI assistant powered by OpenAI GPT with calculator and time tools. Ask questions,
+        perform calculations, or get the current time in any timezone.","name":"GPT
+        Assistant","preferredTransport":"JSONRPC","protocolVersion":"0.3.0","skills":[{"description":"Have
+        a general conversation with the AI assistant. Ask questions, get explanations,
+        or just chat.","examples":["Hello, how are you?","Explain quantum computing
+        in simple terms","What can you help me with?"],"id":"conversation","name":"General
+        Conversation","tags":["chat","conversation","general"]},{"description":"Perform
+        mathematical calculations including arithmetic, exponents, and more.","examples":["What
+        is 25 * 17?","Calculate 2^10","What''s (100 + 50) / 3?"],"id":"calculator","name":"Calculator","tags":["math","calculator","arithmetic"]},{"description":"Get
+        the current date and time in any timezone.","examples":["What time is it?","What''s
+        the current time in Tokyo?","What''s today''s date in New York?"],"id":"time","name":"Current
+        Time","tags":["time","date","timezone"]}],"url":"http://localhost:9999/","version":"1.0.0"}'
+    headers:
+      content-length:
+      - '1198'
+      content-type:
+      - application/json
+      date:
+      - Tue, 06 Jan 2026 14:17:00 GMT
+      server:
+      - uvicorn
+    status:
+      code: 200
+      message: OK
+- request:
+    body: '{"id":"3a17c6bf-8db6-45a6-8535-34c45c0c4936","jsonrpc":"2.0","method":"message/stream","params":{"configuration":{"acceptedOutputModes":[],"blocking":true},"message":{"kind":"message","messageId":"712558a3-6d92-4591-be8a-9dd8566dde82","parts":[{"kind":"text","text":"What
+      is 2 + 2?"}],"role":"user"}}}'
+    headers:
+      User-Agent:
+      - X-USER-AGENT-XXX
+      accept:
+      - '*/*, text/event-stream'
+      accept-encoding:
+      - ACCEPT-ENCODING-XXX
+      cache-control:
+      - no-store
+      connection:
+      - keep-alive
+      content-length:
+      - '301'
+      content-type:
+      - application/json
+      host:
+      - localhost:9999
+    method: POST
+    uri: http://localhost:9999/
+  response:
+    body:
+      string: "data: {\"id\":\"3a17c6bf-8db6-45a6-8535-34c45c0c4936\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"ca2fbbc9-761e-45d9-a929-0c68b1f8acbf\",\"final\":false,\"kind\":\"status-update\",\"status\":{\"state\":\"submitted\"},\"taskId\":\"c6e88db0-36e9-4269-8b9a-ecb6dfdcf6a1\"}}\r\n\r\ndata:
+        {\"id\":\"3a17c6bf-8db6-45a6-8535-34c45c0c4936\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"ca2fbbc9-761e-45d9-a929-0c68b1f8acbf\",\"final\":false,\"kind\":\"status-update\",\"status\":{\"state\":\"working\"},\"taskId\":\"c6e88db0-36e9-4269-8b9a-ecb6dfdcf6a1\"}}\r\n\r\ndata:
+        {\"id\":\"3a17c6bf-8db6-45a6-8535-34c45c0c4936\",\"jsonrpc\":\"2.0\",\"result\":{\"contextId\":\"ca2fbbc9-761e-45d9-a929-0c68b1f8acbf\",\"final\":true,\"kind\":\"status-update\",\"status\":{\"message\":{\"kind\":\"message\",\"messageId\":\"916324aa-fd25-4849-bceb-c4644e2fcbb0\",\"parts\":[{\"kind\":\"text\",\"text\":\"\\n[Tool:
+        calculator] 2 + 2 = 4\\n2 + 2 equals 4.\"}],\"role\":\"agent\"},\"state\":\"completed\"},\"taskId\":\"c6e88db0-36e9-4269-8b9a-ecb6dfdcf6a1\"}}\r\n\r\n"
+    headers:
+      Transfer-Encoding:
+      - chunked
+      cache-control:
+      - no-store
+      connection:
+      - keep-alive
+      content-type:
+      - text/event-stream; charset=utf-8
+      date:
+      - Tue, 06 Jan 2026 14:17:00 GMT
+      server:
+      - uvicorn
+      x-accel-buffering:
+      - 'no'
+    status:
+      code: 200
+      message: OK
+version: 1
EOF_114329324912

# Since conftest.py is at the root level, we need to determine which tests depend on it
# conftest.py is a pytest configuration file that affects all tests in the project
# We'll run a minimal test to verify the conftest.py changes work correctly

# The conftest.py file typically contains fixtures and configuration for pytest
# We should run tests that would utilize these fixtures to validate the changes

# Based on the monorepo structure, run tests from the main crewai package
# which would use the root conftest.py
cd /testbed

# Run a basic test discovery to ensure conftest.py is valid
# Using --collect-only to verify the configuration loads correctly
uv run pytest --collect-only --maxfail=1 -q 2>&1 | head -20

# Now run actual tests from lib/crewai/tests to verify conftest.py works
# Using single process mode for stability, with network blocking and timeout
cd /testbed/lib/crewai
uv run pytest tests/ --block-network --timeout=60 -vv --maxfail=3 -x
rc=$?

# Required: echo test status for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: reset any changes
cd /testbed
git checkout 0ccc155457500278e5287dbdd7ba5ae80bbe08f4 "conftest.py"