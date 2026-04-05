#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 6bd8b52ad765674387b209693cb9aaa80d401057 "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" "components/esp_timer/test_apps/main/test_esp_timer_dfs.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c b/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
--- a/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
+++ b/components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c
@@ -31,7 +31,7 @@
 
 #define CALIBRATE_ONE(cali_clk) calibrate_one(cali_clk, #cali_clk)
 
-static uint32_t calibrate_one(rtc_cal_sel_t cal_clk, const char* name)
+static uint32_t calibrate_one(soc_clk_freq_calculation_src_t cal_clk, const char* name)
 {
     const uint32_t cal_count = 1000;
     const float factor = (1 << 19) * 1000.0f;
@@ -54,25 +54,25 @@ TEST_CASE("RTC_SLOW_CLK sources calibration", "[rtc_clk]")
 
     // By default Kconfig, RTC_SLOW_CLK source is RC_SLOW
     soc_rtc_slow_clk_src_t default_rtc_slow_clk_src = rtc_clk_slow_src_get();
-    CALIBRATE_ONE(RTC_CAL_RTC_MUX);
+    CALIBRATE_ONE(CLK_CAL_RTC_SLOW);
 #if SOC_CLK_RC_FAST_D256_SUPPORTED
-    CALIBRATE_ONE(RTC_CAL_8MD256);
+    CALIBRATE_ONE(CLK_CAL_RC_FAST_D256);
 #endif
 
 #if SOC_CLK_XTAL32K_SUPPORTED
-    uint32_t cal_32k = CALIBRATE_ONE(RTC_CAL_32K_XTAL);
+    uint32_t cal_32k = CALIBRATE_ONE(CLK_CAL_32K_XTAL);
     if (cal_32k == 0) {
         printf("32K XTAL OSC has not started up\n");
     } else {
         printf("switching to SOC_RTC_SLOW_CLK_SRC_XTAL32K: ");
         rtc_clk_slow_src_set(SOC_RTC_SLOW_CLK_SRC_XTAL32K);
         printf("done\n");
 
-        CALIBRATE_ONE(RTC_CAL_RTC_MUX);
+        CALIBRATE_ONE(CLK_CAL_RTC_SLOW);
 #if SOC_CLK_RC_FAST_D256_SUPPORTED
-        CALIBRATE_ONE(RTC_CAL_8MD256);
+        CALIBRATE_ONE(CLK_CAL_RC_FAST_D256);
 #endif
-        CALIBRATE_ONE(RTC_CAL_32K_XTAL);
+        CALIBRATE_ONE(CLK_CAL_32K_XTAL);
     }
 #endif
 
@@ -81,28 +81,28 @@ TEST_CASE("RTC_SLOW_CLK sources calibration", "[rtc_clk]")
     rtc_clk_slow_src_set(SOC_RTC_SLOW_CLK_SRC_RC_FAST_D256);
     printf("done\n");
 
-    CALIBRATE_ONE(RTC_CAL_RTC_MUX);
-    CALIBRATE_ONE(RTC_CAL_8MD256);
+    CALIBRATE_ONE(CLK_CAL_RTC_SLOW);
+    CALIBRATE_ONE(CLK_CAL_RC_FAST_D256);
 #if SOC_CLK_XTAL32K_SUPPORTED
-    CALIBRATE_ONE(RTC_CAL_32K_XTAL);
+    CALIBRATE_ONE(CLK_CAL_32K_XTAL);
 #endif
 #endif
 
 #if SOC_CLK_OSC_SLOW_SUPPORTED
     rtc_clk_32k_enable_external();
-    uint32_t cal_ext_slow_clk = CALIBRATE_ONE(RTC_CAL_32K_OSC_SLOW);
+    uint32_t cal_ext_slow_clk = CALIBRATE_ONE(CLK_CAL_32K_OSC_SLOW);
     if (cal_ext_slow_clk == 0) {
         printf("EXT CLOCK by PIN has not started up\n");
     } else {
         printf("switching to SOC_RTC_SLOW_CLK_SRC_OSC_SLOW: ");
         rtc_clk_slow_src_set(SOC_RTC_SLOW_CLK_SRC_OSC_SLOW);
         printf("done\n");
 
-        CALIBRATE_ONE(RTC_CAL_RTC_MUX);
+        CALIBRATE_ONE(CLK_CAL_RTC_SLOW);
 #if SOC_CLK_RC_FAST_D256_SUPPORTED
-        CALIBRATE_ONE(RTC_CAL_8MD256);
+        CALIBRATE_ONE(CLK_CAL_RC_FAST_D256);
 #endif
-        CALIBRATE_ONE(RTC_CAL_32K_OSC_SLOW);
+        CALIBRATE_ONE(CLK_CAL_32K_OSC_SLOW);
     }
 #endif
 
diff --git a/components/esp_timer/test_apps/main/test_esp_timer_dfs.c b/components/esp_timer/test_apps/main/test_esp_timer_dfs.c
--- a/components/esp_timer/test_apps/main/test_esp_timer_dfs.c
+++ b/components/esp_timer/test_apps/main/test_esp_timer_dfs.c
@@ -109,7 +109,7 @@ static int64_t test_periodic_timer_accuracy_on_dfs(esp_timer_handle_t timer)
 {
     // Calibrate slow clock.
 #if !CONFIG_ESP_SYSTEM_RTC_EXT_XTAL
-    esp_clk_slowclk_cal_set(rtc_clk_cal(RTC_CAL_RTC_MUX, 8192));
+    esp_clk_slowclk_cal_set(rtc_clk_cal(CLK_CAL_RTC_SLOW, 8192));
 #endif
 
     ESP_ERROR_CHECK(esp_timer_start_periodic(timer, ALARM_PERIOD_MS * 1000));
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== Building and Testing RTC Clock and ESP Timer Applications ==="

# Test 1: Build and test rtc_clk test application
echo "=== Test 1: Building rtc_clk test application (esp32) ==="
cd /testbed/components/esp_hw_support/test_apps/rtc_clk
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
rtc_clk_build_rc=$?

if [ $rtc_clk_build_rc -ne 0 ]; then
    echo "ERROR: rtc_clk test application build failed for esp32"
    rc=1
else
    echo "SUCCESS: rtc_clk test application built successfully for esp32"
    
    # Attempt to run pytest (will fail gracefully without hardware, but validates test infrastructure)
    echo "=== Attempting to run rtc_clk tests via pytest ==="
    if [ -f "pytest_rtc_clk.py" ]; then
        echo "Found pytest_rtc_clk.py, attempting test execution"
        
        # Try to collect tests
        pytest --collect-only pytest_rtc_clk.py --target=esp32 2>&1 | tee pytest_rtc_clk_collect.log || true
        
        # Try to run with timeout (will fail due to no hardware but validates configuration)
        timeout 30 pytest pytest_rtc_clk.py --target=esp32 -v 2>&1 | tee pytest_rtc_clk_run.log || rtc_clk_pytest_rc=$?
        
        # Check if tests were properly configured
        if grep -q "test_" pytest_rtc_clk_collect.log || grep -q "test_" pytest_rtc_clk_run.log; then
            echo "INFO: rtc_clk tests properly configured in pytest"
        fi
        
        # Check for expected hardware-related failures
        if grep -q "No device" pytest_rtc_clk_run.log || grep -q "serial port" pytest_rtc_clk_run.log || grep -q "SKIPPED" pytest_rtc_clk_run.log; then
            echo "INFO: pytest correctly detected missing hardware for rtc_clk tests"
        fi
    else
        echo "INFO: pytest_rtc_clk.py not found, build validation only"
    fi
fi

# Test 2: Build and test esp_timer test application
echo "=== Test 2: Building esp_timer test application (esp32) ==="
cd /testbed/components/esp_timer/test_apps
rm -rf build sdkconfig
idf.py set-target esp32
idf.py build
esp_timer_build_rc=$?

if [ $esp_timer_build_rc -ne 0 ]; then
    echo "ERROR: esp_timer test application build failed for esp32"
    rc=1
else
    echo "SUCCESS: esp_timer test application built successfully for esp32"
    
    # Attempt to run pytest (will fail gracefully without hardware, but validates test infrastructure)
    echo "=== Attempting to run esp_timer tests via pytest ==="
    if [ -f "pytest_esp_timer.py" ]; then
        echo "Found pytest_esp_timer.py, attempting test execution"
        
        # Try to collect tests
        pytest --collect-only pytest_esp_timer.py --target=esp32 2>&1 | tee pytest_esp_timer_collect.log || true
        
        # Try to run with timeout (will fail due to no hardware but validates configuration)
        timeout 30 pytest pytest_esp_timer.py --target=esp32 -v 2>&1 | tee pytest_esp_timer_run.log || esp_timer_pytest_rc=$?
        
        # Check if tests were properly configured
        if grep -q "test_" pytest_esp_timer_collect.log || grep -q "test_" pytest_esp_timer_run.log; then
            echo "INFO: esp_timer tests properly configured in pytest"
        fi
        
        # Check for expected hardware-related failures
        if grep -q "No device" pytest_esp_timer_run.log || grep -q "serial port" pytest_esp_timer_run.log || grep -q "SKIPPED" pytest_esp_timer_run.log; then
            echo "INFO: pytest correctly detected missing hardware for esp_timer tests"
        fi
    else
        echo "INFO: pytest_esp_timer.py not found, build validation only"
    fi
fi

# Validate that test files were compiled
echo "=== Validating test files were compiled ==="
if [ -f "/testbed/components/esp_hw_support/test_apps/rtc_clk/build/rtc_clk.elf" ] || [ -f "/testbed/components/esp_hw_support/test_apps/rtc_clk/build/rtc_clk_test.elf" ]; then
    echo "SUCCESS: rtc_clk test binary created"
else
    echo "INFO: Checking for alternative rtc_clk binary locations"
    find /testbed/components/esp_hw_support/test_apps/rtc_clk/build -name "*.elf" 2>/dev/null | head -5 || true
fi

if [ -f "/testbed/components/esp_timer/test_apps/build/esp_timer_test.elf" ] || [ -f "/testbed/components/esp_timer/test_apps/build/esp_timer.elf" ]; then
    echo "SUCCESS: esp_timer test binary created"
else
    echo "INFO: Checking for alternative esp_timer binary locations"
    find /testbed/components/esp_timer/test_apps/build -name "*.elf" 2>/dev/null | head -5 || true
fi

# Determine overall exit code
if [ $rtc_clk_build_rc -eq 0 ] && [ $esp_timer_build_rc -eq 0 ]; then
    echo "=== All test applications built successfully ==="
    echo "=== Build verification confirms patches are valid ==="
    echo "=== Note: Actual test execution requires physical ESP32 hardware ==="
    rc=0
else
    echo "=== One or more test applications failed to build ==="
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 6bd8b52ad765674387b209693cb9aaa80d401057 "components/esp_hw_support/test_apps/rtc_clk/main/test_rtc_clk.c" "components/esp_timer/test_apps/main/test_esp_timer_dfs.c"