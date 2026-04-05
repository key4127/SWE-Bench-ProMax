#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 1c0587de89007b2809ae7a0acd60aac5323538a9 "test/toolkits/test_terminal_toolkit.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/test/toolkits/test_terminal_toolkit.py b/test/toolkits/test_terminal_toolkit.py
--- a/test/toolkits/test_terminal_toolkit.py
+++ b/test/toolkits/test_terminal_toolkit.py
@@ -61,28 +61,32 @@ def test_shell_exec(terminal_toolkit, temp_dir):
     )
     assert "not found" in result.lower()
 
-    # Test session persistence
+    # Test session persistence - use non-blocking mode to create sessions
     session_id = "persistent_session"
-    terminal_toolkit.shell_exec(session_id, "echo 'test1'")
+    terminal_toolkit.shell_exec(session_id, "echo 'test1'", block=False)
     assert session_id in terminal_toolkit.shell_sessions
-    assert terminal_toolkit.shell_sessions[session_id]["output"] != ""
+    # For non-blocking mode, check if session was created
+    # (output might be empty initially)
+    assert "output_stream" in terminal_toolkit.shell_sessions[session_id]
 
 
 def test_shell_exec_multiple_sessions(terminal_toolkit, temp_dir):
-    # Test multiple concurrent sessions
+    # Test multiple concurrent sessions - use non-blocking mode
+    # to create sessions
     session1 = "session1"
     session2 = "session2"
 
-    result1 = terminal_toolkit.shell_exec(
+    terminal_toolkit.shell_exec(
         session1,
         "echo 'Session 1'",
+        block=False,
     )
-    result2 = terminal_toolkit.shell_exec(
+    terminal_toolkit.shell_exec(
         session2,
         "echo 'Session 2'",
+        block=False,
     )
 
-    assert "Session 1" in result1
-    assert "Session 2" in result2
+    # For non-blocking mode, sessions should be created immediately
     assert session1 in terminal_toolkit.shell_sessions
     assert session2 in terminal_toolkit.shell_sessions
EOF_114329324912

# Run the target test file with verbose output
pytest test/toolkits/test_terminal_toolkit.py -v --tb=short

# Capture the exit code
rc=$?

# Echo the exit code for the judge to determine test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 1c0587de89007b2809ae7a0acd60aac5323538a9 "test/toolkits/test_terminal_toolkit.py"