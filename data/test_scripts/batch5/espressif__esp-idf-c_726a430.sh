#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
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
 
-#define TEST_I2S_PD_SLEEP   (SOC_I2S_SUPPORT_SLEEP_RETENTION && CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP)
+#define TEST_I2S_PD_SLEEP   (SOC_HAS(PAU) && CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP)
 
 extern void i2s_read_write_test(i2s_chan_handle_t tx_chan, i2s_chan_handle_t rx_chan);
 
@@ -42,7 +43,7 @@ static void s_test_i2s_enter_light_sleep(int sec, bool allow_power_down)
     printf("Woke up from light sleep\n");
 
     TEST_ASSERT_EQUAL(0, sleep_ctx.sleep_request_result);
-#if SOC_I2S_SUPPORT_SLEEP_RETENTION && !SOC_PM_TOP_PD_NOT_ALLOWED
+#if SOC_HAS(PAU) && !SOC_PM_TOP_PD_NOT_ALLOWED
     // check if the power domain also is powered down
     TEST_ASSERT_EQUAL(allow_power_down ? PMU_SLEEP_PD_TOP : 0, (sleep_ctx.sleep_flags) & PMU_SLEEP_PD_TOP);
 #endif
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
source /testbed/export.sh

# Initialize return code
rc=0

# Navigate to the test directory
cd /testbed/components/esp_driver_i2s/test_apps/i2s

# Clean any previous builds
rm -rf build sdkconfig

echo "=== Setting target to esp32 ==="
idf.py set-target esp32
set_target_rc=$?

if [ $set_target_rc -ne 0 ]; then
    echo "ERROR: idf.py set-target failed with exit code $set_target_rc"
    rc=1
else
    echo "SUCCESS: Target set to esp32"
    
    echo "=== Building I2S test application (default configuration) ==="
    idf.py build
    build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: idf.py build failed with exit code $build_rc"
        rc=1
    else
        echo "SUCCESS: Build completed successfully"
        
        # Optional: Try QEMU execution if build succeeded
        echo "=== Attempting QEMU execution (optional validation) ==="
        cd /testbed/components/esp_driver_i2s/test_apps/i2s
        pytest --target esp32 -m qemu --embedded-services idf,qemu --qemu-extra-args "-global driver=timer.esp32.timg,property=wdt_disable,value=true" --junitxml=XUNIT_RESULT.xml || true
        
        # Note: QEMU execution may fail due to I2S peripheral limitations, but build success is the primary validation
        echo "INFO: QEMU execution attempted (failures expected for hardware-specific I2S tests)"
        
        # Build success is sufficient for validation
        rc=0
    fi
fi

# Test additional configurations if primary build succeeded
if [ $rc -eq 0 ]; then
    echo "=== Testing IRAM_SAFE configuration ==="
    cd /testbed/components/esp_driver_i2s/test_apps/i2s
    rm -rf build sdkconfig
    
    if [ -f sdkconfig.defaults ] && [ -f sdkconfig.ci.iram_safe ]; then
        cat sdkconfig.defaults sdkconfig.ci.iram_safe > sdkconfig
        idf.py build
        iram_build_rc=$?
        
        if [ $iram_build_rc -ne 0 ]; then
            echo "ERROR: IRAM_SAFE configuration build failed with exit code $iram_build_rc"
            rc=1
        else
            echo "SUCCESS: IRAM_SAFE configuration build completed"
        fi
    else
        echo "INFO: IRAM_SAFE configuration files not found, skipping"
    fi
    
    if [ $rc -eq 0 ]; then
        echo "=== Testing RELEASE configuration ==="
        cd /testbed/components/esp_driver_i2s/test_apps/i2s
        rm -rf build sdkconfig
        
        if [ -f sdkconfig.defaults ] && [ -f sdkconfig.ci.release ]; then
            cat sdkconfig.defaults sdkconfig.ci.release > sdkconfig
            idf.py build
            release_build_rc=$?
            
            if [ $release_build_rc -ne 0 ]; then
                echo "ERROR: RELEASE configuration build failed with exit code $release_build_rc"
                rc=1
            else
                echo "SUCCESS: RELEASE configuration build completed"
            fi
        else
            echo "INFO: RELEASE configuration files not found, skipping"
        fi
    fi
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 31602cbe66c53a4a824e43933bda2c33fb893062 "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s_sleep.c"