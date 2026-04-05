#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 9adbef737423889e6a766ea8cc4d10efc78bda0d "components/esp_driver_ledc/test_apps/.build-test-rules.yml" "components/esp_driver_ledc/test_apps/ledc/CMakeLists.txt" "components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.cpp" "examples/peripherals/.build-test-rules.yml"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_ledc/test_apps/.build-test-rules.yml b/components/esp_driver_ledc/test_apps/.build-test-rules.yml
--- a/components/esp_driver_ledc/test_apps/.build-test-rules.yml
+++ b/components/esp_driver_ledc/test_apps/.build-test-rules.yml
@@ -5,3 +5,4 @@ components/esp_driver_ledc/test_apps/ledc:
     - if: SOC_LEDC_SUPPORTED != 1
   depends_components:
     - esp_driver_ledc
+    - esp_hal_ledc
diff --git a/components/esp_driver_ledc/test_apps/ledc/CMakeLists.txt b/components/esp_driver_ledc/test_apps/ledc/CMakeLists.txt
--- a/components/esp_driver_ledc/test_apps/ledc/CMakeLists.txt
+++ b/components/esp_driver_ledc/test_apps/ledc/CMakeLists.txt
@@ -9,10 +9,16 @@ project(ledc_test)
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    set(LEDC_RTL_DIRS
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_ledc
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_ledc
+    )
+    string(JOIN "," LEDC_RTL_DIRS_JOINED ${LEDC_RTL_DIRS})
     add_custom_target(
         check_test_app_sections ALL
         COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-        --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_ledc/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+        --rtl-dirs ${LEDC_RTL_DIRS_JOINED}
         --elf-file ${CMAKE_BINARY_DIR}/ledc_test.elf
         find-refs
         --from-sections=.iram0.text
diff --git a/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.cpp b/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.cpp
--- a/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.cpp
+++ b/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.cpp
@@ -14,7 +14,7 @@
 #include "esp_private/sleep_cpu.h"
 #include "esp_private/esp_sleep_internal.h"
 #include "esp_private/esp_pmu.h"
-#include "soc/ledc_periph.h"
+#include "hal/ledc_periph.h"
 #include "esp_private/sleep_retention.h"
 #include "esp_rom_serial_output.h"
 
diff --git a/examples/peripherals/.build-test-rules.yml b/examples/peripherals/.build-test-rules.yml
--- a/examples/peripherals/.build-test-rules.yml
+++ b/examples/peripherals/.build-test-rules.yml
@@ -272,18 +272,15 @@ examples/peripherals/ledc:
     - if: SOC_LEDC_SUPPORTED != 1
   depends_components:
     - esp_driver_ledc
+    - esp_hal_ledc
 
 examples/peripherals/ledc/ledc_dimmer:
   disable:
     - if: SOC_ETM_SUPPORTED != 1 or SOC_LEDC_SUPPORT_ETM != 1
-  depends_components:
-    - esp_driver_ledc
 
 examples/peripherals/ledc/ledc_gamma_curve_fade:
   disable:
     - if: SOC_LEDC_SUPPORTED != 1 or SOC_LEDC_GAMMA_CURVE_FADE_SUPPORTED != 1
-  depends_components:
-    - esp_driver_ledc
 
 examples/peripherals/mcpwm:
   disable:
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export CI_PIPELINE_ID=test-pipeline

# Verify Python dependencies are installed
python3 -m pip install -r ${IDF_PATH}/tools/requirements/requirements.core.txt
# Install test framework dependencies if available
if [ -f ${IDF_PATH}/tools/requirements/requirements.pytest.txt ]; then
    python3 -m pip install -r ${IDF_PATH}/tools/requirements/requirements.pytest.txt
elif [ -f ${IDF_PATH}/tools/requirements/requirements.ci.txt ]; then
    python3 -m pip install -r ${IDF_PATH}/tools/requirements/requirements.ci.txt
fi

# Navigate to the LEDC test directory
cd /testbed/components/esp_driver_ledc/test_apps/ledc

# Clean any previous build artifacts
rm -rf build sdkconfig

# Set target to esp32 (primary target for LEDC tests)
idf.py set-target esp32

# Build the test application
# This validates syntax, semantics, API usage, dependency resolution, and linking
# Success indicates the test code is correct and compatible with ESP-IDF v6.1
idf.py build
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 9adbef737423889e6a766ea8cc4d10efc78bda0d "components/esp_driver_ledc/test_apps/.build-test-rules.yml" "components/esp_driver_ledc/test_apps/ledc/CMakeLists.txt" "components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.cpp" "examples/peripherals/.build-test-rules.yml"