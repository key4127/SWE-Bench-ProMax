#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 1862fdec74829d56a0a525754225035b3ecdd99b "components/esp_driver_gpio/test_apps/gpio_extensions/main/test_dedicated_gpio.c" "components/esp_driver_sdm/test_apps/sigma_delta/main/test_sdm.cpp"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_gpio/test_apps/gpio_extensions/main/test_dedicated_gpio.c b/components/esp_driver_gpio/test_apps/gpio_extensions/main/test_dedicated_gpio.c
--- a/components/esp_driver_gpio/test_apps/gpio_extensions/main/test_dedicated_gpio.c
+++ b/components/esp_driver_gpio/test_apps/gpio_extensions/main/test_dedicated_gpio.c
@@ -12,16 +12,17 @@
 #include "unity_test_utils.h"
 #include "esp_rom_sys.h"
 #include "soc/soc_caps_full.h"
+#include "hal/dedic_gpio_caps.h"
 #include "hal/dedic_gpio_periph.h"
 #include "hal/dedic_gpio_cpu_ll.h"
 #include "driver/gpio.h"
 #include "driver/dedic_gpio.h"
 
 TEST_CASE("Dedicated_GPIO_bundle_install/uninstall", "[dedic_gpio]")
 {
-    const int test_gpios[SOC_DEDIC_GPIO_ATTR(OUT_CHANS_PER_CPU) / 2] = {0};
-    const int test2_gpios[SOC_DEDIC_GPIO_ATTR(OUT_CHANS_PER_CPU) / 2 + 1] = {0};
-    const int test3_gpios[SOC_DEDIC_GPIO_ATTR(OUT_CHANS_PER_CPU) + 1] = {0};
+    const int test_gpios[DEDIC_GPIO_CAPS_GET(OUT_CHANS_PER_CPU) / 2] = {0};
+    const int test2_gpios[DEDIC_GPIO_CAPS_GET(OUT_CHANS_PER_CPU) / 2 + 1] = {0};
+    const int test3_gpios[DEDIC_GPIO_CAPS_GET(OUT_CHANS_PER_CPU) + 1] = {0};
     dedic_gpio_bundle_handle_t test_bundle, test_bundle2, test_bundle3 = NULL;
     dedic_gpio_bundle_config_t bundle_config = {
         .gpio_array = test_gpios,
@@ -48,7 +49,7 @@ TEST_CASE("Dedicated_GPIO_bundle_install/uninstall", "[dedic_gpio]")
     TEST_ASSERT_EQUAL_MESSAGE(ESP_OK, dedic_gpio_new_bundle(&bundle_config, &test_bundle), "create bundle with half channels failed");
     uint32_t mask = 0;
     TEST_ESP_OK(dedic_gpio_get_out_mask(test_bundle, &mask));
-    TEST_ASSERT_EQUAL_MESSAGE((1 << (SOC_DEDIC_GPIO_ATTR(OUT_CHANS_PER_CPU) / 2)) - 1, mask, "wrong out mask");
+    TEST_ASSERT_EQUAL_MESSAGE((1 << (DEDIC_GPIO_CAPS_GET(OUT_CHANS_PER_CPU) / 2)) - 1, mask, "wrong out mask");
     TEST_ESP_OK(dedic_gpio_get_in_mask(test_bundle, &mask));
     TEST_ASSERT_EQUAL_MESSAGE(0, mask, "wrong in mask");
 
diff --git a/components/esp_driver_sdm/test_apps/sigma_delta/main/test_sdm.cpp b/components/esp_driver_sdm/test_apps/sigma_delta/main/test_sdm.cpp
--- a/components/esp_driver_sdm/test_apps/sigma_delta/main/test_sdm.cpp
+++ b/components/esp_driver_sdm/test_apps/sigma_delta/main/test_sdm.cpp
@@ -11,6 +11,7 @@
 #include "unity.h"
 #include "driver/sdm.h"
 #include "hal/sdm_periph.h"
+#include "hal/sdm_caps.h"
 #include "esp_attr.h"
 
 TEST_CASE("sdm_channel_install_uninstall", "[sdm]")
@@ -25,17 +26,17 @@ TEST_CASE("sdm_channel_install_uninstall", "[sdm]")
             .allow_pd = false,
         },
     };
-    sdm_channel_handle_t chans[SOC_SDM_ATTR(INST_NUM)][SOC_SDM_ATTR(CHANS_PER_INST)] = {};
-    for (int i = 0; i < SOC_SDM_ATTR(INST_NUM); i++) {
-        for (int j = 0; j < SOC_SDM_ATTR(CHANS_PER_INST); j++) {
+    sdm_channel_handle_t chans[SDM_CAPS_GET(INST_NUM)][SDM_CAPS_GET(CHANS_PER_INST)] = {};
+    for (int i = 0; i < SDM_CAPS_GET(INST_NUM); i++) {
+        for (int j = 0; j < SDM_CAPS_GET(CHANS_PER_INST); j++) {
             TEST_ESP_OK(sdm_new_channel(&config, &chans[i][j]));
         }
         TEST_ESP_ERR(ESP_ERR_NOT_FOUND, sdm_new_channel(&config, &chans[0][0]));
     }
 
     printf("delete sdm channels\r\n");
-    for (int i = 0; i < SOC_SDM_ATTR(INST_NUM); i++) {
-        for (int j = 0; j < SOC_SDM_ATTR(CHANS_PER_INST); j++) {
+    for (int i = 0; i < SDM_CAPS_GET(INST_NUM); i++) {
+        for (int j = 0; j < SDM_CAPS_GET(CHANS_PER_INST); j++) {
             TEST_ESP_OK(sdm_del_channel(chans[i][j]));
         }
     }
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

# Note: These are embedded firmware tests that compile to ESP32 binaries, NOT native x86 executables.
# They cannot be executed on x86 host - they require ESP32 hardware or QEMU emulator.
# Validation approach: Build verification (successful compilation = valid test code).
# This is the standard CI approach for ESP-IDF projects.

# Test 1: Build gpio_extensions test app
# This test requires SOC_DEDICATED_GPIO_SUPPORTED, available on esp32s2, esp32s3, esp32c3, esp32c6, esp32h2
echo "=== Testing gpio_extensions (dedicated GPIO) for esp32s3 ==="
cd /testbed/components/esp_driver_gpio/test_apps/gpio_extensions
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32s3
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: gpio_extensions build failed for esp32s3"
else
    echo "SUCCESS: gpio_extensions build passed for esp32s3"
fi

# Test 2: Build sigma_delta test app
# This test requires SOC_SDM_SUPPORTED, available on esp32, esp32s2, esp32s3, esp32c3, esp32c6
echo "=== Testing sigma_delta (SDM) for esp32s3 ==="
cd /testbed/components/esp_driver_sdm/test_apps/sigma_delta
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32s3
idf.py build
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: sigma_delta build failed for esp32s3"
else
    echo "SUCCESS: sigma_delta build passed for esp32s3"
fi

# Summary
echo "=== Build Validation Summary ==="
if [ $rc -eq 0 ]; then
    echo "All test applications built successfully"
else
    echo "One or more test applications failed to build"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 1862fdec74829d56a0a525754225035b3ecdd99b "components/esp_driver_gpio/test_apps/gpio_extensions/main/test_dedicated_gpio.c" "components/esp_driver_sdm/test_apps/sigma_delta/main/test_sdm.cpp"