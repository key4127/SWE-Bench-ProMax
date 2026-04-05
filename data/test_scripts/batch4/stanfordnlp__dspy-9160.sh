#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout e23f9eaa7f242dca016389bff9a8bb08021b7e98 "tests/clients/test_lm_local.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/clients/test_lm_local.py b/tests/clients/test_lm_local.py
new file mode 100644
--- /dev/null
+++ b/tests/clients/test_lm_local.py
@@ -0,0 +1,97 @@
+from unittest import mock
+from unittest.mock import patch
+
+from dspy.clients.lm_local import LocalProvider
+
+
+@patch("dspy.clients.lm_local.threading.Thread")
+@patch("dspy.clients.lm_local.subprocess.Popen")
+@patch("dspy.clients.lm_local.get_free_port")
+@patch("dspy.clients.lm_local.wait_for_server")
+def test_command_with_spaces_in_path(mock_wait, mock_port, mock_popen, mock_thread):
+    mock_port.return_value = 8000
+    mock_process = mock.Mock()
+    mock_process.pid = 12345
+    mock_process.stdout.readline.return_value = ""
+    mock_process.poll.return_value = 0
+    mock_popen.return_value = mock_process
+
+    lm = mock.Mock(spec=[])
+    lm.model = "/path/to/my models/llama"
+    lm.launch_kwargs = {}
+    lm.kwargs = {}
+
+    with mock.patch.dict("sys.modules", {"sglang": mock.Mock(), "sglang.utils": mock.Mock()}):
+        LocalProvider.launch(lm, launch_kwargs={})
+
+        assert mock_popen.called
+        call_args = mock_popen.call_args
+        command = call_args[0][0]
+
+        assert isinstance(command, list)
+        assert "--model-path" in command
+        model_index = command.index("--model-path")
+        assert command[model_index + 1] == "/path/to/my models/llama"
+
+
+@patch("dspy.clients.lm_local.threading.Thread")
+@patch("dspy.clients.lm_local.subprocess.Popen")
+@patch("dspy.clients.lm_local.get_free_port")
+@patch("dspy.clients.lm_local.wait_for_server")
+def test_command_construction_prevents_injection(mock_wait, mock_port, mock_popen, mock_thread):
+    mock_port.return_value = 8000
+    mock_process = mock.Mock()
+    mock_process.pid = 12345
+    mock_process.stdout.readline.return_value = ""
+    mock_process.poll.return_value = 0
+    mock_popen.return_value = mock_process
+
+    lm = mock.Mock(spec=[])
+    lm.model = "model --trust-remote-code"
+    lm.launch_kwargs = {}
+    lm.kwargs = {}
+
+    with mock.patch.dict("sys.modules", {"sglang": mock.Mock(), "sglang.utils": mock.Mock()}):
+        LocalProvider.launch(lm, launch_kwargs={})
+
+        assert mock_popen.called
+        call_args = mock_popen.call_args
+        command = call_args[0][0]
+
+        assert isinstance(command, list)
+        assert "--model-path" in command
+        model_index = command.index("--model-path")
+        assert command[model_index + 1] == "model --trust-remote-code"
+
+
+@patch("dspy.clients.lm_local.threading.Thread")
+@patch("dspy.clients.lm_local.subprocess.Popen")
+@patch("dspy.clients.lm_local.get_free_port")
+@patch("dspy.clients.lm_local.wait_for_server")
+def test_command_is_list_not_string(mock_wait, mock_port, mock_popen, mock_thread):
+    mock_port.return_value = 8000
+    mock_process = mock.Mock()
+    mock_process.pid = 12345
+    mock_process.stdout.readline.return_value = ""
+    mock_process.poll.return_value = 0
+    mock_popen.return_value = mock_process
+
+    lm = mock.Mock(spec=[])
+    lm.model = "meta-llama/Llama-2-7b"
+    lm.launch_kwargs = {}
+    lm.kwargs = {}
+
+    with mock.patch.dict("sys.modules", {"sglang": mock.Mock(), "sglang.utils": mock.Mock()}):
+        LocalProvider.launch(lm, launch_kwargs={})
+
+        assert mock_popen.called
+        call_args = mock_popen.call_args
+        command = call_args[0][0]
+
+        assert isinstance(command, list)
+        assert command[0] == "python"
+        assert command[1] == "-m"
+        assert command[2] == "sglang.launch_server"
+        assert "--model-path" in command
+        assert "--port" in command
+        assert "--host" in command
EOF_114329324912

# Run the target test file
# Using single-process mode for stability in virtualized environment
# -xvs flags: -x stops at first failure, -v for verbose, -s shows print statements
# --tb=short for concise traceback on failures
pytest tests/clients/test_lm_local.py -xvs --tb=short

# Capture exit code
rc=$?

# Echo exit code for judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original test file
git checkout e23f9eaa7f242dca016389bff9a8bb08021b7e98 "tests/clients/test_lm_local.py"

# Exit with the test result code
exit $rc