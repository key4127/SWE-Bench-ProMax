#!/bin/bash
set -uxo pipefail

# Activate the virtual environment
source /opt/testbed_env/bin/activate

# Navigate to the testbed directory
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 623957c0a8d9fae308ced3cf99291852cefc32a8 "tests/unittests/cli/utils/test_cli.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/unittests/cli/utils/test_cli.py b/tests/unittests/cli/utils/test_cli.py
--- a/tests/unittests/cli/utils/test_cli.py
+++ b/tests/unittests/cli/utils/test_cli.py
@@ -18,7 +18,7 @@
 
 import json
 from pathlib import Path
-import sys
+from textwrap import dedent
 import types
 from typing import Any
 from typing import Dict
@@ -87,35 +87,24 @@ async def close(self, *a: Any, **k: Any) -> None:
 
 
 @pytest.fixture()
-def fake_agent(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
+def fake_agent(tmp_path: Path):
   """Create a minimal importable agent package and patch importlib."""
 
   parent_dir = tmp_path / "agents"
   parent_dir.mkdir()
   agent_dir = parent_dir / "fake_agent"
   agent_dir.mkdir()
   # __init__.py exposes root_agent with .name
-  (agent_dir / "__init__.py").write_text(
-      "from types import SimpleNamespace\n"
-      "root_agent = SimpleNamespace(name='fake_root')\n"
-  )
-
-  # Ensure importable via sys.path
-  sys.path.insert(0, str(parent_dir))
-
-  import importlib
-
-  module = importlib.import_module("fake_agent")
-  fake_module = types.SimpleNamespace(agent=module)
-
-  monkeypatch.setattr(importlib, "import_module", lambda n: fake_module)
-  monkeypatch.setattr(cli.envs, "load_dotenv_for_agent", lambda *a, **k: None)
+  (agent_dir / "__init__.py").write_text(dedent("""
+    from google.adk.agents.base_agent import BaseAgent
+    class FakeAgent(BaseAgent):
+      def __init__(self, name):
+        super().__init__(name=name)
 
-  yield parent_dir, "fake_agent"
+    root_agent = FakeAgent(name="fake_root")
+    """))
 
-  # Cleanup
-  sys.path.remove(str(parent_dir))
-  del sys.modules["fake_agent"]
+  return parent_dir, "fake_agent"
 
 
 # _run_input_file
EOF_114329324912

# Run the specific test file
# Using pytest with single-process mode for safety in virtualized environment
# --no-header: suppress header information
# -rA: show all test outcomes (passed, failed, skipped, etc.)
# --tb=short: use short traceback format for cleaner output
# -p no:cacheprovider: disable cache for clean test execution
pytest --no-header -rA --tb=short -p no:cacheprovider tests/unittests/cli/utils/test_cli.py

# Capture the exit code
rc=$?

# Echo the exit code for the judge to parse
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout 623957c0a8d9fae308ced3cf99291852cefc32a8 "tests/unittests/cli/utils/test_cli.py"