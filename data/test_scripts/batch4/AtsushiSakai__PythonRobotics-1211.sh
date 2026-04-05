#!/bin/bash
set -uxo pipefail
cd /testbed

# Checkout the original test file to ensure clean state
git checkout 22cbee49218a1f8acb07ad488416db3c952c19d6 "tests/test_raycasting_grid_map.py"

# Apply the test patch (which renames the file)
git apply -v - <<'EOF_114329324912'
diff --git a/tests/test_raycasting_grid_map.py b/tests/test_ray_casting_grid_map.py
rename from tests/test_raycasting_grid_map.py
rename to tests/test_ray_casting_grid_map.py
--- a/tests/test_raycasting_grid_map.py
+++ b/tests/test_ray_casting_grid_map.py
@@ -1,5 +1,5 @@
 import conftest  # Add root path to sys.path
-from Mapping.raycasting_grid_map import raycasting_grid_map as m
+from Mapping.ray_casting_grid_map import ray_casting_grid_map as m
 
 
 def test1():
EOF_114329324912

# Execute the target test file with pytest
# NOTE: The patch renames the file from test_raycasting_grid_map.py to test_ray_casting_grid_map.py
# Using the NEW filename after the patch is applied
# Filter out pyparsing deprecation warnings from matplotlib to avoid false failures
pytest tests/test_ray_casting_grid_map.py -l -Werror -W ignore::pyparsing.warnings.PyparsingDeprecationWarning --durations=0
rc=$?

# Required: echo test status for judge evaluation
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original test file (use original name for checkout)
git checkout 22cbee49218a1f8acb07ad488416db3c952c19d6 "tests/test_raycasting_grid_map.py"