#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout e50f12974d56a757e602a1665f47eb99febbec56 "components/esp_driver_parlio/test_apps/parlio/CMakeLists.txt" "components/esp_driver_parlio/test_apps/parlio/main/CMakeLists.txt" "components/esp_driver_parlio/test_apps/parlio/main/test_parlio_bitscrambler.c" "components/esp_driver_parlio/test_apps/parlio/main/test_parlio_rx.c" "components/esp_driver_parlio/test_apps/parlio/main/test_parlio_tx.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_parlio/test_apps/parlio/CMakeLists.txt b/components/esp_driver_parlio/test_apps/parlio/CMakeLists.txt
--- a/components/esp_driver_parlio/test_apps/parlio/CMakeLists.txt
+++ b/components/esp_driver_parlio/test_apps/parlio/CMakeLists.txt
@@ -9,16 +9,17 @@ project(parlio_test)
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
-    add_custom_target(check_test_app_sections ALL
-                      COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                      --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_parlio/,${CMAKE_BINARY_DIR}/esp-idf/hal/
-                      --elf-file ${CMAKE_BINARY_DIR}/parlio_test.elf
-                      find-refs
-                      --from-sections=.iram0.text
-                      --to-sections=.flash.text,.flash.rodata
-                      --exit-code
-                      DEPENDS ${elf}
-                      )
+    add_custom_target(
+        check_test_app_sections ALL
+        COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
+        --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_parlio/,${CMAKE_BINARY_DIR}/esp-idf/esp_hal_parlio/
+        --elf-file ${CMAKE_BINARY_DIR}/parlio_test.elf
+        find-refs
+        --from-sections=.iram0.text
+        --to-sections=.flash.text,.flash.rodata
+        --exit-code
+        DEPENDS ${elf}
+    )
 endif()
 
 message(STATUS "Checking parlio registers are not read-write by half-word")
diff --git a/components/esp_driver_parlio/test_apps/parlio/main/CMakeLists.txt b/components/esp_driver_parlio/test_apps/parlio/main/CMakeLists.txt
--- a/components/esp_driver_parlio/test_apps/parlio/main/CMakeLists.txt
+++ b/components/esp_driver_parlio/test_apps/parlio/main/CMakeLists.txt
@@ -19,7 +19,7 @@ endif()
 idf_component_register(SRCS ${srcs}
                        PRIV_REQUIRES unity esp_driver_parlio esp_driver_gpio
                                     esp_driver_i2s esp_driver_spi esp_psram
-                                    esp_driver_bitscrambler
+                                    esp_driver_bitscrambler esp_hal_parlio
                        WHOLE_ARCHIVE)
 
 if(CONFIG_SOC_BITSCRAMBLER_SUPPORTED)
diff --git a/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_bitscrambler.c b/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_bitscrambler.c
--- a/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_bitscrambler.c
+++ b/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_bitscrambler.c
@@ -202,7 +202,7 @@ TEST_CASE("parlio_tx_bitscrambler_test", "[parlio_bitscrambler]")
     test_parlio_bitscrambler();
 }
 
-#if SOC_PARLIO_TX_SUPPORT_EOF_FROM_DMA
+#if PARLIO_LL_SUPPORT(TX_EOF_FROM_DMA)
 static void test_parlio_bitscrambler_different_input_output_sizes(void)
 {
     parlio_tx_unit_handle_t tx_unit = NULL;
@@ -353,4 +353,4 @@ TEST_CASE("parlio_tx_bitscrambler_different_input_output_sizes_test", "[parlio_b
 {
     test_parlio_bitscrambler_different_input_output_sizes();
 }
-#endif // SOC_PARLIO_TX_SUPPORT_EOF_FROM_DMA
+#endif // PARLIO_LL_SUPPORT(TX_EOF_FROM_DMA)
diff --git a/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_rx.c b/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_rx.c
--- a/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_rx.c
+++ b/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_rx.c
@@ -20,7 +20,8 @@
 #include "hal/cache_ll.h"
 #include "soc/soc_caps.h"
 #include "soc/spi_periph.h"
-#include "soc/parlio_periph.h"
+#include "hal/parlio_periph.h"
+#include "hal/parlio_ll.h"
 #include "esp_attr.h"
 #include "test_board.h"
 #include "esp_private/parlio_rx_private.h"
@@ -29,7 +30,7 @@
 #define TEST_I2S_PORT   I2S_NUM_0
 #define TEST_VALID_SIG  (PARLIO_RX_UNIT_MAX_DATA_WIDTH - 1)
 
-#if SOC_PARLIO_RX_CLK_SUPPORT_OUTPUT
+#if PARLIO_LL_SUPPORT(RX_CLK_OUTPUT)
 #define TEST_OUTPUT_CLK_PIN     TEST_CLK_GPIO
 #else
 #define TEST_OUTPUT_CLK_PIN     -1
@@ -399,11 +400,11 @@ TEST_CASE("parallel_rx_unit_pulse_delimiter_test_via_i2s", "[parlio_rx]")
 TEST_CASE("parallel_rx_unit_install_uninstall", "[parlio_rx]")
 {
     printf("install rx units exhaustively\r\n");
-    parlio_rx_unit_handle_t units[SOC_PARLIO_GROUPS * SOC_PARLIO_RX_UNITS_PER_GROUP];
+    parlio_rx_unit_handle_t units[PARLIO_LL_GET(INST_NUM) * PARLIO_LL_GET(RX_UNITS_PER_INST)];
     int k = 0;
     parlio_rx_unit_config_t config = TEST_DEFAULT_UNIT_CONFIG(PARLIO_CLK_SRC_DEFAULT, 1000000);
-    for (int i = 0; i < SOC_PARLIO_GROUPS; i++) {
-        for (int j = 0; j < SOC_PARLIO_RX_UNITS_PER_GROUP; j++) {
+    for (int i = 0; i < PARLIO_LL_GET(INST_NUM); i++) {
+        for (int j = 0; j < PARLIO_LL_GET(RX_UNITS_PER_INST); j++) {
             TEST_ESP_OK(parlio_new_rx_unit(&config, &units[k++]));
         }
     }
@@ -421,7 +422,7 @@ TEST_CASE("parallel_rx_unit_install_uninstall", "[parlio_rx]")
     // clock from internal
     config.clk_src = PARLIO_CLK_SRC_DEFAULT;
     config.clk_out_gpio_num = TEST_CLK_GPIO;
-#if SOC_PARLIO_RX_CLK_SUPPORT_OUTPUT
+#if PARLIO_LL_SUPPORT(RX_CLK_OUTPUT)
     TEST_ESP_OK(parlio_new_rx_unit(&config, &units[0]));
     TEST_ESP_OK(parlio_del_rx_unit(units[0]));
 #else
diff --git a/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_tx.c b/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_tx.c
--- a/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_tx.c
+++ b/components/esp_driver_parlio/test_apps/parlio/main/test_parlio_tx.c
@@ -19,7 +19,7 @@
 TEST_CASE("parallel_tx_unit_install_uninstall", "[parlio_tx]")
 {
     printf("install tx units exhaustively\r\n");
-    parlio_tx_unit_handle_t units[SOC_PARLIO_GROUPS * SOC_PARLIO_TX_UNITS_PER_GROUP];
+    parlio_tx_unit_handle_t units[PARLIO_LL_GET(INST_NUM) * PARLIO_LL_GET(TX_UNITS_PER_INST)];
     int k = 0;
     parlio_tx_unit_config_t config = {
         .clk_src = PARLIO_CLK_SRC_DEFAULT,
@@ -31,8 +31,8 @@ TEST_CASE("parallel_tx_unit_install_uninstall", "[parlio_tx]")
         .max_transfer_size = 64,
         .valid_gpio_num = -1,
     };
-    for (int i = 0; i < SOC_PARLIO_GROUPS; i++) {
-        for (int j = 0; j < SOC_PARLIO_TX_UNITS_PER_GROUP; j++) {
+    for (int i = 0; i < PARLIO_LL_GET(INST_NUM); i++) {
+        for (int j = 0; j < PARLIO_LL_GET(TX_UNITS_PER_INST); j++) {
             TEST_ESP_OK(parlio_new_tx_unit(&config, &units[k++]));
         }
     }
@@ -649,7 +649,7 @@ TEST_CASE("parlio_tx_loop_transmission", "[parlio_tx]")
 }
 #endif  // SOC_PARLIO_TX_SUPPORT_LOOP_TRANSMISSION
 
-#if SOC_PARLIO_TX_SUPPORT_EOF_FROM_DMA
+#if PARLIO_LL_SUPPORT(TX_EOF_FROM_DMA)
 TEST_CASE("parlio_tx can transmit buffer larger than max_size decided by datalen_eof", "[parlio_tx]")
 {
     printf("install parlio tx unit\r\n");
@@ -695,4 +695,4 @@ TEST_CASE("parlio_tx can transmit buffer larger than max_size decided by datalen
     TEST_ESP_OK(parlio_del_tx_unit(tx_unit));
     free(buffer);
 }
-#endif // SOC_PARLIO_TX_SUPPORT_EOF_FROM_DMA
+#endif // PARLIO_LL_SUPPORT(TX_EOF_FROM_DMA)
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export CI_PIPELINE_ID=test-pipeline

# Verify Python dependencies are installed (no --user flag in virtualenv)
python3 -m pip install -r ${IDF_PATH}/tools/requirements/requirements.core.txt
# Use requirements.ci.txt if requirements.pytest.txt doesn't exist at this commit
if [ -f ${IDF_PATH}/tools/requirements/requirements.pytest.txt ]; then
    python3 -m pip install -r ${IDF_PATH}/tools/requirements/requirements.pytest.txt
elif [ -f ${IDF_PATH}/tools/requirements/requirements.ci.txt ]; then
    python3 -m pip install -r ${IDF_PATH}/tools/requirements/requirements.ci.txt
fi

# Navigate to the test directory
cd /testbed/components/esp_driver_parlio/test_apps/parlio

# Clean any previous build artifacts
rm -rf build sdkconfig

# Set target to esp32c6 (one of the supported targets for parlio tests)
idf.py set-target esp32c6

# Build the test application
# This validates syntax, semantics, API usage, dependency resolution, and linking
# Success indicates the test code is correct and compatible with ESP-IDF v6.1
idf.py build
rc=$?

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout e50f12974d56a757e602a1665f47eb99febbec56 "components/esp_driver_parlio/test_apps/parlio/CMakeLists.txt" "components/esp_driver_parlio/test_apps/parlio/main/CMakeLists.txt" "components/esp_driver_parlio/test_apps/parlio/main/test_parlio_bitscrambler.c" "components/esp_driver_parlio/test_apps/parlio/main/test_parlio_rx.c" "components/esp_driver_parlio/test_apps/parlio/main/test_parlio_tx.c"