#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Ensure PYTHONPATH is set
export PYTHONPATH=/testbed

# Checkout the original test file to ensure clean state
git checkout 52d784b76383d1802e33354049308237c5dc885b "tests/proxy_unit_tests/test_response_polling_handler.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/proxy_unit_tests/test_response_polling_handler.py b/tests/proxy_unit_tests/test_response_polling_handler.py
--- a/tests/proxy_unit_tests/test_response_polling_handler.py
+++ b/tests/proxy_unit_tests/test_response_polling_handler.py
@@ -864,98 +864,139 @@ def test_provider_resolution_model_not_in_router(self):
 class TestPollingConditionChecks:
     """
     Test cases for the conditions that determine whether polling should be enabled.
-    Tests the logic in endpoints.py responses_api function.
+    Tests the should_use_polling_for_request function.
     """
 
     def test_polling_enabled_when_all_conditions_met(self):
         """Test polling is enabled when background=true, polling_via_cache="all", and redis is available"""
-        background_mode = True
-        polling_via_cache_enabled = "all"
-        redis_usage_cache = Mock()  # Non-None mock
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
         
-        should_use_polling = False
-        if background_mode and polling_via_cache_enabled and redis_usage_cache:
-            if polling_via_cache_enabled == "all":
-                should_use_polling = True
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled="all",
+            redis_cache=Mock(),
+            model="gpt-4o",
+            llm_router=None,
+        )
         
-        assert should_use_polling is True
+        assert result is True
 
     def test_polling_disabled_when_background_false(self):
         """Test polling is disabled when background=false"""
-        background_mode = False
-        polling_via_cache_enabled = "all"
-        redis_usage_cache = Mock()
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
         
-        should_use_polling = False
-        if background_mode and polling_via_cache_enabled and redis_usage_cache:
-            if polling_via_cache_enabled == "all":
-                should_use_polling = True
+        result = should_use_polling_for_request(
+            background_mode=False,
+            polling_via_cache_enabled="all",
+            redis_cache=Mock(),
+            model="gpt-4o",
+            llm_router=None,
+        )
         
-        assert should_use_polling is False
+        assert result is False
 
     def test_polling_disabled_when_config_false(self):
         """Test polling is disabled when polling_via_cache is False"""
-        background_mode = True
-        polling_via_cache_enabled = False
-        redis_usage_cache = Mock()
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
         
-        should_use_polling = False
-        if background_mode and polling_via_cache_enabled and redis_usage_cache:
-            if polling_via_cache_enabled == "all":
-                should_use_polling = True
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled=False,
+            redis_cache=Mock(),
+            model="gpt-4o",
+            llm_router=None,
+        )
         
-        assert should_use_polling is False
+        assert result is False
 
     def test_polling_disabled_when_redis_not_configured(self):
         """Test polling is disabled when Redis is not configured"""
-        background_mode = True
-        polling_via_cache_enabled = "all"
-        redis_usage_cache = None
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
         
-        should_use_polling = False
-        if background_mode and polling_via_cache_enabled and redis_usage_cache:
-            if polling_via_cache_enabled == "all":
-                should_use_polling = True
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled="all",
+            redis_cache=None,
+            model="gpt-4o",
+            llm_router=None,
+        )
         
-        assert should_use_polling is False
+        assert result is False
 
     def test_polling_enabled_with_provider_list_match(self):
         """Test polling is enabled when provider list matches"""
-        background_mode = True
-        polling_via_cache_enabled = ["openai", "anthropic"]
-        redis_usage_cache = Mock()
-        model = "openai/gpt-4o"
-        
-        should_use_polling = False
-        if background_mode and polling_via_cache_enabled and redis_usage_cache:
-            if polling_via_cache_enabled == "all":
-                should_use_polling = True
-            elif isinstance(polling_via_cache_enabled, list):
-                if "/" in model:
-                    provider = model.split("/")[0]
-                    if provider in polling_via_cache_enabled:
-                        should_use_polling = True
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
+        
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled=["openai", "anthropic"],
+            redis_cache=Mock(),
+            model="openai/gpt-4o",
+            llm_router=None,
+        )
         
-        assert should_use_polling is True
+        assert result is True
 
     def test_polling_disabled_with_provider_list_no_match(self):
         """Test polling is disabled when provider not in list"""
-        background_mode = True
-        polling_via_cache_enabled = ["openai"]
-        redis_usage_cache = Mock()
-        model = "anthropic/claude-3"
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
+        
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled=["openai"],
+            redis_cache=Mock(),
+            model="anthropic/claude-3",
+            llm_router=None,
+        )
         
-        should_use_polling = False
-        if background_mode and polling_via_cache_enabled and redis_usage_cache:
-            if polling_via_cache_enabled == "all":
-                should_use_polling = True
-            elif isinstance(polling_via_cache_enabled, list):
-                if "/" in model:
-                    provider = model.split("/")[0]
-                    if provider in polling_via_cache_enabled:
-                        should_use_polling = True
+        assert result is False
+
+    def test_polling_with_router_lookup(self):
+        """Test polling uses router to resolve model name to provider"""
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
         
-        assert should_use_polling is False
+        # Create mock router
+        mock_router = Mock()
+        mock_router.model_name_to_deployment_indices = {"gpt-5": [0]}
+        mock_router.model_list = [
+            {
+                "model_name": "gpt-5",
+                "litellm_params": {"model": "openai/gpt-5"}
+            }
+        ]
+        
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled=["openai"],
+            redis_cache=Mock(),
+            model="gpt-5",  # No slash, needs router lookup
+            llm_router=mock_router,
+        )
+        
+        assert result is True
+
+    def test_polling_with_router_lookup_no_match(self):
+        """Test polling returns False when router lookup finds non-matching provider"""
+        from litellm.proxy.response_polling.polling_handler import should_use_polling_for_request
+        
+        mock_router = Mock()
+        mock_router.model_name_to_deployment_indices = {"claude-3": [0]}
+        mock_router.model_list = [
+            {
+                "model_name": "claude-3",
+                "litellm_params": {"model": "anthropic/claude-3-sonnet"}
+            }
+        ]
+        
+        result = should_use_polling_for_request(
+            background_mode=True,
+            polling_via_cache_enabled=["openai"],
+            redis_cache=Mock(),
+            model="claude-3",
+            llm_router=mock_router,
+        )
+        
+        assert result is False
 
 
 class TestStreamingEventParsing:
EOF_114329324912

# Run the target test file with pytest
# Using -v for verbose output, --tb=short for concise tracebacks
# Running in single-process mode for stability in virtualized environment
pytest tests/proxy_unit_tests/test_response_polling_handler.py -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore the original test file
git checkout 52d784b76383d1802e33354049308237c5dc885b "tests/proxy_unit_tests/test_response_polling_handler.py"

# Exit with the captured return code
exit $rc