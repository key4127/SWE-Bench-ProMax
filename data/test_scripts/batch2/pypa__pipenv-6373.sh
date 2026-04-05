#!/bin/bash
set -uxo pipefail

# Navigate to the testbed directory
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 29b4197693ad6d02bfe6c5b8034189ae345d35de "tests/unit/test_utils.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unit/test_utils.py b/tests/unit/test_utils.py
--- a/tests/unit/test_utils.py
+++ b/tests/unit/test_utils.py
@@ -1,10 +1,11 @@
 import os
+import sys
 from unittest import mock
 
 import pytest
 
 from pipenv.exceptions import PipenvUsageError
-from pipenv.utils import dependencies, indexes, internet, shell, toml
+from pipenv.utils import dependencies, indexes, internet, shell, toml, virtualenv
 
 # Pipfile format <-> requirements.txt format.
 DEP_PIP_PAIRS = [
@@ -547,3 +548,17 @@ def test_is_env_truthy_does_not_exisxt(self, monkeypatch):
         name = "ZZZ"
         monkeypatch.delenv(name, raising=False)
         assert shell.is_env_truthy(name) is False
+
+    @pytest.mark.utils
+    # substring search in version handles special-case of MSYS2 MinGW CPython
+    # https://github.com/msys2/MINGW-packages/blob/master/mingw-w64-python/0017-sysconfig-treat-MINGW-builds-as-POSIX-builds.patch#L24
+    @pytest.mark.skipif(os.name != "nt" or "GCC" in sys.version, reason="Windows test only")
+    def test_virtualenv_scripts_dir_nt(self):
+        """
+        """
+        assert str(virtualenv.virtualenv_scripts_dir('foobar')) == 'foobar\\Scripts'
+
+    @pytest.mark.utils
+    @pytest.mark.skipif(os.name == "nt" and "GCC" not in sys.version, reason="POSIX test only")
+    def test_virtualenv_scripts_dir_posix(self):
+        assert str(virtualenv.virtualenv_scripts_dir('foobar')) == 'foobar/bin'
EOF_114329324912

# Ensure environment variables are set
export PYTHONIOENCODING=utf-8
export LANG=C.UTF-8
export PIPENV_CACHE_DIR=/tmp/pipenv-cache

# Create cache directory if it doesn't exist
mkdir -p /tmp/pipenv-cache

# Run the target test file with pytest
# Using -v for verbose output, -ra for test summary, --tb=short for concise tracebacks
# Not using parallel execution to ensure stability in the virtualized environment
pytest -v -ra --tb=short tests/unit/test_utils.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge to determine test success
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 29b4197693ad6d02bfe6c5b8034189ae345d35de "tests/unit/test_utils.py"