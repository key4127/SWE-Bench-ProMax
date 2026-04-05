#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific test files
git checkout 6c968cee04b41846b1b309902c84c38a0ae0648a "components/esp_driver_dac/test_apps/dac/main/test_dac.c" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c" "components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c"

# Apply the test patch
echo "=== Applying test patch ==="
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_dac/test_apps/dac/main/test_dac.c b/components/esp_driver_dac/test_apps/dac/main/test_dac.c
--- a/components/esp_driver_dac/test_apps/dac/main/test_dac.c
+++ b/components/esp_driver_dac/test_apps/dac/main/test_dac.c
@@ -257,7 +257,7 @@ TEST_CASE("DAC_dma_convert_frequency_test", "[dac]")
     gpio_set_direction(GPIO_NUM_4, GPIO_MODE_INPUT_OUTPUT);
     // The DAC conversion frequency is equal to I2S bclk.
     esp_rom_gpio_connect_out_signal(GPIO_NUM_4, i2s_periph_signal[0].m_tx_ws_sig, 0, 0);
-    esp_rom_gpio_connect_in_signal(GPIO_NUM_4, pcnt_periph_signals.groups[0].units[0].channels[0].pulse_sig, 0);
+    esp_rom_gpio_connect_in_signal(GPIO_NUM_4, soc_pcnt_signals[0].units[0].channels[0].pulse_sig_id_matrix, 0);
 
     size_t len = 800;
     uint8_t data[len];
diff --git a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
--- a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
+++ b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
@@ -847,7 +847,7 @@ static void i2s_test_common_sample_rate(i2s_chan_handle_t rx_chan, i2s_std_clk_c
     gpio_func_sel(MASTER_WS_IO, PIN_FUNC_GPIO);
     gpio_set_direction(MASTER_WS_IO, GPIO_MODE_INPUT_OUTPUT);
     esp_rom_gpio_connect_out_signal(MASTER_WS_IO, i2s_periph_signal[0].m_rx_ws_sig, 0, 0);
-    esp_rom_gpio_connect_in_signal(MASTER_WS_IO, pcnt_periph_signals.groups[0].units[0].channels[0].pulse_sig, 0);
+    esp_rom_gpio_connect_in_signal(MASTER_WS_IO, soc_pcnt_signals[0].units[0].channels[0].pulse_sig_id_matrix, 0);
 
     const uint32_t test_freq[] = {
         8000,  10000, 11025, 12000, 16000, 22050,
diff --git a/components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c b/components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c
--- a/components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c
+++ b/components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c
@@ -9,12 +9,13 @@
 #include "freertos/FreeRTOS.h"
 #include "freertos/task.h"
 #include "unity.h"
+#include "soc/soc_caps.h"
+#include "soc/pcnt_periph.h"
+#include "hal/pcnt_ll.h"
 #include "driver/pulse_cnt.h"
 #include "driver/gpio.h"
-#include "soc/soc_caps.h"
 #include "esp_attr.h"
 #include "test_pulse_cnt_board.h"
-#include "hal/pcnt_ll.h"
 
 TEST_CASE("pcnt_unit_install_uninstall", "[pcnt]")
 {
@@ -23,21 +24,21 @@ TEST_CASE("pcnt_unit_install_uninstall", "[pcnt]")
         .high_limit = 100,
         .intr_priority = 0,
     };
-    pcnt_unit_handle_t units[SOC_PCNT_UNITS_PER_GROUP];
+    pcnt_unit_handle_t units[SOC_PCNT_ATTR(UNITS_PER_INST)];
     int count_value = 0;
 
     printf("install pcnt units and check initial count\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP - 1; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST) - 1; i++) {
         TEST_ESP_OK(pcnt_new_unit(&unit_config, &units[i]));
         TEST_ESP_OK(pcnt_unit_get_count(units[i], &count_value));
         TEST_ASSERT_EQUAL(0, count_value);
     }
 
     // unit with a different interrupt priority
     unit_config.intr_priority = 3;
-    TEST_ESP_ERR(ESP_ERR_INVALID_STATE, pcnt_new_unit(&unit_config, &units[SOC_PCNT_UNITS_PER_GROUP - 1]));
+    TEST_ESP_ERR(ESP_ERR_INVALID_STATE, pcnt_new_unit(&unit_config, &units[SOC_PCNT_ATTR(UNITS_PER_INST) - 1]));
     unit_config.intr_priority = 0;
-    TEST_ESP_OK(pcnt_new_unit(&unit_config, &units[SOC_PCNT_UNITS_PER_GROUP - 1]));
+    TEST_ESP_OK(pcnt_new_unit(&unit_config, &units[SOC_PCNT_ATTR(UNITS_PER_INST) - 1]));
 
     // no more free pcnt units
     TEST_ASSERT_EQUAL(ESP_ERR_NOT_FOUND, pcnt_new_unit(&unit_config, &units[0]));
@@ -46,7 +47,7 @@ TEST_CASE("pcnt_unit_install_uninstall", "[pcnt]")
     pcnt_glitch_filter_config_t filter_config = {
         .max_glitch_ns = 1000,
     };
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_set_glitch_filter(units[i], &filter_config));
     }
     // invalid glitch configuration
@@ -56,30 +57,30 @@ TEST_CASE("pcnt_unit_install_uninstall", "[pcnt]")
         .on_reach = NULL,
     };
     printf("enable pcnt units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_register_event_callbacks(units[i], &cbs, NULL));
         TEST_ESP_OK(pcnt_unit_enable(units[i]));
     }
 
     printf("start pcnt units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_start(units[i]));
     }
 
     printf("stop pcnt units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_stop(units[i]));
     }
 
     // can't uninstall unit before disable it
     TEST_ASSERT_EQUAL(ESP_ERR_INVALID_STATE, pcnt_del_unit(units[0]));
     printf("disable pcnt units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_disable(units[i]));
     }
 
     printf("uninstall pcnt units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_del_unit(units[i]));
     }
 }
@@ -96,17 +97,17 @@ TEST_CASE("pcnt_channel_install_uninstall", "[pcnt]")
         .edge_gpio_num = TEST_PCNT_GPIO_A, // only detect edge signal in this case
         .level_gpio_num = -1,
     };
-    pcnt_unit_handle_t units[SOC_PCNT_UNITS_PER_GROUP];
-    pcnt_channel_handle_t chans[SOC_PCNT_UNITS_PER_GROUP][SOC_PCNT_CHANNELS_PER_UNIT];
+    pcnt_unit_handle_t units[SOC_PCNT_ATTR(UNITS_PER_INST)];
+    pcnt_channel_handle_t chans[SOC_PCNT_ATTR(UNITS_PER_INST)][SOC_PCNT_ATTR(CHANS_PER_UNIT)];
 
     printf("install pcnt units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_new_unit(&unit_config, &units[i]));
     }
 
     printf("install pcnt channels\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
-        for (int j = 0; j < SOC_PCNT_CHANNELS_PER_UNIT; j++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
+        for (int j = 0; j < SOC_PCNT_ATTR(CHANS_PER_UNIT); j++) {
             TEST_ESP_OK(pcnt_new_channel(units[i], &chan_config, &chans[i][j]));
             TEST_ESP_OK(pcnt_channel_set_edge_action(chans[i][j], PCNT_CHANNEL_EDGE_ACTION_INCREASE, PCNT_CHANNEL_EDGE_ACTION_HOLD));
             TEST_ESP_OK(pcnt_channel_set_level_action(chans[i][j], PCNT_CHANNEL_LEVEL_ACTION_KEEP, PCNT_CHANNEL_LEVEL_ACTION_KEEP));
@@ -117,55 +118,55 @@ TEST_CASE("pcnt_channel_install_uninstall", "[pcnt]")
 
     printf("start units\r\n");
     int count_value = 0;
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         // start unit
         TEST_ESP_OK(pcnt_unit_start(units[i]));
         // trigger 10 rising edge on GPIO0
         test_gpio_simulate_rising_edge(TEST_PCNT_GPIO_A, 10);
         TEST_ESP_OK(pcnt_unit_get_count(units[i], &count_value));
         // each channel increases to the same unit counter
-        TEST_ASSERT_EQUAL(10 * SOC_PCNT_CHANNELS_PER_UNIT, count_value);
+        TEST_ASSERT_EQUAL(10 * SOC_PCNT_ATTR(CHANS_PER_UNIT), count_value);
     }
 
     printf("clear counts\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_clear_count(units[i]));
         TEST_ESP_OK(pcnt_unit_get_count(units[i], &count_value));
         TEST_ASSERT_EQUAL(0, count_value);
     }
 
     printf("stop unit\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         // stop unit
         TEST_ESP_OK(pcnt_unit_stop(units[i]));
     }
 
     // trigger 10 rising edge on GPIO0 shouldn't increase the counter
     test_gpio_simulate_rising_edge(TEST_PCNT_GPIO_A, 10);
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         TEST_ESP_OK(pcnt_unit_get_count(units[i], &count_value));
         TEST_ASSERT_EQUAL(0, count_value);
     }
 
     printf("restart units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         // start unit
         TEST_ESP_OK(pcnt_unit_start(units[i]));
         // trigger 10 rising edge on GPIO
         test_gpio_simulate_rising_edge(TEST_PCNT_GPIO_A, 10);
         TEST_ESP_OK(pcnt_unit_get_count(units[i], &count_value));
         // each channel increases to the same unit counter
-        TEST_ASSERT_EQUAL(10 * SOC_PCNT_CHANNELS_PER_UNIT, count_value);
+        TEST_ASSERT_EQUAL(10 * SOC_PCNT_ATTR(CHANS_PER_UNIT), count_value);
     }
 
     printf("uninstall channels and units\r\n");
-    for (int i = 0; i < SOC_PCNT_UNITS_PER_GROUP; i++) {
+    for (int i = 0; i < SOC_PCNT_ATTR(UNITS_PER_INST); i++) {
         // stop unit
         TEST_ESP_OK(pcnt_unit_stop(units[i]));
         TEST_ESP_OK(pcnt_unit_disable(units[i]));
         // can't uninstall unit when channel is still alive
         TEST_ASSERT_EQUAL(ESP_ERR_INVALID_STATE, pcnt_del_unit(units[i]));
-        for (int j = 0; j < SOC_PCNT_CHANNELS_PER_UNIT; j++) {
+        for (int j = 0; j < SOC_PCNT_ATTR(CHANS_PER_UNIT); j++) {
             TEST_ESP_OK(pcnt_del_channel(chans[i][j]));
         }
         TEST_ESP_OK(pcnt_del_unit(units[i]));
EOF_114329324912

# Verify patch application
echo "=== Verifying patch was applied correctly ==="
for file in "components/esp_driver_dac/test_apps/dac/main/test_dac.c" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c" "components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c"; do
    if [ -f /testbed/$file ]; then
        echo "SUCCESS: $file exists"
    else
        echo "ERROR: $file not found"
        exit 1
    fi
done

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CI_BUILD=1
export PYTHONPATH=${IDF_PATH}/tools:${IDF_PATH}/tools/ci:${IDF_PATH}/tools/esp_app_trace:${IDF_PATH}/components/partition_table:${IDF_PATH}/tools/ci/python_packages
source /testbed/export.sh

# Initialize return code
rc=0

# Test 1: Build DAC test application (ESP32 target)
echo "=== Building DAC test application ==="
cd /testbed/components/esp_driver_dac/test_apps/dac
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
dac_rc=$?

if [ $dac_rc -ne 0 ]; then
    echo "ERROR: DAC build failed with exit code $dac_rc"
    rc=1
else
    echo "SUCCESS: DAC test application built successfully"
    if [ -f build/*.elf ]; then
        ls -lh build/*.elf | head -3
    fi
fi

# Test 2: Build I2S test application (ESP32 target)
echo "=== Building I2S test application ==="
cd /testbed/components/esp_driver_i2s/test_apps/i2s
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
i2s_rc=$?

if [ $i2s_rc -ne 0 ]; then
    echo "ERROR: I2S build failed with exit code $i2s_rc"
    rc=1
else
    echo "SUCCESS: I2S test application built successfully"
    if [ -f build/*.elf ]; then
        ls -lh build/*.elf | head -3
    fi
fi

# Test 3: Build Pulse Counter test application (ESP32 target)
echo "=== Building Pulse Counter test application ==="
cd /testbed/components/esp_driver_pcnt/test_apps/pulse_cnt
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
pcnt_rc=$?

if [ $pcnt_rc -ne 0 ]; then
    echo "ERROR: Pulse Counter build failed with exit code $pcnt_rc"
    rc=1
else
    echo "SUCCESS: Pulse Counter test application built successfully"
    if [ -f build/*.elf ]; then
        ls -lh build/*.elf | head -3
    fi
fi

# Determine overall exit code
echo ""
echo "========================================"
echo "=== Build Summary ==="
echo "========================================"
echo "DAC build: $([ $dac_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
echo "I2S build: $([ $i2s_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
echo "Pulse Counter build: $([ $pcnt_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"

if [ $dac_rc -eq 0 ] && [ $i2s_rc -eq 0 ] && [ $pcnt_rc -eq 0 ]; then
    echo "=== All test applications built successfully ==="
    echo "=== Build verification confirms patches are valid ==="
    rc=0
else
    echo "=== One or more test applications failed to build ==="
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 6c968cee04b41846b1b309902c84c38a0ae0648a "components/esp_driver_dac/test_apps/dac/main/test_dac.c" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c" "components/esp_driver_pcnt/test_apps/pulse_cnt/main/test_pulse_cnt.c"

# Clean up build artifacts
rm -rf /testbed/components/esp_driver_dac/test_apps/dac/build
rm -rf /testbed/components/esp_driver_dac/test_apps/dac/sdkconfig*
rm -rf /testbed/components/esp_driver_i2s/test_apps/i2s/build
rm -rf /testbed/components/esp_driver_i2s/test_apps/i2s/sdkconfig*
rm -rf /testbed/components/esp_driver_pcnt/test_apps/pulse_cnt/build
rm -rf /testbed/components/esp_driver_pcnt/test_apps/pulse_cnt/sdkconfig*

exit $rc