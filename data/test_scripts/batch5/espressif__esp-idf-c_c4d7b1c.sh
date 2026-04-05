#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 20f17000534efc19e38b5452cabf5a64b143d9e8 \
    "components/driver/test_apps/touch_sensor_v2/main/touch_scope.c" \
    "components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c" \
    "components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c" \
    "components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c" \
    "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c" \
    "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" \
    "components/esp_system/test_apps/console/main/test_app_main.c" \
    "components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c" \
    "components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c" \
    "components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c" \
    "components/log/test_apps/main/test_log_level.c" \
    "components/log/test_apps/main/test_log_perf.c"

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
source /testbed/export.sh

# Initialize return code
rc=0

# Function to build test app for a specific target
build_test_app() {
    local test_dir=$1
    local target=$2
    local test_name=$3
    
    echo "=== Building $test_name for $target ==="
    cd /testbed/$test_dir
    
    idf.py set-target $target
    idf.py build
    local build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: $test_name build failed for $target with exit code $build_rc"
        rc=1
    else
        echo "SUCCESS: $test_name built successfully for $target"
    fi
    
    idf.py fullclean
    return $build_rc
}

# Test 1: Touch Sensor V2 (esp32s2, esp32s3)
build_test_app "components/driver/test_apps/touch_sensor_v2" "esp32s2" "touch_sensor_v2"

# Test 2: GPIO (esp32, esp32s2, esp32c3)
build_test_app "components/esp_driver_gpio/test_apps/gpio" "esp32" "gpio"

# Test 3: LEDC (esp32, esp32s2, esp32c3)
build_test_app "components/esp_driver_ledc/test_apps/ledc" "esp32" "ledc"

# Test 4: UART VFS (esp32, esp32s2, esp32c3)
build_test_app "components/esp_driver_uart/test_apps/uart_vfs" "esp32" "uart_vfs"

# Test 5: ESP HW Support Unity Tests (esp32, esp32s2, esp32c3)
build_test_app "components/esp_hw_support/test_apps/esp_hw_support_unity_tests" "esp32" "esp_hw_support_unity_tests"

# Test 6: RTC CLK (esp32, esp32s2, esp32c3)
build_test_app "components/esp_hw_support/test_apps/rtc_clk" "esp32" "rtc_clk"

# Test 7: Console (esp32, esp32s2, esp32c3)
build_test_app "components/esp_system/test_apps/console" "esp32" "console"

# Test 8: ESP System Unity Tests (esp32, esp32s2, esp32c3)
build_test_app "components/esp_system/test_apps/esp_system_unity_tests" "esp32" "esp_system_unity_tests"

# Test 9: TEE APM (esp32c6, esp32h2)
build_test_app "components/hal/test_apps/tee_apm" "esp32c6" "tee_apm"

# Test 10: Log Test Apps (esp32, esp32s2, esp32c3)
build_test_app "components/log/test_apps" "esp32" "log_test_apps"

# Summary
if [ $rc -eq 0 ]; then
    echo "=== All test applications built successfully ==="
    echo "=== Build verification confirms patches are valid ==="
else
    echo "=== One or more test applications failed to build ==="
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 20f17000534efc19e38b5452cabf5a64b143d9e8 \
    "components/driver/test_apps/touch_sensor_v2/main/touch_scope.c" \
    "components/esp_driver_gpio/test_apps/gpio/main/test_gpio.c" \
    "components/esp_driver_ledc/test_apps/ledc/main/test_ledc_sleep.c" \
    "components/esp_driver_uart/test_apps/uart_vfs/main/test_vfs_uart.c" \
    "components/esp_hw_support/test_apps/esp_hw_support_unity_tests/main/test_dport.c" \
    "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" \
    "components/esp_system/test_apps/console/main/test_app_main.c" \
    "components/esp_system/test_apps/esp_system_unity_tests/main/test_backtrace.c" \
    "components/esp_system/test_apps/esp_system_unity_tests/main/test_sleep.c" \
    "components/hal/test_apps/tee_apm/components/pms/src/test_panic_handler.c" \
    "components/log/test_apps/main/test_log_level.c" \
    "components/log/test_apps/main/test_log_perf.c"