#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the original test file to ensure clean state
git checkout d30dc9fdc1138be3f409057dac74744e2882f6f2 "tests/test_memory_macos.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_memory_macos.py b/tests/test_memory_macos.py
--- a/tests/test_memory_macos.py
+++ b/tests/test_memory_macos.py
@@ -4,7 +4,7 @@
 import psutil
 import platform
 import time
-from crawl4ai.memory_utils import get_true_memory_usage_percent, get_memory_stats, get_true_available_memory_gb
+from crawl4ai.utils import get_true_memory_usage_percent, get_memory_stats, get_true_available_memory_gb
 
 
 def test_memory_calculation():
EOF_114329324912

# Execute the memory test using direct Python interpreter
# This is NOT a pytest test - it's a standalone diagnostic script
python tests/test_memory_macos.py

# Capture exit code immediately
rc=$?

# Echo exit code for the judge to evaluate
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore the original test file
git checkout d30dc9fdc1138be3f409057dac74744e2882f6f2 "tests/test_memory_macos.py"