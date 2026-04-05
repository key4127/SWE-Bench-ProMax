#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific test files
git checkout 31602cbe66c53a4a824e43933bda2c33fb893062 "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
--- a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
+++ b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
@@ -55,7 +55,7 @@ static void i2s_test_io_config(int mode)
     gpio_set_direction(DATA_OUT_IO, GPIO_MODE_INPUT_OUTPUT);
 
     switch (mode) {
-#if SOC_I2S_NUM > 1
+#if SOC_I2S_ATTR(INST_NUM) > 1
     case I2S_TEST_MODE_SLAVE_TO_MASTER: {
         esp_rom_gpio_connect_out_signal(MASTER_BCK_IO, i2s_periph_signal[0].m_rx_bck_sig, 0, 0);
         esp_rom_gpio_connect_in_signal(MASTER_BCK_IO, i2s_periph_signal[1].s_tx_bck_sig, 0);
@@ -169,14 +169,14 @@ TEST_CASE("I2S_basic_channel_allocation_reconfig_deleting_test", "[i2s]")
 
     /* Exhaust test */
     std_cfg.gpio_cfg.mclk = -1;
-    i2s_chan_handle_t tx_ex[SOC_I2S_NUM] = {};
-    for (int i = 0; i < SOC_I2S_NUM; i++) {
+    i2s_chan_handle_t tx_ex[SOC_I2S_ATTR(INST_NUM)] = {};
+    for (int i = 0; i < SOC_I2S_ATTR(INST_NUM); i++) {
         TEST_ESP_OK(i2s_new_channel(&chan_cfg, &tx_ex[i], NULL));
         TEST_ESP_OK(i2s_channel_init_std_mode(tx_ex[i], &std_cfg));
         TEST_ESP_OK(i2s_channel_enable(tx_ex[i]));
     }
     TEST_ESP_ERR(ESP_ERR_NOT_FOUND, i2s_new_channel(&chan_cfg, &tx_handle, NULL));
-    for (int i = 0; i < SOC_I2S_NUM; i++) {
+    for (int i = 0; i < SOC_I2S_ATTR(INST_NUM); i++) {
         TEST_ESP_OK(i2s_channel_disable(tx_ex[i]));
         TEST_ESP_OK(i2s_del_channel(tx_ex[i]));
     }
@@ -741,7 +741,7 @@ TEST_CASE("I2S_loopback_test", "[i2s]")
     TEST_ESP_OK(i2s_del_channel(rx_handle));
 }
 
-#if SOC_I2S_NUM > 1 && !CONFIG_ESP32P4_SELECTS_REV_LESS_V3
+#if SOC_I2S_ATTR(INST_NUM) > 1 && !CONFIG_ESP32P4_SELECTS_REV_LESS_V3
 TEST_CASE("I2S_master_write_slave_read_test", "[i2s]")
 {
     i2s_chan_handle_t tx_handle;
@@ -856,11 +856,11 @@ static void i2s_test_common_sample_rate(i2s_chan_handle_t rx_chan, i2s_std_clk_c
     };
     int real_pulse = 0;
     int case_cnt = sizeof(test_freq) / sizeof(uint32_t);
-#if SOC_I2S_SUPPORTS_PLL_F96M
+#if I2S_LL_DEFAULT_CLK_FREQ == 96000000
     // 196000 Hz sample rate doesn't support on PLL_96M target
     case_cnt = 15;
 #endif
-#if SOC_I2S_SUPPORTS_XTAL
+#if I2S_LL_SUPPORT_XTAL
     // Can't support a very high sample rate while using XTAL as clock source
     if (clk_cfg->clk_src == I2S_CLK_SRC_XTAL) {
         case_cnt = 10;
@@ -911,7 +911,7 @@ TEST_CASE("I2S_default_PLL_clock_test", "[i2s]")
     std_cfg.clk_cfg.clk_src = I2S_LL_DEFAULT_CLK_SRC;
 #endif
     i2s_test_common_sample_rate(rx_handle, &std_cfg.clk_cfg);
-#if SOC_I2S_SUPPORTS_XTAL
+#if I2S_LL_SUPPORT_XTAL
     std_cfg.clk_cfg.clk_src = I2S_CLK_SRC_XTAL;
     i2s_test_common_sample_rate(rx_handle, &std_cfg.clk_cfg);
 #endif
diff --git a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c
--- a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c
+++ b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c
@@ -19,7 +19,7 @@
 #include "esp_private/esp_pmu.h"
 #include "../../test_inc/test_i2s.h"
 
-#define TEST_I2S_PD_SLEEP   (SOC_I2S_SUPPORT_SLEEP_RETENTION && CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP)
+#define TEST_I2S_PD_SLEEP   (SOC_MODULE_SUPPORT(I2S, SLEEP_RETENTION) && CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP)
 
 extern void i2s_read_write_test(i2s_chan_handle_t tx_chan, i2s_chan_handle_t rx_chan);
 
@@ -42,7 +42,7 @@ static void s_test_i2s_enter_light_sleep(int sec, bool allow_power_down)
     printf("Woke up from light sleep\n");
 
     TEST_ASSERT_EQUAL(0, sleep_ctx.sleep_request_result);
-#if SOC_I2S_SUPPORT_SLEEP_RETENTION && !SOC_PM_TOP_PD_NOT_ALLOWED
+#if SOC_HAS(PAU) && !SOC_PM_TOP_PD_NOT_ALLOWED
     // check if the power domain also is powered down
     TEST_ASSERT_EQUAL(allow_power_down ? PMU_SLEEP_PD_TOP : 0, (sleep_ctx.sleep_flags) & PMU_SLEEP_PD_TOP);
 #endif
EOF_114329324912

# Source ESP-IDF environment - using correct IDF_TOOLS_PATH that matches Dockerfile
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export LC_ALL=C.UTF-8
export PYTHONPATH="${IDF_PATH}/tools:${IDF_PATH}/tools/ci:${IDF_PATH}/tools/ci/python_packages:${IDF_PATH}/tools/esp_app_trace:${IDF_PATH}/components/partition_table:${PYTHONPATH}"

# Source export.sh to activate ESP-IDF environment
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== ESP-IDF I2S Driver Test Validation ==="
echo "Testing I2S driver components build and structure"

# Navigate to I2S test application directory
cd /testbed/components/esp_driver_i2s/test_apps/i2s

# Clean previous builds
echo "=== Cleaning previous builds ==="
rm -rf build sdkconfig sdkconfig.old

# Build the test application for esp32 target
echo "=== Building I2S test application for esp32 target ==="
idf.py set-target esp32
set_target_rc=$?

if [ $set_target_rc -ne 0 ]; then
    echo "ERROR: Failed to set target to esp32"
    rc=1
else
    echo "SUCCESS: Target set to esp32"
    
    # Build the test application
    idf.py build
    build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: I2S test application build failed for esp32"
        rc=1
    else
        echo "SUCCESS: I2S test application built successfully for esp32"
        
        # Verify that test binaries were generated
        if [ -f build/i2s_test.elf ]; then
            echo "SUCCESS: Test binary generated"
        else
            echo "INFO: Checking for alternative binary names"
            ls -la build/*.elf || echo "WARNING: Expected ELF file not found"
        fi
        
        # Verify the test files were compiled
        if [ -f build/esp-idf/main/libmain.a ]; then
            echo "SUCCESS: Test object files compiled"
        fi
        
        rc=0
    fi
fi

# Validate pytest test structure (collection only, no execution)
echo "=== Validating pytest test structure ==="
cd /testbed/components/esp_driver_i2s/test_apps/i2s

# Run pytest in collection-only mode to validate test structure
pytest --collect-only pytest_i2s.py
collect_rc=$?

if [ $collect_rc -eq 0 ]; then
    echo "SUCCESS: Pytest test structure is valid"
else
    echo "WARNING: Pytest collection had issues (may be expected)"
fi

# Note about hardware requirement
echo ""
echo "=== Build Verification Complete ==="
echo "NOTE: I2S tests require physical ESP32 hardware with I2S peripherals"
echo "NOTE: Tests are NOT marked with @pytest.mark.qemu - QEMU emulation not supported"
echo "NOTE: Actual test execution cannot be performed in a containerized environment"
echo "NOTE: Build success indicates that the patched code compiles correctly"

# Summary
echo "=== Test Validation Summary ==="
if [ $rc -eq 0 ]; then
    echo "SUCCESS: I2S driver build validation completed successfully"
    echo "The patched test files compile correctly and are ready for hardware testing"
else
    echo "FAILURE: I2S driver build validation failed"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 31602cbe66c53a4a824e43933bda2c33fb893062 "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c"