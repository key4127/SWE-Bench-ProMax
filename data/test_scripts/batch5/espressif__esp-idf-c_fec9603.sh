#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test file
git checkout 91a6387005db04179937c2eee4ee5f2b468299c2 "components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c
--- a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c
+++ b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c
@@ -13,13 +13,14 @@
 #include "driver/i2s_std.h"
 #include "driver/uart.h"
 #include "soc/i2s_struct.h"
+#include "soc/soc_caps_full.h"
 #include "esp_sleep.h"
 #include "esp_private/sleep_cpu.h"
 #include "esp_private/esp_sleep_internal.h"
 #include "esp_private/esp_pmu.h"
 #include "../../test_inc/test_i2s.h"
 
-#define TEST_I2S_PD_SLEEP   (SOC_MODULE_SUPPORT(I2S, SLEEP_RETENTION) && CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP)
+#define TEST_I2S_PD_SLEEP   (SOC_HAS(PAU) && CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP)
 
 extern void i2s_read_write_test(i2s_chan_handle_t tx_chan, i2s_chan_handle_t rx_chan);
 
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_CCACHE_ENABLE=1
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_SKIP_CHECK_SUBMODULES=1
export LC_ALL=C.UTF-8
source /testbed/export.sh

# Initialize return code
rc=0

# Navigate to the I2S test apps directory
cd /testbed/components/esp_driver_i2s/test_apps/i2s

# Test 1: Build for ESP32 (default target)
echo "=== Building i2s test application for ESP32 ==="
idf.py set-target esp32
idf.py build
esp32_rc=$?

if [ $esp32_rc -ne 0 ]; then
    echo "ERROR: ESP32 build failed with exit code $esp32_rc"
    rc=1
else
    echo "SUCCESS: ESP32 i2s test application built successfully"
    # Verify output file exists
    if [ -f build/test_i2s.elf ] || [ -f build/i2s_test.elf ]; then
        echo "SUCCESS: ELF binary generated"
        ls -lh build/*.elf
    else
        echo "ERROR: ELF binary not found"
        rc=1
    fi
fi

# Clean build artifacts before next target
idf.py fullclean

# Test 2: Build for ESP32-S2
echo "=== Building i2s test application for ESP32-S2 ==="
idf.py set-target esp32s2
idf.py build
esp32s2_rc=$?

if [ $esp32s2_rc -ne 0 ]; then
    echo "ERROR: ESP32-S2 build failed with exit code $esp32s2_rc"
    rc=1
else
    echo "SUCCESS: ESP32-S2 i2s test application built successfully"
fi

# Clean build artifacts before next target
idf.py fullclean

# Test 3: Build for ESP32-C3
echo "=== Building i2s test application for ESP32-C3 ==="
idf.py set-target esp32c3
idf.py build
esp32c3_rc=$?

if [ $esp32c3_rc -ne 0 ]; then
    echo "ERROR: ESP32-C3 build failed with exit code $esp32c3_rc"
    rc=1
else
    echo "SUCCESS: ESP32-C3 i2s test application built successfully"
fi

# Clean build artifacts before next target
idf.py fullclean

# Test 4: Build for ESP32-S3
echo "=== Building i2s test application for ESP32-S3 ==="
idf.py set-target esp32s3
idf.py build
esp32s3_rc=$?

if [ $esp32s3_rc -ne 0 ]; then
    echo "ERROR: ESP32-S3 build failed with exit code $esp32s3_rc"
    rc=1
else
    echo "SUCCESS: ESP32-S3 i2s test application built successfully"
fi

# Clean build artifacts before next target
idf.py fullclean

# Test 5: Build for ESP32-C6
echo "=== Building i2s test application for ESP32-C6 ==="
idf.py set-target esp32c6
idf.py build
esp32c6_rc=$?

if [ $esp32c6_rc -ne 0 ]; then
    echo "ERROR: ESP32-C6 build failed with exit code $esp32c6_rc"
    rc=1
else
    echo "SUCCESS: ESP32-C6 i2s test application built successfully"
fi

# Clean build artifacts before next target
idf.py fullclean

# Test 6: Build for ESP32-H2
echo "=== Building i2s test application for ESP32-H2 ==="
idf.py set-target esp32h2
idf.py build
esp32h2_rc=$?

if [ $esp32h2_rc -ne 0 ]; then
    echo "ERROR: ESP32-H2 build failed with exit code $esp32h2_rc"
    rc=1
else
    echo "SUCCESS: ESP32-H2 i2s test application built successfully"
fi

# Determine overall exit code
if [ $esp32_rc -eq 0 ] && [ $esp32s2_rc -eq 0 ] && [ $esp32c3_rc -eq 0 ] && [ $esp32s3_rc -eq 0 ] && [ $esp32c6_rc -eq 0 ] && [ $esp32h2_rc -eq 0 ]; then
    echo "=== All I2S test applications built successfully for all supported targets ==="
    echo "=== Build verification confirms test patch is valid ==="
    echo "=== NOTE: Actual test execution requires physical ESP32 hardware ==="
    rc=0
else
    echo "=== One or more I2S test applications failed to build ==="
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 91a6387005db04179937c2eee4ee5f2b468299c2 "components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c"