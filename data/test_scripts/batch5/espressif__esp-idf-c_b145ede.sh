#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 76b28d8257139453f158beafe95dec47d6fa4e3f "components/esp_hw_support/test_apps/mspi/main/CMakeLists.txt" "components/esp_psram/test_apps/.build-test-rules.yml" "components/spi_flash/test_apps/.build-test-rules.yml"

# Apply the test patch
echo "=== Applying test patch ==="
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_hw_support/test_apps/mspi/main/CMakeLists.txt b/components/esp_hw_support/test_apps/mspi/main/CMakeLists.txt
--- a/components/esp_hw_support/test_apps/mspi/main/CMakeLists.txt
+++ b/components/esp_hw_support/test_apps/mspi/main/CMakeLists.txt
@@ -7,5 +7,5 @@ set(srcs
 # In order for the cases defined by `TEST_CASE` to be linked into the final elf,
 # the component can be registered as WHOLE_ARCHIVE
 idf_component_register(SRCS ${srcs}
-                       PRIV_REQUIRES unity esp_timer spi_flash esp_partition
+                       PRIV_REQUIRES unity esp_timer spi_flash esp_partition esp_hal_mspi
                        WHOLE_ARCHIVE)
diff --git a/components/esp_psram/test_apps/.build-test-rules.yml b/components/esp_psram/test_apps/.build-test-rules.yml
--- a/components/esp_psram/test_apps/.build-test-rules.yml
+++ b/components/esp_psram/test_apps/.build-test-rules.yml
@@ -10,3 +10,4 @@ components/esp_psram/test_apps/psram:
     - esp_driver_gpio
     - esp_driver_spi
     - spi_flash
+    - esp_hal_mspi
diff --git a/components/spi_flash/test_apps/.build-test-rules.yml b/components/spi_flash/test_apps/.build-test-rules.yml
--- a/components/spi_flash/test_apps/.build-test-rules.yml
+++ b/components/spi_flash/test_apps/.build-test-rules.yml
@@ -14,6 +14,7 @@ components/spi_flash/test_apps/esp_flash:
     - esp_driver_gpio
     - esp_driver_spi
     - esptool_py # Some flash related kconfigs are listed here.
+    - esp_hal_mspi
 
 components/spi_flash/test_apps/esp_flash_stress:
   disable:
@@ -23,6 +24,7 @@ components/spi_flash/test_apps/esp_flash_stress:
   depends_components:
     - esp_mm
     - spi_flash
+    - esp_hal_mspi
 
 components/spi_flash/test_apps/flash_encryption:
   disable:
@@ -37,11 +39,13 @@ components/spi_flash/test_apps/flash_encryption:
   depends_components:
     - esp_mm
     - spi_flash
+    - esp_hal_mspi
 
 components/spi_flash/test_apps/flash_mmap:
   depends_components:
     - esp_mm
     - spi_flash
+    - esp_hal_mspi
   enable:
     - if: CONFIG_NAME == "release" and IDF_TARGET != "linux"
     - if: CONFIG_NAME == "rom_impl" and ESP_ROM_HAS_SPI_FLASH == 1
@@ -64,6 +68,7 @@ components/spi_flash/test_apps/flash_suspend:
   depends_components:
     - spi_flash
     - esp_driver_gptimer
+    - esp_hal_mspi
 
 components/spi_flash/test_apps/mspi_test:
   disable:
@@ -78,3 +83,4 @@ components/spi_flash/test_apps/mspi_test:
     - esp_driver_gpio
     - esp_driver_spi
     - esptool_py # Some flash related kconfigs are listed here.
+    - esp_hal_mspi
EOF_114329324912

# Verify patch application
echo "=== Verifying patch was applied correctly ==="
echo "Checking modified files..."
git diff --name-only HEAD

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_CCACHE_ENABLE=1
source /testbed/export.sh

# Initialize return code
rc=0

# Test 1: Build MSPI test application (esp32s3 target)
echo "=== Building MSPI test application for ESP32-S3 ==="
cd /testbed/components/esp_hw_support/test_apps/mspi
rm -rf build sdkconfig

idf.py set-target esp32s3
idf.py build
mspi_build_rc=$?

if [ $mspi_build_rc -ne 0 ]; then
    echo "ERROR: MSPI test application build failed with exit code $mspi_build_rc"
    rc=1
else
    echo "SUCCESS: MSPI test application built successfully for ESP32-S3"
fi

# Test 2: Build PSRAM test application (esp32s3 target)
echo "=== Building PSRAM test application for ESP32-S3 ==="
cd /testbed/components/esp_psram/test_apps/psram
rm -rf build sdkconfig

idf.py set-target esp32s3
idf.py build
psram_build_rc=$?

if [ $psram_build_rc -ne 0 ]; then
    echo "ERROR: PSRAM test application build failed with exit code $psram_build_rc"
    rc=1
else
    echo "SUCCESS: PSRAM test application built successfully for ESP32-S3"
fi

# Test 3: Build SPI Flash test applications
# Test esp_flash app
echo "=== Building esp_flash test application for ESP32-S3 ==="
cd /testbed/components/spi_flash/test_apps/esp_flash
rm -rf build sdkconfig

idf.py set-target esp32s3
idf.py build
esp_flash_build_rc=$?

if [ $esp_flash_build_rc -ne 0 ]; then
    echo "ERROR: esp_flash test application build failed with exit code $esp_flash_build_rc"
    rc=1
else
    echo "SUCCESS: esp_flash test application built successfully for ESP32-S3"
fi

# Test flash_mmap app
echo "=== Building flash_mmap test application for ESP32-S3 ==="
cd /testbed/components/spi_flash/test_apps/flash_mmap
rm -rf build sdkconfig

idf.py set-target esp32s3
idf.py build
flash_mmap_build_rc=$?

if [ $flash_mmap_build_rc -ne 0 ]; then
    echo "ERROR: flash_mmap test application build failed with exit code $flash_mmap_build_rc"
    rc=1
else
    echo "SUCCESS: flash_mmap test application built successfully for ESP32-S3"
fi

# Test mspi_test app
echo "=== Building mspi_test (spi_flash) application for ESP32-S3 ==="
cd /testbed/components/spi_flash/test_apps/mspi_test
rm -rf build sdkconfig

idf.py set-target esp32s3
idf.py build
spi_mspi_build_rc=$?

if [ $spi_mspi_build_rc -ne 0 ]; then
    echo "ERROR: mspi_test (spi_flash) application build failed with exit code $spi_mspi_build_rc"
    rc=1
else
    echo "SUCCESS: mspi_test (spi_flash) application built successfully for ESP32-S3"
fi

# Summary of results
echo "=== Build Test Summary ==="
echo "MSPI test app: $([ $mspi_build_rc -eq 0 ] && echo 'PASS' || echo 'FAIL')"
echo "PSRAM test app: $([ $psram_build_rc -eq 0 ] && echo 'PASS' || echo 'FAIL')"
echo "esp_flash test app: $([ $esp_flash_build_rc -eq 0 ] && echo 'PASS' || echo 'FAIL')"
echo "flash_mmap test app: $([ $flash_mmap_build_rc -eq 0 ] && echo 'PASS' || echo 'FAIL')"
echo "mspi_test (spi_flash) app: $([ $spi_mspi_build_rc -eq 0 ] && echo 'PASS' || echo 'FAIL')"

# Final result
if [ $rc -eq 0 ]; then
    echo "=== All build tests passed successfully ==="
else
    echo "=== Some build tests failed ==="
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 76b28d8257139453f158beafe95dec47d6fa4e3f "components/esp_hw_support/test_apps/mspi/main/CMakeLists.txt" "components/esp_psram/test_apps/.build-test-rules.yml" "components/spi_flash/test_apps/.build-test-rules.yml"