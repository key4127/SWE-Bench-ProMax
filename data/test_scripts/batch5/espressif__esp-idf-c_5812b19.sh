#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test file
git checkout bfcba51ca10b1c777cc9fa36facdb9bca9741277 "tools/test_apps/system/g1_components/check_dependencies.py"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tools/test_apps/system/g1_components/check_dependencies.py b/tools/test_apps/system/g1_components/check_dependencies.py
--- a/tools/test_apps/system/g1_components/check_dependencies.py
+++ b/tools/test_apps/system/g1_components/check_dependencies.py
@@ -1,18 +1,35 @@
-# SPDX-FileCopyrightText: 2024 Espressif Systems (Shanghai) CO LTD
+# SPDX-FileCopyrightText: 2024-2025 Espressif Systems (Shanghai) CO LTD
 # SPDX-License-Identifier: Unlicense OR CC0-1.0
 import argparse
 import logging
 from typing import Dict
 from typing import List
 from typing import Tuple
 
-g1_g0_components = ['hal', 'cxx', 'newlib', 'freertos', 'esp_hw_support', 'heap', 'log', 'soc', 'esp_rom',
-                    'esp_common', 'esp_system', 'xtensa', 'riscv', 'spi_flash', 'esp_mm']
-
-expected_dep_violations = {'esp_system': ['esp_timer', 'bootloader_support', 'esp_pm'],
-                           'spi_flash': ['bootloader_support', 'app_update', 'esp_driver_gpio'],
-                           'esp_hw_support': ['efuse', 'bootloader_support', 'esp_driver_gpio', 'esp_timer', 'esp_pm', 'esp_security'],
-                           'cxx': ['pthread']}
+g1_g0_components = [
+    'hal',
+    'cxx',
+    'newlib',
+    'freertos',
+    'esp_hw_support',
+    'heap',
+    'log',
+    'soc',
+    'esp_rom',
+    'esp_common',
+    'esp_system',
+    'xtensa',
+    'riscv',
+    'spi_flash',
+    'esp_mm',
+]
+
+expected_dep_violations = {
+    'esp_system': ['esp_timer', 'bootloader_support', 'esp_pm'],
+    'spi_flash': ['bootloader_support'],
+    'esp_hw_support': ['efuse', 'bootloader_support', 'esp_driver_gpio', 'esp_timer', 'esp_pm', 'esp_security'],
+    'cxx': ['pthread'],
+}
 
 
 def parse_dependencies(file_path: str) -> Tuple[Dict[str, List[str]], List[str]]:
@@ -25,7 +42,7 @@ def parse_dependencies(file_path: str) -> Tuple[Dict[str, List[str]], List[str]]
             if line:
                 parts = line.split(' -> ')
 
-                if (len(parts) >= 2):
+                if len(parts) >= 2:
                     source = parts[0]
                     target = parts[1].split()[0]  # Extracting the target component
                     logging.debug(f'Parsed dependency: {source} -> {target}')
@@ -48,7 +65,9 @@ def parse_dependencies(file_path: str) -> Tuple[Dict[str, List[str]], List[str]]
 
 if __name__ == '__main__':
     parser = argparse.ArgumentParser(description='Check G1 dependencies')
-    parser.add_argument('--component_deps_file', required=True, type=str, help='The path to the component_deps.dot file')
+    parser.add_argument(
+        '--component_deps_file', required=True, type=str, help='The path to the component_deps.dot file'
+    )
 
     args = parser.parse_args()
 
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_SKIP_CHECK_SUBMODULES=1
source /testbed/export.sh

# Initialize return code
rc=0

# Navigate to the test directory
cd /testbed/tools/test_apps/system/g1_components

# Run idf.py reconfigure to generate component_deps.dot
echo "=== Running idf.py reconfigure to generate component dependency graph ==="
idf.py reconfigure
reconfigure_rc=$?

if [ $reconfigure_rc -ne 0 ]; then
    echo "ERROR: idf.py reconfigure failed with exit code $reconfigure_rc"
    rc=1
else
    echo "SUCCESS: idf.py reconfigure completed successfully"
    
    # Check if the dependency file was generated
    if [ ! -f build/component_deps.dot ]; then
        echo "ERROR: build/component_deps.dot was not generated"
        rc=1
    else
        echo "=== Running check_dependencies.py test ==="
        python check_dependencies.py --component_deps_file build/component_deps.dot
        test_rc=$?
        
        if [ $test_rc -ne 0 ]; then
            echo "ERROR: check_dependencies.py test failed with exit code $test_rc"
            rc=1
        else
            echo "SUCCESS: check_dependencies.py test passed"
            rc=0
        fi
    fi
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout bfcba51ca10b1c777cc9fa36facdb9bca9741277 "tools/test_apps/system/g1_components/check_dependencies.py"