#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test files to ensure clean state
git checkout b9dd166a6b1697e7bb61bf181d6812693ddbc19f \
    "lib/crewai/tests/test_flow_human_input_integration.py" \
    "lib/crewai/tests/utilities/test_console_formatter_pause_resume.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/lib/crewai/tests/test_flow_human_input_integration.py b/lib/crewai/tests/test_flow_human_input_integration.py
--- a/lib/crewai/tests/test_flow_human_input_integration.py
+++ b/lib/crewai/tests/test_flow_human_input_integration.py
@@ -7,22 +7,19 @@
 class TestFlowHumanInputIntegration:
     """Test integration between Flow execution and human input functionality."""
 
-    def test_console_formatter_pause_resume_methods(self):
-        """Test that ConsoleFormatter pause/resume methods work correctly."""
+    def test_console_formatter_pause_resume_methods_exist(self):
+        """Test that ConsoleFormatter pause/resume methods exist and are callable."""
         formatter = event_listener.formatter
 
-        original_paused_state = formatter._live_paused
+        # Methods should exist and be callable
+        assert hasattr(formatter, "pause_live_updates")
+        assert hasattr(formatter, "resume_live_updates")
+        assert callable(formatter.pause_live_updates)
+        assert callable(formatter.resume_live_updates)
 
-        try:
-            formatter._live_paused = False
-
-            formatter.pause_live_updates()
-            assert formatter._live_paused
-
-            formatter.resume_live_updates()
-            assert not formatter._live_paused
-        finally:
-            formatter._live_paused = original_paused_state
+        # Should not raise
+        formatter.pause_live_updates()
+        formatter.resume_live_updates()
 
     @patch("builtins.input", return_value="")
     def test_human_input_pauses_flow_updates(self, mock_input):
@@ -38,23 +35,16 @@ def test_human_input_pauses_flow_updates(self, mock_input):
 
         formatter = event_listener.formatter
 
-        original_paused_state = formatter._live_paused
+        with (
+            patch.object(formatter, "pause_live_updates") as mock_pause,
+            patch.object(formatter, "resume_live_updates") as mock_resume,
+        ):
+            result = executor._ask_human_input("Test result")
 
-        try:
-            formatter._live_paused = False
-
-            with (
-                patch.object(formatter, "pause_live_updates") as mock_pause,
-                patch.object(formatter, "resume_live_updates") as mock_resume,
-            ):
-                result = executor._ask_human_input("Test result")
-
-                mock_pause.assert_called_once()
-                mock_resume.assert_called_once()
-                mock_input.assert_called_once()
-                assert result == ""
-        finally:
-            formatter._live_paused = original_paused_state
+            mock_pause.assert_called_once()
+            mock_resume.assert_called_once()
+            mock_input.assert_called_once()
+            assert result == ""
 
     @patch("builtins.input", side_effect=["feedback", ""])
     def test_multiple_human_input_rounds(self, mock_input):
@@ -70,53 +60,46 @@ def test_multiple_human_input_rounds(self, mock_input):
 
         formatter = event_listener.formatter
 
-        original_paused_state = formatter._live_paused
+        pause_calls = []
+        resume_calls = []
 
-        try:
-            pause_calls = []
-            resume_calls = []
-
-            def track_pause():
-                pause_calls.append(True)
+        def track_pause():
+            pause_calls.append(True)
 
-            def track_resume():
-                resume_calls.append(True)
+        def track_resume():
+            resume_calls.append(True)
 
-            with (
-                patch.object(formatter, "pause_live_updates", side_effect=track_pause),
-                patch.object(
-                    formatter, "resume_live_updates", side_effect=track_resume
-                ),
-            ):
-                result1 = executor._ask_human_input("Test result 1")
-                assert result1 == "feedback"
+        with (
+            patch.object(formatter, "pause_live_updates", side_effect=track_pause),
+            patch.object(
+                formatter, "resume_live_updates", side_effect=track_resume
+            ),
+        ):
+            result1 = executor._ask_human_input("Test result 1")
+            assert result1 == "feedback"
 
-                result2 = executor._ask_human_input("Test result 2")
-                assert result2 == ""
+            result2 = executor._ask_human_input("Test result 2")
+            assert result2 == ""
 
-                assert len(pause_calls) == 2
-                assert len(resume_calls) == 2
-        finally:
-            formatter._live_paused = original_paused_state
+            assert len(pause_calls) == 2
+            assert len(resume_calls) == 2
 
     def test_pause_resume_with_no_live_session(self):
         """Test pause/resume methods handle case when no Live session exists."""
         formatter = event_listener.formatter
 
-        original_live = formatter._live
-        original_paused_state = formatter._live_paused
+        original_streaming_live = formatter._streaming_live
 
         try:
-            formatter._live = None
-            formatter._live_paused = False
+            formatter._streaming_live = None
 
+            # Should not raise when no session exists
             formatter.pause_live_updates()
             formatter.resume_live_updates()
 
-            assert not formatter._live_paused
+            assert formatter._streaming_live is None
         finally:
-            formatter._live = original_live
-            formatter._live_paused = original_paused_state
+            formatter._streaming_live = original_streaming_live
 
     def test_pause_resume_exception_handling(self):
         """Test that resume is called even if exception occurs during human input."""
@@ -131,23 +114,18 @@ def test_pause_resume_exception_handling(self):
 
         formatter = event_listener.formatter
 
-        original_paused_state = formatter._live_paused
+        with (
+            patch.object(formatter, "pause_live_updates") as mock_pause,
+            patch.object(formatter, "resume_live_updates") as mock_resume,
+            patch(
+                "builtins.input", side_effect=KeyboardInterrupt("Test exception")
+            ),
+        ):
+            with pytest.raises(KeyboardInterrupt):
+                executor._ask_human_input("Test result")
 
-        try:
-            with (
-                patch.object(formatter, "pause_live_updates") as mock_pause,
-                patch.object(formatter, "resume_live_updates") as mock_resume,
-                patch(
-                    "builtins.input", side_effect=KeyboardInterrupt("Test exception")
-                ),
-            ):
-                with pytest.raises(KeyboardInterrupt):
-                    executor._ask_human_input("Test result")
-
-                mock_pause.assert_called_once()
-                mock_resume.assert_called_once()
-        finally:
-            formatter._live_paused = original_paused_state
+            mock_pause.assert_called_once()
+            mock_resume.assert_called_once()
 
     def test_training_mode_human_input(self):
         """Test human input in training mode."""
@@ -162,28 +140,25 @@ def test_training_mode_human_input(self):
 
         formatter = event_listener.formatter
 
-        original_paused_state = formatter._live_paused
-
-        try:
-            with (
-                patch.object(formatter, "pause_live_updates") as mock_pause,
-                patch.object(formatter, "resume_live_updates") as mock_resume,
-                patch("builtins.input", return_value="training feedback"),
-            ):
-                result = executor._ask_human_input("Test result")
-
-                mock_pause.assert_called_once()
-                mock_resume.assert_called_once()
-                assert result == "training feedback"
-
-                executor._printer.print.assert_called()
-                call_args = [
-                    call[1]["content"]
-                    for call in executor._printer.print.call_args_list
-                ]
-                training_prompt_found = any(
-                    "TRAINING MODE" in content for content in call_args
-                )
-                assert training_prompt_found
-        finally:
-            formatter._live_paused = original_paused_state
+        with (
+            patch.object(formatter, "pause_live_updates") as mock_pause,
+            patch.object(formatter, "resume_live_updates") as mock_resume,
+            patch.object(formatter.console, "print") as mock_console_print,
+            patch("builtins.input", return_value="training feedback"),
+        ):
+            result = executor._ask_human_input("Test result")
+
+            mock_pause.assert_called_once()
+            mock_resume.assert_called_once()
+            assert result == "training feedback"
+
+            # Verify the training panel was printed via formatter's console
+            mock_console_print.assert_called()
+            # Check that a Panel with training title was printed
+            call_args = mock_console_print.call_args_list
+            training_panel_found = any(
+                hasattr(call[0][0], "title") and "Training" in str(call[0][0].title)
+                for call in call_args
+                if call[0]
+            )
+            assert training_panel_found
diff --git a/lib/crewai/tests/utilities/test_console_formatter_pause_resume.py b/lib/crewai/tests/utilities/test_console_formatter_pause_resume.py
--- a/lib/crewai/tests/utilities/test_console_formatter_pause_resume.py
+++ b/lib/crewai/tests/utilities/test_console_formatter_pause_resume.py
@@ -1,116 +1,107 @@
 from unittest.mock import MagicMock, patch
-from rich.tree import Tree
 from rich.live import Live
 from crewai.events.utils.console_formatter import ConsoleFormatter
 
 
 class TestConsoleFormatterPauseResume:
-    """Test ConsoleFormatter pause/resume functionality."""
+    """Test ConsoleFormatter pause/resume functionality for HITL features."""
 
-    def test_pause_live_updates_with_active_session(self):
-        """Test pausing when Live session is active."""
+    def test_pause_stops_active_streaming_session(self):
+        """Test pausing stops an active streaming Live session."""
         formatter = ConsoleFormatter()
 
         mock_live = MagicMock(spec=Live)
-        formatter._live = mock_live
-        formatter._live_paused = False
+        formatter._streaming_live = mock_live
 
         formatter.pause_live_updates()
 
         mock_live.stop.assert_called_once()
-        assert formatter._live_paused
+        assert formatter._streaming_live is None
 
-    def test_pause_live_updates_when_already_paused(self):
-        """Test pausing when already paused does nothing."""
+    def test_pause_is_safe_when_no_session(self):
+        """Test pausing when no streaming session exists doesn't error."""
         formatter = ConsoleFormatter()
+        formatter._streaming_live = None
 
-        mock_live = MagicMock(spec=Live)
-        formatter._live = mock_live
-        formatter._live_paused = True
-
+        # Should not raise
         formatter.pause_live_updates()
 
-        mock_live.stop.assert_not_called()
-        assert formatter._live_paused
+        assert formatter._streaming_live is None
 
-    def test_pause_live_updates_with_no_session(self):
-        """Test pausing when no Live session exists."""
+    def test_multiple_pauses_are_safe(self):
+        """Test calling pause multiple times is safe."""
         formatter = ConsoleFormatter()
 
-        formatter._live = None
-        formatter._live_paused = False
+        mock_live = MagicMock(spec=Live)
+        formatter._streaming_live = mock_live
 
         formatter.pause_live_updates()
+        mock_live.stop.assert_called_once()
+        assert formatter._streaming_live is None
 
-        assert formatter._live_paused
+        # Second pause should not error (no session to stop)
+        formatter.pause_live_updates()
 
-    def test_resume_live_updates_when_paused(self):
-        """Test resuming when paused."""
+    def test_resume_is_safe(self):
+        """Test resume method exists and doesn't error."""
         formatter = ConsoleFormatter()
 
-        formatter._live_paused = True
-
+        # Should not raise
         formatter.resume_live_updates()
 
-        assert not formatter._live_paused
-
-    def test_resume_live_updates_when_not_paused(self):
-        """Test resuming when not paused does nothing."""
+    def test_streaming_after_pause_resume_creates_new_session(self):
+        """Test that streaming after pause/resume creates new Live session."""
         formatter = ConsoleFormatter()
+        formatter.verbose = True
 
-        formatter._live_paused = False
-
-        formatter.resume_live_updates()
-
-        assert not formatter._live_paused
-
-    def test_print_after_resume_restarts_live_session(self):
-        """Test that printing a Tree after resume creates new Live session."""
-        formatter = ConsoleFormatter()
+        # Simulate having an active session
+        mock_live = MagicMock(spec=Live)
+        formatter._streaming_live = mock_live
 
-        formatter._live_paused = True
-        formatter._live = None
+        # Pause stops the session
+        formatter.pause_live_updates()
+        assert formatter._streaming_live is None
 
+        # Resume (no-op, sessions created on demand)
         formatter.resume_live_updates()
-        assert not formatter._live_paused
-
-        tree = Tree("Test")
 
+        # After resume, streaming should be able to start a new session
         with patch("crewai.events.utils.console_formatter.Live") as mock_live_class:
             mock_live_instance = MagicMock()
             mock_live_class.return_value = mock_live_instance
 
-            formatter.print(tree)
+            # Simulate streaming chunk (this creates a new Live session)
+            formatter.handle_llm_stream_chunk("test chunk", call_type=None)
 
             mock_live_class.assert_called_once()
             mock_live_instance.start.assert_called_once()
-            assert formatter._live == mock_live_instance
+            assert formatter._streaming_live == mock_live_instance
 
-    def test_multiple_pause_resume_cycles(self):
-        """Test multiple pause/resume cycles work correctly."""
+    def test_pause_resume_cycle_with_streaming(self):
+        """Test full pause/resume cycle during streaming."""
         formatter = ConsoleFormatter()
+        formatter.verbose = True
 
-        mock_live = MagicMock(spec=Live)
-        formatter._live = mock_live
-        formatter._live_paused = False
-
-        formatter.pause_live_updates()
-        assert formatter._live_paused
-        mock_live.stop.assert_called_once()
-        assert formatter._live is None  # Live session should be cleared
+        with patch("crewai.events.utils.console_formatter.Live") as mock_live_class:
+            mock_live_instance = MagicMock()
+            mock_live_class.return_value = mock_live_instance
 
-        formatter.resume_live_updates()
-        assert not formatter._live_paused
+            # Start streaming
+            formatter.handle_llm_stream_chunk("chunk 1", call_type=None)
+            assert formatter._streaming_live == mock_live_instance
 
-        formatter.pause_live_updates()
-        assert formatter._live_paused
+            # Pause should stop the session
+            formatter.pause_live_updates()
+            mock_live_instance.stop.assert_called_once()
+            assert formatter._streaming_live is None
 
-        formatter.resume_live_updates()
-        assert not formatter._live_paused
+            # Resume (no-op)
+            formatter.resume_live_updates()
 
-    def test_pause_resume_state_initialization(self):
-        """Test that _live_paused is properly initialized."""
-        formatter = ConsoleFormatter()
+            # Create a new mock for the next session
+            mock_live_instance_2 = MagicMock()
+            mock_live_class.return_value = mock_live_instance_2
 
-        assert hasattr(formatter, "_live_paused")
-        assert not formatter._live_paused
+            # Streaming again creates new session
+            formatter.handle_llm_stream_chunk("chunk 2", call_type=None)
+            assert formatter._streaming_live == mock_live_instance_2
EOF_114329324912

# Set environment variables to ensure proper test execution
export OTEL_SDK_DISABLED=true
export PYTHONUNBUFFERED=1
export CREWAI_DISABLE_TELEMETRY=true
export CREWAI_TESTING=true
export PYTEST_VCR_RECORD_MODE=none
export OPENAI_API_KEY=fake-openai-key
export ANTHROPIC_API_KEY=fake-anthropic-key
export GEMINI_API_KEY=fake-gemini-key
export AZURE_OPENAI_API_KEY=fake-azure-key
export AZURE_OPENAI_ENDPOINT=fake-azure-endpoint
export GROQ_API_KEY=fake-groq-key
export COHERE_API_KEY=fake-cohere-key
export MISTRAL_API_KEY=fake-mistral-key
export BRAVE_API_KEY=fake-brave-key
export SNOWFLAKE_USER=fake-snowflake-user
export SNOWFLAKE_PASSWORD=fake-snowflake-password
export SNOWFLAKE_ACCOUNT=fake-snowflake-account
export SNOWFLAKE_WAREHOUSE=fake-snowflake-warehouse
export SNOWFLAKE_DATABASE=fake-snowflake-database
export SNOWFLAKE_SCHEMA=fake-snowflake-schema
export EMBEDCHAIN_DB_URI=sqlite:///test.db

# Change to the crewai package directory
cd /testbed

# Run the target test files using uv
# Using single-process mode for safety in virtualized environment
# --block-network ensures no external network calls (as per pytest config)
# --timeout=60 sets 60 second timeout per test (as per pytest config)
# -v for verbose output
# --tb=short for shorter traceback format
# -p no:cacheprovider to disable cache
uv run pytest --no-header -rA --tb=short -p no:cacheprovider \
    --block-network --timeout=60 -v \
    lib/crewai/tests/test_flow_human_input_integration.py \
    lib/crewai/tests/utilities/test_console_formatter_pause_resume.py

# Capture exit code
rc=$?

# Echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test files
cd /testbed
git checkout b9dd166a6b1697e7bb61bf181d6812693ddbc19f \
    "lib/crewai/tests/test_flow_human_input_integration.py" \
    "lib/crewai/tests/utilities/test_console_formatter_pause_resume.py"