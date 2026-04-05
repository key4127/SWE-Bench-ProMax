#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e8f39b4c8d32d20829df7ff07f3d2dd5ca9ead31 "components/esp_driver_dac/test_apps/dac/main/CMakeLists.txt" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_dac/test_apps/dac/main/CMakeLists.txt b/components/esp_driver_dac/test_apps/dac/main/CMakeLists.txt
--- a/components/esp_driver_dac/test_apps/dac/main/CMakeLists.txt
+++ b/components/esp_driver_dac/test_apps/dac/main/CMakeLists.txt
@@ -8,6 +8,6 @@ endif()
 # In order for the cases defined by `TEST_CASE` to be linked into the final elf,
 # the component can be registered as WHOLE_ARCHIVE
 idf_component_register(SRCS ${srcs}
-                       PRIV_REQUIRES unity esp_driver_pcnt esp_adc esp_hal_i2s
+                       PRIV_REQUIRES unity esp_driver_pcnt esp_adc
                                      esp_driver_dac esp_driver_gpio esp_driver_i2s esp_driver_spi
                        WHOLE_ARCHIVE)
diff --git a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
--- a/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
+++ b/components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c
@@ -55,7 +55,7 @@ static void i2s_test_io_config(int mode)
     gpio_set_direction(DATA_OUT_IO, GPIO_MODE_INPUT_OUTPUT);
 
     switch (mode) {
-#if SOC_I2S_ATTR(INST_NUM) > 1
+#if I2S_LL_GET(INST_NUM) > 1
     case I2S_TEST_MODE_SLAVE_TO_MASTER: {
         esp_rom_gpio_connect_out_signal(MASTER_BCK_IO, i2s_periph_signal[0].m_rx_bck_sig, 0, 0);
         esp_rom_gpio_connect_in_signal(MASTER_BCK_IO, i2s_periph_signal[1].s_tx_bck_sig, 0);
@@ -169,14 +169,14 @@ TEST_CASE("I2S_basic_channel_allocation_reconfig_deleting_test", "[i2s]")
 
     /* Exhaust test */
     std_cfg.gpio_cfg.mclk = -1;
-    i2s_chan_handle_t tx_ex[SOC_I2S_ATTR(INST_NUM)] = {};
-    for (int i = 0; i < SOC_I2S_ATTR(INST_NUM); i++) {
+    i2s_chan_handle_t tx_ex[I2S_LL_GET(INST_NUM)] = {};
+    for (int i = 0; i < I2S_LL_GET(INST_NUM); i++) {
         TEST_ESP_OK(i2s_new_channel(&chan_cfg, &tx_ex[i], NULL));
         TEST_ESP_OK(i2s_channel_init_std_mode(tx_ex[i], &std_cfg));
         TEST_ESP_OK(i2s_channel_enable(tx_ex[i]));
     }
     TEST_ESP_ERR(ESP_ERR_NOT_FOUND, i2s_new_channel(&chan_cfg, &tx_handle, NULL));
-    for (int i = 0; i < SOC_I2S_ATTR(INST_NUM); i++) {
+    for (int i = 0; i < I2S_LL_GET(INST_NUM); i++) {
         TEST_ESP_OK(i2s_channel_disable(tx_ex[i]));
         TEST_ESP_OK(i2s_del_channel(tx_ex[i]));
     }
@@ -741,7 +741,7 @@ TEST_CASE("I2S_loopback_test", "[i2s]")
     TEST_ESP_OK(i2s_del_channel(rx_handle));
 }
 
-#if SOC_I2S_ATTR(INST_NUM) > 1 && !CONFIG_ESP32P4_SELECTS_REV_LESS_V3
+#if I2S_LL_GET(INST_NUM) > 1 && !CONFIG_ESP32P4_SELECTS_REV_LESS_V3
 TEST_CASE("I2S_master_write_slave_read_test", "[i2s]")
 {
     i2s_chan_handle_t tx_handle;
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up tools)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export CI_PIPELINE_ID=test-pipeline
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export IDF_SKIP_CHECK_SUBMODULES=1

# Initialize return code
rc=0

# Test 1: Build esp_driver_dac test app for esp32
echo "=== Testing esp_driver_dac test app for esp32 ==="
cd /testbed/components/esp_driver_dac/test_apps/dac
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: esp_driver_dac test app build failed for esp32"
fi

# Test 2: Build esp_driver_dac test app for esp32s2
echo "=== Testing esp_driver_dac test app for esp32s2 ==="
cd /testbed/components/esp_driver_dac/test_apps/dac
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32s2
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: esp_driver_dac test app build failed for esp32s2"
fi

# Test 3: Build esp_driver_i2s test app for esp32
echo "=== Testing esp_driver_i2s test app for esp32 ==="
cd /testbed/components/esp_driver_i2s/test_apps/i2s
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: esp_driver_i2s test app build failed for esp32"
fi

# Test 4: Build esp_driver_i2s test app for esp32s2
echo "=== Testing esp_driver_i2s test app for esp32s2 ==="
cd /testbed/components/esp_driver_i2s/test_apps/i2s
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32s2
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: esp_driver_i2s test app build failed for esp32s2"
fi

# Test 5: Build esp_driver_i2s test app for esp32c3
echo "=== Testing esp_driver_i2s test app for esp32c3 ==="
cd /testbed/components/esp_driver_i2s/test_apps/i2s
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32c3
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: esp_driver_i2s test app build failed for esp32c3"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout e8f39b4c8d32d20829df7ff07f3d2dd5ca9ead31 "components/esp_driver_dac/test_apps/dac/main/CMakeLists.txt" "components/esp_driver_i2s/test_apps/i2s/main/test_i2s.c"