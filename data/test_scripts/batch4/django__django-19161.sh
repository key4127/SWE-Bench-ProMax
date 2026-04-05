#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 3839afb63ad5183cdf08e06e3a43a014ca4b7263 tests/shell/tests.py

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/shell/tests.py b/tests/shell/tests.py
--- a/tests/shell/tests.py
+++ b/tests/shell/tests.py
@@ -85,13 +85,14 @@ def test_stdin_read_inline_function_call(self, select):
     def test_ipython(self):
         cmd = shell.Command()
         mock_ipython = mock.Mock(start_ipython=mock.MagicMock())
+        options = {"verbosity": 0, "no_imports": False}
 
         with mock.patch.dict(sys.modules, {"IPython": mock_ipython}):
-            cmd.ipython({"verbosity": 0, "no_imports": False})
+            cmd.ipython(options)
 
         self.assertEqual(
             mock_ipython.start_ipython.mock_calls,
-            [mock.call(argv=[], user_ns=cmd.get_and_report_namespace(0))],
+            [mock.call(argv=[], user_ns=cmd.get_and_report_namespace(**options))],
         )
 
     @mock.patch("django.core.management.commands.shell.select.select")  # [1]
@@ -106,12 +107,14 @@ def test_shell_with_ipython_not_installed(self, select):
     def test_bpython(self):
         cmd = shell.Command()
         mock_bpython = mock.Mock(embed=mock.MagicMock())
+        options = {"verbosity": 0, "no_imports": False}
 
         with mock.patch.dict(sys.modules, {"bpython": mock_bpython}):
-            cmd.bpython({"verbosity": 0, "no_imports": False})
+            cmd.bpython(options)
 
         self.assertEqual(
-            mock_bpython.embed.mock_calls, [mock.call(cmd.get_and_report_namespace(0))]
+            mock_bpython.embed.mock_calls,
+            [mock.call(cmd.get_and_report_namespace(**options))],
         )
 
     @mock.patch("django.core.management.commands.shell.select.select")  # [1]
@@ -126,13 +129,14 @@ def test_shell_with_bpython_not_installed(self, select):
     def test_python(self):
         cmd = shell.Command()
         mock_code = mock.Mock(interact=mock.MagicMock())
+        options = {"verbosity": 0, "no_startup": True, "no_imports": False}
 
         with mock.patch.dict(sys.modules, {"code": mock_code}):
-            cmd.python({"verbosity": 0, "no_startup": True, "no_imports": False})
+            cmd.python(options)
 
         self.assertEqual(
             mock_code.interact.mock_calls,
-            [mock.call(local=cmd.get_and_report_namespace(0))],
+            [mock.call(local=cmd.get_and_report_namespace(**options))],
         )
 
     # [1] Patch select to prevent tests failing when the test suite is run
EOF_114329324912

# Run the target test file using Django's test runner
python tests/runtests.py shell.tests -v2
rc=$?

# Capture and echo the exit code for the judge
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 3839afb63ad5183cdf08e06e3a43a014ca4b7263 tests/shell/tests.py