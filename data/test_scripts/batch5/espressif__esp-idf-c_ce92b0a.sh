#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout dee2895ab4bc8c15c9c0a56b10df10d07de2c31f "components/driver/test_apps/touch_sensor_v2/main/touch_scope.c" "components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c" "components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c" "components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c" "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" "components/esp_system/test_apps/console/main/test_app_main.c" "components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c" "components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c" "components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c" "components/log/test_apps/main/test_log_level.c" "components/log/test_apps/main/test_log_perf.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/driver/test_apps/touch_sensor_v2/main/touch_scope.c b/components/driver/test_apps/touch_sensor_v2/main/touch_scope.c
--- a/components/driver/test_apps/touch_sensor_v2/main/touch_scope.c
+++ b/components/driver/test_apps/touch_sensor_v2/main/touch_scope.c
@@ -7,7 +7,7 @@
 #include <string.h>
 #include "esp_err.h"
 #include "driver/uart.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 
 #define ROM_UART_DRIVER_ENABLE 0
 
diff --git a/components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c b/components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c
--- a/components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c
+++ b/components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c
@@ -28,7 +28,7 @@
 #include "freertos/queue.h"
 #include "freertos/semphr.h"
 #include "sdkconfig.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "esp_rom_sys.h"
 #include "spi_flash_mmap.h"
 #include "esp_attr.h"
diff --git a/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c b/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c
--- a/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c
+++ b/components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c
@@ -16,7 +16,7 @@
 #include "esp_private/esp_pmu.h"
 #include "soc/ledc_periph.h"
 #include "esp_private/sleep_retention.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 
 // Note. Test cases in this file cannot run one after another without reset
 
diff --git a/components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c b/components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c
--- a/components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c
+++ b/components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c
@@ -12,7 +12,7 @@
 #include <sys/errno.h>
 #include <unistd.h>
 #include "unity.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "freertos/semphr.h"
diff --git a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c
--- a/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c
+++ b/components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c
@@ -22,7 +22,7 @@
 #include "driver/uart.h"
 #include "unity.h"
 #include "test_utils.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "hal/uart_types.h"
 #include "hal/uart_ll.h"
 #include "soc/dport_reg.h"
diff --git a/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c b/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
--- a/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
+++ b/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
@@ -19,7 +19,7 @@
 #include "freertos/task.h"
 #include "esp_rom_gpio.h"
 #include "esp_rom_sys.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "test_utils.h"
 #include "esp_random.h"
 #include "esp_sleep.h"
diff --git a/components/esp_system/test_apps/console/main/test_app_main.c b/components/esp_system/test_apps/console/main/test_app_main.c
--- a/components/esp_system/test_apps/console/main/test_app_main.c
+++ b/components/esp_system/test_apps/console/main/test_app_main.c
@@ -8,7 +8,7 @@
 #include <string.h>
 #include "sdkconfig.h"
 
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "esp_rom_sys.h"
 
 #include "hal/uart_ll.h"
diff --git a/components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c b/components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c
--- a/components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c
+++ b/components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c
@@ -12,7 +12,7 @@
 #include "unity.h"
 #include "test_utils.h"
 #include "esp_rom_sys.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 
 #if CONFIG_IDF_TARGET_ARCH_XTENSA
 
diff --git a/components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c b/components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c
--- a/components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c
+++ b/components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c
@@ -25,7 +25,7 @@
 #include "esp_newlib.h"
 #include "test_utils.h"
 #include "sdkconfig.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "esp_rom_sys.h"
 #include "esp_timer.h"
 #include "esp_private/esp_clk.h"
diff --git a/components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c b/components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c
--- a/components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c
+++ b/components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c
@@ -5,11 +5,11 @@
  */
 
 #include <stddef.h>
-
+#include "esp_attr.h"
 #include "soc/soc_caps.h"
 #include "esp_macros.h"
 #include "esp_rom_sys.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 
 #include "riscv/csr.h"
 #include "riscv/rvruntime-frames.h"
diff --git a/components/log/test_apps/main/test_log_level.c b/components/log/test_apps/main/test_log_level.c
--- a/components/log/test_apps/main/test_log_level.c
+++ b/components/log/test_apps/main/test_log_level.c
@@ -10,7 +10,7 @@
 #include <string.h>
 #include <inttypes.h>
 #include "unity.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "sdkconfig.h"
 
 /*
diff --git a/components/log/test_apps/main/test_log_perf.c b/components/log/test_apps/main/test_log_perf.c
--- a/components/log/test_apps/main/test_log_perf.c
+++ b/components/log/test_apps/main/test_log_perf.c
@@ -14,7 +14,7 @@
 #include "freertos/semphr.h"
 #include "esp_log.h"
 #include "esp_timer.h"
-#include "esp_rom_uart.h"
+#include "esp_rom_serial_output.h"
 #include "sdkconfig.h"
 
 typedef struct {
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export IDF_SKIP_CHECK_SUBMODULES=1
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== Building and Testing ESP-IDF Test Applications ==="
echo "=== Note: Full test execution requires physical ESP32 hardware ==="
echo "=== This script performs build verification and pytest infrastructure validation ==="

# Test 1: Build touch_sensor_v2 test app for esp32s2
echo "=== Test 1: Building touch_sensor_v2 test app (esp32s2) ==="
cd /testbed/components/driver/test_apps/touch_sensor_v2
rm -rf build sdkconfig
idf.py set-target esp32s2
idf.py build
test1_rc=$?
if [ $test1_rc -ne 0 ]; then
    echo "ERROR: touch_sensor_v2 test app build failed"
    rc=1
else
    echo "SUCCESS: touch_sensor_v2 test app built successfully"
    if [ -f "pytest_touch_sensor_v2.py" ]; then
        pytest --collect-only pytest_touch_sensor_v2.py --target=esp32s2 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 2: Build gpio test app for esp32
echo "=== Test 2: Building gpio test app (esp32) ==="
cd /testbed/components/esp_driver_gpio/test_apps/gpio
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test2_rc=$?
if [ $test2_rc -ne 0 ]; then
    echo "ERROR: gpio test app build failed"
    rc=1
else
    echo "SUCCESS: gpio test app built successfully"
    if [ -f "pytest_gpio.py" ]; then
        pytest --collect-only pytest_gpio.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 3: Build ledc test app for esp32
echo "=== Test 3: Building ledc test app (esp32) ==="
cd /testbed/components/esp_driver_ledc/test_apps/ledc
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test3_rc=$?
if [ $test3_rc -ne 0 ]; then
    echo "ERROR: ledc test app build failed"
    rc=1
else
    echo "SUCCESS: ledc test app built successfully"
    if [ -f "pytest_ledc.py" ]; then
        pytest --collect-only pytest_ledc.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 4: Build uart_vfs test app for esp32
echo "=== Test 4: Building uart_vfs test app (esp32) ==="
cd /testbed/components/esp_driver_uart/test_apps/uart_vfs
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test4_rc=$?
if [ $test4_rc -ne 0 ]; then
    echo "ERROR: uart_vfs test app build failed"
    rc=1
else
    echo "SUCCESS: uart_vfs test app built successfully"
    if [ -f "pytest_uart_vfs.py" ]; then
        pytest --collect-only pytest_uart_vfs.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 5: Build esp_hw_support_unity_tests test app for esp32
echo "=== Test 5: Building esp_hw_support_unity_tests test app (esp32) ==="
cd /testbed/components/esp_hw_support/test_apps/esp_hw_support_unity_tests
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test5_rc=$?
if [ $test5_rc -ne 0 ]; then
    echo "ERROR: esp_hw_support_unity_tests test app build failed"
    rc=1
else
    echo "SUCCESS: esp_hw_support_unity_tests test app built successfully"
    if [ -f "pytest_esp_hw_support.py" ]; then
        pytest --collect-only pytest_esp_hw_support.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 6: Build rtc_clk test app for esp32
echo "=== Test 6: Building rtc_clk test app (esp32) ==="
cd /testbed/components/esp_hw_support/test_apps/rtc_clk
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test6_rc=$?
if [ $test6_rc -ne 0 ]; then
    echo "ERROR: rtc_clk test app build failed"
    rc=1
else
    echo "SUCCESS: rtc_clk test app built successfully"
    if [ -f "pytest_rtc_clk.py" ]; then
        pytest --collect-only pytest_rtc_clk.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 7: Build console test app for esp32
echo "=== Test 7: Building console test app (esp32) ==="
cd /testbed/components/esp_system/test_apps/console
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test7_rc=$?
if [ $test7_rc -ne 0 ]; then
    echo "ERROR: console test app build failed"
    rc=1
else
    echo "SUCCESS: console test app built successfully"
    if [ -f "pytest_console.py" ]; then
        pytest --collect-only pytest_console.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 8: Build esp_system_unity_tests test app for esp32
echo "=== Test 8: Building esp_system_unity_tests test app (esp32) ==="
cd /testbed/components/esp_system/test_apps/esp_system_unity_tests
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test8_rc=$?
if [ $test8_rc -ne 0 ]; then
    echo "ERROR: esp_system_unity_tests test app build failed"
    rc=1
else
    echo "SUCCESS: esp_system_unity_tests test app built successfully"
    if [ -f "pytest_esp_system.py" ]; then
        pytest --collect-only pytest_esp_system.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 9: Build tee_apm test app for esp32c6
echo "=== Test 9: Building tee_apm test app (esp32c6) ==="
cd /testbed/components/hal/test_apps/tee_apm
rm -rf build sdkconfig
idf.py set-target esp32c6
idf.py build
test9_rc=$?
if [ $test9_rc -ne 0 ]; then
    echo "ERROR: tee_apm test app build failed"
    rc=1
else
    echo "SUCCESS: tee_apm test app built successfully"
    if [ -f "pytest_tee_apm.py" ]; then
        pytest --collect-only pytest_tee_apm.py --target=esp32c6 2>&1 | tee pytest_collect.log || true
    fi
fi

# Test 10: Build log test app for esp32
echo "=== Test 10: Building log test app (esp32) ==="
cd /testbed/components/log/test_apps
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
test10_rc=$?
if [ $test10_rc -ne 0 ]; then
    echo "ERROR: log test app build failed"
    rc=1
else
    echo "SUCCESS: log test app built successfully"
    if [ -f "pytest_log.py" ]; then
        pytest --collect-only pytest_log.py --target=esp32 2>&1 | tee pytest_collect.log || true
    fi
fi

# Validate that test binaries were created
echo "=== Validating test binaries were created ==="
for test_dir in \
    "/testbed/components/driver/test_apps/touch_sensor_v2" \
    "/testbed/components/esp_driver_gpio/test_apps/gpio" \
    "/testbed/components/esp_driver_ledc/test_apps/ledc" \
    "/testbed/components/esp_driver_uart/test_apps/uart_vfs" \
    "/testbed/components/esp_hw_support/test_apps/esp_hw_support_unity_tests" \
    "/testbed/components/esp_hw_support/test_apps/rtc_clk" \
    "/testbed/components/esp_system/test_apps/console" \
    "/testbed/components/esp_system/test_apps/esp_system_unity_tests" \
    "/testbed/components/hal/test_apps/tee_apm" \
    "/testbed/components/log/test_apps"
do
    if [ -d "$test_dir/build" ]; then
        elf_count=$(find "$test_dir/build" -name "*.elf" 2>/dev/null | wc -l)
        if [ $elf_count -gt 0 ]; then
            echo "SUCCESS: Found $elf_count ELF binary(ies) in $test_dir"
        else
            echo "INFO: No ELF binaries found in $test_dir/build"
        fi
    fi
done

# Determine overall exit code
if [ $test1_rc -eq 0 ] && [ $test2_rc -eq 0 ] && [ $test3_rc -eq 0 ] && \
   [ $test4_rc -eq 0 ] && [ $test5_rc -eq 0 ] && [ $test6_rc -eq 0 ] && \
   [ $test7_rc -eq 0 ] && [ $test8_rc -eq 0 ] && [ $test9_rc -eq 0 ] && \
   [ $test10_rc -eq 0 ]; then
    echo "=== All test applications built successfully ==="
    echo "=== Build verification confirms patches are valid ==="
    echo "=== Note: Actual Unity test execution requires physical ESP32 hardware ==="
    echo "=== The patched test files have been successfully compiled into test binaries ==="
    rc=0
else
    echo "=== One or more test applications failed to build ==="
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout dee2895ab4bc8c15c9c0a56b10df10d07de2c31f "components/driver/test_apps/touch_sensor_v2/main/touch_scope.c" "components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c" "components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c" "components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c" "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c" "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" "components/esp_system/test_apps/console/main/test_app_main.c" "components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c" "components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c" "components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c" "components/log/test_apps/main/test_log_level.c" "components/log/test_apps/main/test_log_perf.c"