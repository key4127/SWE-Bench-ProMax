#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 758cf6e1a3b1e983596a05369314f4706eb83b6a "components/app_update/test_apps/test_app_update/main/test_bootloader_update.c" "components/app_update/test_apps/test_app_update/main/test_ota_partitions.c" "components/spi_flash/test_apps/esp_flash/main/test_esp_flash_drv.c" "components/spi_flash/test_apps/esp_flash_blockdev/main/test_spi_flash.c" "components/spi_flash/test_apps/esp_flash_freq_limit/main/test_esp_flash_freq_limit.c" "examples/storage/.build-test-rules.yml" "tools/test_apps/system/g1_components/check_dependencies.py"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/app_update/test_apps/test_app_update/main/test_bootloader_update.c b/components/app_update/test_apps/test_app_update/main/test_bootloader_update.c
--- a/components/app_update/test_apps/test_app_update/main/test_bootloader_update.c
+++ b/components/app_update/test_apps/test_app_update/main/test_bootloader_update.c
@@ -10,7 +10,7 @@
 #include "unity.h"
 #include "esp_log.h"
 #include "esp_efuse.h"
-#include "esp_flash_internal.h"
+#include "esp_private/esp_flash_internal.h" //For dangerous write protection
 #include "esp_rom_sys.h"
 #include "utils_update.h"
 #include "sdkconfig.h"
diff --git a/components/app_update/test_apps/test_app_update/main/test_ota_partitions.c b/components/app_update/test_apps/test_app_update/main/test_ota_partitions.c
--- a/components/app_update/test_apps/test_app_update/main/test_ota_partitions.c
+++ b/components/app_update/test_apps/test_app_update/main/test_ota_partitions.c
@@ -6,7 +6,7 @@
 #include "esp_ota_ops.h"
 #include "esp_partition.h"
 #include "esp_flash_partitions.h"
-#include "esp_flash_internal.h"
+#include "esp_flash.h"
 #include "spi_flash_mmap.h"
 #include "esp_image_format.h"
 #include "esp_system.h"
@@ -34,12 +34,9 @@ static uint32_t find_unused_space(size_t required_size)
     esp_partition_iterator_release(it);
     TEST_ASSERT_NOT_NULL(latest_partition);
 
-#if CONFIG_IDF_TARGET_LINUX
     uint32_t flash_chip_size;
-    esp_flash_get_size(NULL, &flash_chip_size);
-#else
-    uint32_t flash_chip_size = esp_flash_default_chip->size;
-#endif // CONFIG_IDF_TARGET_LINUX
+    esp_err_t ret = esp_flash_get_size(esp_flash_default_chip, &flash_chip_size);
+    TEST_ASSERT_EQUAL(ESP_OK, ret);
     uint32_t unused_offset = latest_partition->address + latest_partition->size;
     TEST_ASSERT_GREATER_OR_EQUAL_UINT32(required_size, flash_chip_size - unused_offset);
     return unused_offset;
diff --git a/components/spi_flash/test_apps/esp_flash/main/test_esp_flash_drv.c b/components/spi_flash/test_apps/esp_flash/main/test_esp_flash_drv.c
--- a/components/spi_flash/test_apps/esp_flash/main/test_esp_flash_drv.c
+++ b/components/spi_flash/test_apps/esp_flash/main/test_esp_flash_drv.c
@@ -14,7 +14,7 @@
 #include "esp_flash.h"
 #include "esp_private/spi_common_internal.h"
 #include "esp_flash_spi_init.h"
-#include "memspi_host_driver.h"
+#include "esp_private/memspi_host_driver.h"
 #include <esp_attr.h>
 #include "esp_log.h"
 #include "test_utils.h"
diff --git a/components/spi_flash/test_apps/esp_flash_blockdev/main/test_spi_flash.c b/components/spi_flash/test_apps/esp_flash_blockdev/main/test_spi_flash.c
--- a/components/spi_flash/test_apps/esp_flash_blockdev/main/test_spi_flash.c
+++ b/components/spi_flash/test_apps/esp_flash_blockdev/main/test_spi_flash.c
@@ -9,7 +9,7 @@
 
 #include "esp_log.h"
 #include "unity.h"
-#include "esp_flash_port/spi_flash_chip_driver.h"
+#include "esp_flash_chips/spi_flash_chip_driver.h"
 #include "test_flash_utils.h"
 
 TEST_CASE("spi_flash BDL test", "[esp_flash]")
diff --git a/components/spi_flash/test_apps/esp_flash_freq_limit/main/idf_component.yml b/components/spi_flash/test_apps/esp_flash_freq_limit/main/idf_component.yml
new file mode 100644
--- /dev/null
+++ b/components/spi_flash/test_apps/esp_flash_freq_limit/main/idf_component.yml
@@ -0,0 +1,3 @@
+dependencies:
+  test_utils:
+    path: ${IDF_PATH}/tools/test_apps/components/test_utils
diff --git a/components/spi_flash/test_apps/esp_flash_freq_limit/main/test_esp_flash_freq_limit.c b/components/spi_flash/test_apps/esp_flash_freq_limit/main/test_esp_flash_freq_limit.c
--- a/components/spi_flash/test_apps/esp_flash_freq_limit/main/test_esp_flash_freq_limit.c
+++ b/components/spi_flash/test_apps/esp_flash_freq_limit/main/test_esp_flash_freq_limit.c
@@ -14,7 +14,7 @@
 #include <inttypes.h>
 #include "unity.h"
 #include "esp_flash.h"
-#include "esp_private/esp_flash_types.h"
+#include "esp_flash_chips/esp_flash_types.h"
 #include "soc/rtc.h"
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
diff --git a/examples/storage/.build-test-rules.yml b/examples/storage/.build-test-rules.yml
--- a/examples/storage/.build-test-rules.yml
+++ b/examples/storage/.build-test-rules.yml
@@ -3,6 +3,10 @@
 examples/storage/custom_flash_driver:
   depends_components:
     - spi_flash
+  disable:
+    - if: 1 == 1
+      temporary: true
+      reason: breaking change needs external component to fix first (IDF-15134)
 
 examples/storage/emmc:
   depends_components:
diff --git a/tools/test_apps/system/g1_components/check_dependencies.py b/tools/test_apps/system/g1_components/check_dependencies.py
--- a/tools/test_apps/system/g1_components/check_dependencies.py
+++ b/tools/test_apps/system/g1_components/check_dependencies.py
@@ -54,7 +54,7 @@ def get_all_esp_hal_components() -> list[str]:
 # Global expected dependency violations that apply to all targets
 expected_dep_violations = {
     'esp_system': ['esp_timer', 'bootloader_support', 'esp_pm', 'esp_usb_cdc_rom_console'],
-    'spi_flash': ['bootloader_support', 'esp_blockdev'],
+    'spi_flash': ['bootloader_support', 'esp_blockdev', 'esp_driver_gpio'],
     'esp_hw_support': ['efuse', 'bootloader_support', 'esp_driver_gpio', 'esp_timer', 'esp_pm'],
     'cxx': ['pthread'],
 }
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export CI_PIPELINE_ID=test-pipeline

# Verify Python dependencies are installed
python3 -m pip install --break-system-packages --upgrade pip
python3 -m pip install --break-system-packages -r ${IDF_PATH}/tools/requirements/requirements.core.txt

# Install test framework dependencies if available
if [ -f ${IDF_PATH}/tools/requirements/requirements.pytest.txt ]; then
    python3 -m pip install --break-system-packages -r ${IDF_PATH}/tools/requirements/requirements.pytest.txt
elif [ -f ${IDF_PATH}/tools/requirements/requirements.ci.txt ]; then
    python3 -m pip install --break-system-packages -r ${IDF_PATH}/tools/requirements/requirements.ci.txt
fi

# Initialize overall return code
overall_rc=0

# Test 1: Build test_app_update (contains test_bootloader_update.c and test_ota_partitions.c)
echo "=========================================="
echo "Building test_app_update..."
echo "=========================================="
cd /testbed/components/app_update/test_apps/test_app_update
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: test_app_update build failed with exit code $rc"
    overall_rc=$rc
fi

# Test 2: Build esp_flash test app (contains test_esp_flash_drv.c)
echo "=========================================="
echo "Building esp_flash test app..."
echo "=========================================="
cd /testbed/components/spi_flash/test_apps/esp_flash
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: esp_flash test app build failed with exit code $rc"
    overall_rc=$rc
fi

# Test 3: Build esp_flash_blockdev test app (contains test_spi_flash.c)
echo "=========================================="
echo "Building esp_flash_blockdev test app..."
echo "=========================================="
cd /testbed/components/spi_flash/test_apps/esp_flash_blockdev
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: esp_flash_blockdev test app build failed with exit code $rc"
    overall_rc=$rc
fi

# Test 4: Build esp_flash_freq_limit test app (contains test_esp_flash_freq_limit.c)
echo "=========================================="
echo "Building esp_flash_freq_limit test app..."
echo "=========================================="
cd /testbed/components/spi_flash/test_apps/esp_flash_freq_limit
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: esp_flash_freq_limit test app build failed with exit code $rc"
    overall_rc=$rc
fi

# Test 5: Build g1_components test app and run Python dependency check script
echo "=========================================="
echo "Building g1_components test app..."
echo "=========================================="
cd /testbed/tools/test_apps/system/g1_components
rm -rf build sdkconfig

# Check if there's a test app here to build
if [ -f "CMakeLists.txt" ]; then
    idf.py set-target esp32
    idf.py build
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: g1_components test app build failed with exit code $rc"
        overall_rc=$rc
    else
        # Run the dependency check script with the generated component_deps.dot file
        echo "=========================================="
        echo "Running check_dependencies.py..."
        echo "=========================================="
        if [ -f "build/component_deps.dot" ]; then
            python3 check_dependencies.py --component_deps_file build/component_deps.dot --target esp32
            rc=$?
            if [ $rc -ne 0 ]; then
                echo "ERROR: check_dependencies.py failed with exit code $rc"
                overall_rc=$rc
            fi
        else
            echo "WARNING: component_deps.dot not found, skipping check_dependencies.py"
        fi
    fi
else
    echo "WARNING: No CMakeLists.txt found in g1_components directory"
    # Try to run the script directly if it's a standalone script
    if [ -f "check_dependencies.py" ]; then
        echo "Attempting to run check_dependencies.py as standalone script..."
        python3 check_dependencies.py --help || true
        echo "WARNING: check_dependencies.py requires build artifacts, skipping execution"
    fi
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$overall_rc"

# Cleanup: restore original files
cd /testbed
git checkout 758cf6e1a3b1e983596a05369314f4706eb83b6a "components/app_update/test_apps/test_app_update/main/test_bootloader_update.c" "components/app_update/test_apps/test_app_update/main/test_ota_partitions.c" "components/spi_flash/test_apps/esp_flash/main/test_esp_flash_drv.c" "components/spi_flash/test_apps/esp_flash_blockdev/main/test_spi_flash.c" "components/spi_flash/test_apps/esp_flash_freq_limit/main/test_esp_flash_freq_limit.c" "examples/storage/.build-test-rules.yml" "tools/test_apps/system/g1_components/check_dependencies.py"