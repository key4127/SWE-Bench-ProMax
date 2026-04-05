#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 3a141e642a292fce73b24e2e58178cc7237afae2 \
    "tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py" \
    "tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py b/tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py
--- a/tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py
+++ b/tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py
@@ -641,70 +641,65 @@ async def test_health_check_server_healthy(self):
         manager = MCPServerManager()
 
         # Mock server
-        server = MagicMock()
-        server.server_id = "test-server"
-        server.name = "test-server"
+        server = MCPServer(
+            server_id="test-server",
+            name="test-server",
+            transport=MCPTransport.http,
+            auth_type=None,
+            authentication_token="test-token",
+            url="http://test-server.com",
+        )
 
         manager.get_mcp_server_by_id = MagicMock(return_value=server)
 
-        # Mock successful _get_tools_from_server
-        async def mock_get_tools_from_server(
-            server,
-            mcp_auth_header=None,
-            raw_headers=None,
-        ):
-            tool1 = MagicMock()
-            tool1.name = "tool1"
-            tool2 = MagicMock()
-            tool2.name = "tool2"
-            return [tool1, tool2]
-
-        manager._get_tools_from_server = mock_get_tools_from_server
+        # Mock successful client.run_with_session
+        mock_client = AsyncMock()
+        mock_client.run_with_session = AsyncMock(return_value="ok")
+        manager._create_mcp_client = MagicMock(return_value=mock_client)
 
         # Perform health check
         result = await manager.health_check_server("test-server")
 
-        # Verify results
-        assert result["server_id"] == "test-server"
-        assert result["status"] == "healthy"
-        assert result["tools_count"] == 2
-        assert result["error"] is None
-        assert "last_health_check" in result
-        assert "response_time_ms" in result
-        assert result["response_time_ms"] >= 0  # Allow 0 for very fast mocks
+        # Verify results - result is now LiteLLM_MCPServerTable
+        assert isinstance(result, LiteLLM_MCPServerTable)
+        assert result.server_id == "test-server"
+        assert result.status == "healthy"
+        assert result.health_check_error is None
+        assert result.last_health_check is not None
 
     @pytest.mark.asyncio
     async def test_health_check_server_unhealthy(self):
         """Test health check for an unhealthy server"""
         manager = MCPServerManager()
 
         # Mock server
-        server = MagicMock()
-        server.server_id = "test-server"
-        server.name = "test-server"
+        server = MCPServer(
+            server_id="test-server",
+            name="test-server",
+            transport=MCPTransport.http,
+            auth_type=None,
+            authentication_token="test-token",
+            url="http://test-server.com",
+        )
 
         manager.get_mcp_server_by_id = MagicMock(return_value=server)
 
-        # Mock failed _get_tools_from_server
-        async def mock_get_tools_from_server(
-            server,
-            mcp_auth_header=None,
-            raw_headers=None,
-        ):
-            raise Exception("Connection timeout")
-
-        manager._get_tools_from_server = mock_get_tools_from_server
+        # Mock failed client.run_with_session
+        mock_client = AsyncMock()
+        mock_client.run_with_session = AsyncMock(
+            side_effect=Exception("Connection timeout")
+        )
+        manager._create_mcp_client = MagicMock(return_value=mock_client)
 
         # Perform health check
         result = await manager.health_check_server("test-server")
 
         # Verify results
-        assert result["server_id"] == "test-server"
-        assert result["status"] == "unhealthy"
-        assert result["error"] == "Connection timeout"
-        assert "last_health_check" in result
-        assert "response_time_ms" in result
-        assert result["response_time_ms"] >= 0  # Allow 0 for very fast mocks
+        assert isinstance(result, LiteLLM_MCPServerTable)
+        assert result.server_id == "test-server"
+        assert result.status == "unhealthy"
+        assert result.health_check_error == "Connection timeout"
+        assert result.last_health_check is not None
 
     @pytest.mark.asyncio
     async def test_health_check_server_not_found(self):
@@ -718,104 +713,121 @@ async def test_health_check_server_not_found(self):
         result = await manager.health_check_server("non-existent-server")
 
         # Verify results
-        assert result["server_id"] == "non-existent-server"
-        assert result["status"] == "unknown"
-        assert result["error"] == "Server not found"
-        assert result["response_time_ms"] is None
-        assert "last_health_check" in result
+        assert isinstance(result, LiteLLM_MCPServerTable)
+        assert result.server_id == "non-existent-server"
+        assert result.server_name is None
+        assert result.status == "unknown"
+        assert result.health_check_error == "Server not found"
+        assert result.last_health_check is not None
 
     @pytest.mark.asyncio
-    async def test_health_check_all_servers(self):
-        """Test health check for all servers"""
+    async def test_health_check_server_oauth2_skips_check(self):
+        """Test that health check is skipped for OAuth2 servers and returns unknown status"""
         manager = MCPServerManager()
 
-        # Mock servers
-        server1 = MagicMock()
-        server1.server_id = "server1"
-        server1.name = "server1"
+        # Mock OAuth2 server
+        server = MCPServer(
+            server_id="oauth2-server",
+            name="oauth2-server",
+            transport=MCPTransport.http,
+            auth_type=MCPAuth.oauth2,
+            url="http://oauth2-server.com",
+        )
 
-        server2 = MagicMock()
-        server2.server_id = "server2"
-        server2.name = "server2"
+        manager.get_mcp_server_by_id = MagicMock(return_value=server)
 
-        # Mock registry
-        manager.registry = {"server1": server1, "server2": server2}
+        # _create_mcp_client should not be called for OAuth2 servers
+        manager._create_mcp_client = MagicMock()
 
-        # Mock get_mcp_server_by_id
-        def mock_get_server_by_id(server_id):
-            if server_id == "server1":
-                return server1
-            elif server_id == "server2":
-                return server2
-            return None
+        # Perform health check
+        result = await manager.health_check_server("oauth2-server")
 
-        manager.get_mcp_server_by_id = mock_get_server_by_id
+        # Verify that client was not created (health check was skipped)
+        manager._create_mcp_client.assert_not_called()
 
-        # Mock _get_tools_from_server with different results
-        async def mock_get_tools_from_server(
-            server,
-            mcp_auth_header=None,
-            raw_headers=None,
-        ):
-            if server.server_id == "server1":
-                tool = MagicMock()
-                tool.name = "tool1"
-                return [tool]
-            elif server.server_id == "server2":
-                raise Exception("Connection failed")
-            return []
+        # Verify results
+        assert isinstance(result, LiteLLM_MCPServerTable)
+        assert result.server_id == "oauth2-server"
+        assert result.status == "unknown"
+        assert result.health_check_error is None
+        assert result.last_health_check is not None
 
-        manager._get_tools_from_server = mock_get_tools_from_server
+    @pytest.mark.asyncio
+    async def test_health_check_server_no_token_skips_check(self):
+        """Test that health check is skipped when auth_type is set but authentication_token is missing"""
+        manager = MCPServerManager()
 
-        # Perform health check for all servers
-        result = await manager.health_check_all_servers()
+        # Mock server with auth_type but no authentication_token
+        server = MCPServer(
+            server_id="no-token-server",
+            name="no-token-server",
+            transport=MCPTransport.http,
+            auth_type=MCPAuth.bearer_token,
+            authentication_token=None,  # No token
+            url="http://no-token-server.com",
+        )
 
-        # Verify results
-        assert len(result) == 2
-        assert "server1" in result
-        assert "server2" in result
+        manager.get_mcp_server_by_id = MagicMock(return_value=server)
+
+        # _create_mcp_client should not be called
+        manager._create_mcp_client = MagicMock()
 
-        # Check server1 (healthy)
-        assert result["server1"]["status"] == "healthy"
-        assert result["server1"]["tools_count"] == 1
-        assert result["server1"]["error"] is None
+        # Perform health check
+        result = await manager.health_check_server("no-token-server")
+
+        # Verify that client was not created (health check was skipped)
+        manager._create_mcp_client.assert_not_called()
 
-        # Check server2 (unhealthy)
-        assert result["server2"]["status"] == "unhealthy"
-        assert result["server2"]["error"] == "Connection failed"
+        # Verify results
+        assert isinstance(result, LiteLLM_MCPServerTable)
+        assert result.server_id == "no-token-server"
+        assert result.status == "unknown"
+        assert result.health_check_error is None
+        assert result.last_health_check is not None
 
     @pytest.mark.asyncio
-    async def test_health_check_server_with_auth_header(self):
-        """Test health check with authentication header"""
+    async def test_health_check_server_with_static_headers(self):
+        """Test health check with static headers configured"""
         manager = MCPServerManager()
 
-        # Mock server
-        server = MagicMock()
-        server.server_id = "test-server"
-        server.name = "test-server"
+        # Mock server with static_headers
+        server = MCPServer(
+            server_id="test-server",
+            name="test-server",
+            transport=MCPTransport.http,
+            auth_type=None,
+            authentication_token="test-token",
+            url="http://test-server.com",
+            static_headers={"X-Custom-Header": "custom-value"},
+        )
 
         manager.get_mcp_server_by_id = MagicMock(return_value=server)
 
-        # Mock _get_tools_from_server to verify auth header is passed
-        async def mock_get_tools_from_server(
-            server,
-            mcp_auth_header=None,
-            raw_headers=None,
-        ):
-            assert mcp_auth_header == "test-token"
-            tool = MagicMock()
-            tool.name = "tool1"
-            return [tool]
+        # Mock successful client
+        mock_client = AsyncMock()
+        mock_client.run_with_session = AsyncMock(return_value="ok")
 
-        manager._get_tools_from_server = mock_get_tools_from_server
+        # Capture the extra_headers passed to _create_mcp_client
+        captured_extra_headers = None
+
+        def capture_create_mcp_client(server, mcp_auth_header, extra_headers, stdio_env):
+            nonlocal captured_extra_headers
+            captured_extra_headers = extra_headers
+            return mock_client
+
+        manager._create_mcp_client = MagicMock(side_effect=capture_create_mcp_client)
+
+        # Perform health check
+        result = await manager.health_check_server("test-server")
 
-        # Perform health check with auth header
-        result = await manager.health_check_server("test-server", "test-token")
+        # Verify static headers were passed
+        assert captured_extra_headers == {"X-Custom-Header": "custom-value"}
 
         # Verify results
-        assert result["server_id"] == "test-server"
-        assert result["status"] == "healthy"
-        assert result["tools_count"] == 1
+        assert isinstance(result, LiteLLM_MCPServerTable)
+        assert result.server_id == "test-server"
+        assert result.status == "healthy"
+        assert result.health_check_error is None
 
     @pytest.mark.asyncio
     async def test_pre_call_tool_check_allowed_tools_list_allows_tool(self):
diff --git a/tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py b/tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py
--- a/tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py
+++ b/tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py
@@ -486,11 +486,14 @@ async def test_fetch_single_mcp_server_redacts_credentials(self):
         mock_server.credentials = {"auth_value": "top-secret"}
 
         mock_prisma_client = MagicMock()
-        mock_health_result = {
-            "status": "healthy",
-            "last_health_check": datetime.now().isoformat(),
-            "error": None,
-        }
+
+        # Mock health check result as LiteLLM_MCPServerTable
+        mock_health_result = generate_mock_mcp_server_db_record(
+            server_id="server-1", alias="Server 1"
+        )
+        mock_health_result.status = "healthy"
+        mock_health_result.last_health_check = datetime.now()
+        mock_health_result.health_check_error = None
 
         mock_user_auth = generate_mock_user_api_key_auth(
             user_role=LitellmUserRoles.PROXY_ADMIN
@@ -531,11 +534,14 @@ async def test_fetch_single_mcp_server_handles_missing_credentials_field(self):
         delattr(mock_server, "credentials")
 
         mock_prisma_client = MagicMock()
-        mock_health_result = {
-            "status": "healthy",
-            "last_health_check": datetime.now().isoformat(),
-            "error": None,
-        }
+
+        # Mock health check result as LiteLLM_MCPServerTable
+        mock_health_result = generate_mock_mcp_server_db_record(
+            server_id="server-2", alias="Server 2"
+        )
+        mock_health_result.status = "healthy"
+        mock_health_result.last_health_check = datetime.now()
+        mock_health_result.health_check_error = None
 
         mock_user_auth = generate_mock_user_api_key_auth(
             user_role=LitellmUserRoles.PROXY_ADMIN
@@ -568,296 +574,6 @@ async def test_fetch_single_mcp_server_handles_missing_credentials_field(self):
             assert result.status == "healthy"
 
 
-class TestMCPHealthCheckEndpoints:
-    """Test MCP health check endpoints"""
-
-    @pytest.mark.asyncio
-    async def test_health_check_mcp_server_success(self):
-        """Test successful health check for a specific MCP server"""
-        # Mock server
-        mock_server = generate_mock_mcp_server_db_record(
-            server_id="test-server", alias="Test Server"
-        )
-
-        # Mock dependencies
-        mock_prisma_client = MagicMock()
-
-        # Mock global MCP server manager
-        mock_manager = MagicMock()
-        mock_manager.health_check_server = AsyncMock(
-            return_value={
-                "server_id": "test-server",
-                "server_name": "Test Server",
-                "status": "healthy",
-                "tools_count": 3,
-                "last_health_check": "2024-01-01T12:00:00",
-                "response_time_ms": 150.5,
-                "error": None,
-            }
-        )
-
-        mock_user_auth = generate_mock_user_api_key_auth(
-            user_role=LitellmUserRoles.PROXY_ADMIN
-        )
-
-        with patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_prisma_client_or_throw",
-            return_value=mock_prisma_client,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints._user_has_admin_view",
-            return_value=True,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.global_mcp_server_manager",
-            mock_manager,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_mcp_server",
-            AsyncMock(return_value=mock_server),
-        ):
-            # Import and call the function
-            from litellm.proxy.management_endpoints.mcp_management_endpoints import (
-                health_check_mcp_server,
-            )
-
-            result = await health_check_mcp_server(
-                server_id="test-server", user_api_key_dict=mock_user_auth
-            )
-
-            # Verify results
-            assert result["server_id"] == "test-server"
-            assert result["server_name"] == "Test Server"
-            assert result["status"] == "healthy"
-            assert result["tools_count"] == 3
-            assert result["response_time_ms"] == 150.5
-            assert result["error"] is None
-
-    @pytest.mark.asyncio
-    async def test_health_check_mcp_server_not_found(self):
-        """Test health check for a server that doesn't exist"""
-        # Mock dependencies
-        mock_prisma_client = MagicMock()
-
-        mock_user_auth = generate_mock_user_api_key_auth(
-            user_role=LitellmUserRoles.PROXY_ADMIN
-        )
-
-        with patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_prisma_client_or_throw",
-            return_value=mock_prisma_client,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_mcp_server",
-            AsyncMock(return_value=None),
-        ):
-            # Import and call the function
-            from litellm.proxy.management_endpoints.mcp_management_endpoints import (
-                health_check_mcp_server,
-            )
-
-            # Should raise HTTPException
-            with pytest.raises(Exception) as exc_info:
-                await health_check_mcp_server(
-                    server_id="non-existent-server", user_api_key_dict=mock_user_auth
-                )
-
-            assert "not found" in str(exc_info.value)
-
-    @pytest.mark.asyncio
-    async def test_health_check_mcp_server_unauthorized(self):
-        """Test health check for a server user doesn't have access to"""
-        # Mock server
-        mock_server = generate_mock_mcp_server_db_record(
-            server_id="test-server", alias="Test Server"
-        )
-
-        # Mock dependencies
-        mock_prisma_client = MagicMock()
-
-        mock_user_auth = generate_mock_user_api_key_auth(
-            user_role=LitellmUserRoles.INTERNAL_USER  # Non-admin user
-        )
-
-        # Mock user doesn't have access to this server
-        mock_user_servers = []
-
-        with patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_prisma_client_or_throw",
-            return_value=mock_prisma_client,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints._user_has_admin_view",
-            return_value=False,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_all_mcp_servers_for_user",
-            return_value=mock_user_servers,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_mcp_server",
-            AsyncMock(return_value=mock_server),
-        ):
-            # Import and call the function
-            from litellm.proxy.management_endpoints.mcp_management_endpoints import (
-                health_check_mcp_server,
-            )
-
-            # Should raise HTTPException
-            with pytest.raises(Exception) as exc_info:
-                await health_check_mcp_server(
-                    server_id="test-server", user_api_key_dict=mock_user_auth
-                )
-
-            assert "permission" in str(exc_info.value)
-
-    @pytest.mark.asyncio
-    async def test_health_check_all_mcp_servers(self):
-        """Test health check for all accessible MCP servers"""
-        # Mock team records
-        team_records = [
-            generate_mock_team_record(
-                team_id="team1",
-                team_alias="Team 1",
-                organization_id="org1",
-                mcp_servers=["server1", "server2"],
-            )
-        ]
-
-        # Mock DB servers
-        db_servers = [
-            generate_mock_mcp_server_db_record(server_id="server1"),
-            generate_mock_mcp_server_db_record(server_id="server2"),
-        ]
-
-        # Mock dependencies
-        mock_prisma_client = MagicMock()
-        mock_prisma_client = setup_mock_prisma_client(
-            mock_prisma_client=mock_prisma_client,
-            team_records=team_records,
-            mcp_servers=db_servers,
-        )
-
-        # Mock global MCP server manager
-        mock_manager = MagicMock()
-        mock_manager.health_check_allowed_servers = AsyncMock(
-            return_value={
-                "server1": {
-                    "server_id": "server1",
-                    "server_name": "Test DB Server",
-                    "status": "healthy",
-                    "tools_count": 2,
-                    "last_health_check": "2024-01-01T12:00:00",
-                    "response_time_ms": 100.0,
-                    "error": None,
-                },
-                "server2": {
-                    "server_id": "server2",
-                    "server_name": "Test DB Server",
-                    "status": "unhealthy",
-                    "last_health_check": "2024-01-01T12:00:00",
-                    "response_time_ms": 5000.0,
-                    "error": "Connection timeout",
-                },
-            }
-        )
-        mock_manager.get_allowed_mcp_servers = AsyncMock(
-            return_value=["server1", "server2"]
-        )
-
-        mock_user_auth = generate_mock_user_api_key_auth(
-            user_role=LitellmUserRoles.INTERNAL_USER
-        )
-
-        with patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_prisma_client_or_throw",
-            return_value=mock_prisma_client,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints._user_has_admin_view",
-            return_value=False,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.global_mcp_server_manager",
-            mock_manager,
-        ):
-            # Import and call the function
-            from litellm.proxy.management_endpoints.mcp_management_endpoints import (
-                health_check_all_mcp_servers,
-            )
-
-            result = await health_check_all_mcp_servers(
-                user_api_key_dict=mock_user_auth
-            )
-
-            # Verify results
-            assert result["total_servers"] == 2
-            assert result["healthy_count"] == 1
-            assert result["unhealthy_count"] == 1
-            assert result["unknown_count"] == 0
-            assert "server1" in result["servers"]
-            assert "server2" in result["servers"]
-
-            # Check individual server results
-            assert result["servers"]["server1"]["status"] == "healthy"
-            assert result["servers"]["server1"]["tools_count"] == 2
-            assert result["servers"]["server1"]["server_name"] == "Test DB Server"
-            assert result["servers"]["server2"]["status"] == "unhealthy"
-            assert result["servers"]["server2"]["error"] == "Connection timeout"
-            assert result["servers"]["server2"]["server_name"] == "Test DB Server"
-
-    @pytest.mark.asyncio
-    async def test_fetch_all_mcp_servers_with_health_status(self):
-        """Test that fetch_all_mcp_servers includes health check status"""
-        # Mock server with health status
-        mock_server = generate_mock_mcp_server_db_record(
-            server_id="test-server", alias="Test Server"
-        )
-        # Add health status to the mock server
-        mock_server.status = "healthy"
-        mock_server.last_health_check = datetime.now()
-        mock_server.health_check_error = None
-
-        # Mock dependencies
-        mock_prisma_client = MagicMock()
-        mock_prisma_client = setup_mock_prisma_client(
-            mock_prisma_client=mock_prisma_client,
-            team_records=[],
-            mcp_servers=[],  # Don't add servers here since we're mocking get_all_mcp_servers
-        )
-
-        # Mock global MCP server manager
-        mock_manager = MagicMock()
-        mock_manager.config_mcp_servers = {}
-        mock_manager.get_allowed_mcp_servers = AsyncMock(return_value=[])
-        mock_manager.get_all_mcp_servers_with_health_and_teams = AsyncMock(
-            return_value=[mock_server]
-        )
-
-        mock_server.credentials = {"auth_value": "secret"}
-
-        mock_user_auth = generate_mock_user_api_key_auth(
-            user_role=LitellmUserRoles.PROXY_ADMIN
-        )
-
-        with patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.get_prisma_client_or_throw",
-            return_value=mock_prisma_client,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints._user_has_admin_view",
-            return_value=True,
-        ), patch(
-            "litellm.proxy.management_endpoints.mcp_management_endpoints.global_mcp_server_manager",
-            mock_manager,
-        ):
-            # Import and call the function
-            from litellm.proxy.management_endpoints.mcp_management_endpoints import (
-                fetch_all_mcp_servers,
-            )
-
-            result = await fetch_all_mcp_servers(user_api_key_dict=mock_user_auth)
-
-            # Verify health check status is included
-            assert len(result) == 1
-            server = result[0]
-            assert server.server_id == "test-server"
-            assert server.status == "healthy"
-            assert server.last_health_check is not None
-            assert server.health_check_error is None
-            assert server.credentials is None
-
-
 class TestTemporaryMCPSessionEndpoints:
     def test_inherit_credentials_from_existing_server(self):
         payload = NewMCPServerRequest(
@@ -1170,7 +886,6 @@ async def test_mcp_register_proxies_request_body(self):
             fallback_client_id="server-1",
         )
 
-
 class TestUpdateMCPServer:
     """Test suite for update MCP server functionality"""
 
EOF_114329324912

# Ensure PYTHONPATH is set correctly
export PYTHONPATH=/testbed:$PYTHONPATH

# Run the target test files with pytest
# Using -v for verbose output and --tb=short for concise tracebacks
# Running both test files in a single command for efficiency
pytest \
    tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py \
    tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py \
    -v --tb=short

# Capture exit code immediately after test execution
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files to clean state
git checkout 3a141e642a292fce73b24e2e58178cc7237afae2 \
    "tests/test_litellm/proxy/_experimental/mcp_server/test_mcp_server_manager.py" \
    "tests/test_litellm/proxy/management_endpoints/test_mcp_management_endpoints.py"

# Exit with the captured return code
exit $rc