#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 3a0eba4c4635800c42773c3c5ff84067e401d06d "components/app_trace/test_apps/.build-test-rules.yml" "components/driver/test_apps/legacy_twai/main/CMakeLists.txt" "components/esp_driver_gptimer/test_apps/gptimer/CMakeLists.txt" "components/esp_driver_i2c/test_apps/i2c_test_apps/CMakeLists.txt" "components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/CMakeLists.txt" "components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml" "components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/CMakeLists.txt" "components/spi_flash/test_apps/mspi_test/CMakeLists.txt" "components/vfs/test_apps/.build-test-rules.yml" "examples/bluetooth/.build-test-rules.yml" "examples/storage/.build-test-rules.yml" "examples/storage/fatfs/.build-test-rules.yml" "examples/storage/nvs/.build-test-rules.yml" "tools/test_apps/phy/.build-test-rules.yml"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/app_trace/test_apps/.build-test-rules.yml b/components/app_trace/test_apps/.build-test-rules.yml
--- a/components/app_trace/test_apps/.build-test-rules.yml
+++ b/components/app_trace/test_apps/.build-test-rules.yml
@@ -5,8 +5,9 @@ components/app_trace/test_apps:
     - app_trace
     - esp_timer
     - soc
-    - driver
     - esp_hw_support
+    - esp_driver_uart
+    - esp_driver_gptimer
   disable:
     - if: IDF_TARGET in ["esp32c5", "esp32c61", "esp32h21", "esp32h4"]
       temporary: true
diff --git a/components/driver/test_apps/legacy_twai/main/CMakeLists.txt b/components/driver/test_apps/legacy_twai/main/CMakeLists.txt
--- a/components/driver/test_apps/legacy_twai/main/CMakeLists.txt
+++ b/components/driver/test_apps/legacy_twai/main/CMakeLists.txt
@@ -5,5 +5,5 @@ set(srcs "test_app_main.cpp"
 # In order for the cases defined by `TEST_CASE` to be linked into the final elf,
 # the component can be registered as WHOLE_ARCHIVE
 idf_component_register(SRCS ${srcs}
-                       PRIV_REQUIRES unity driver esp_driver_gpio esp_hw_support
+                       PRIV_REQUIRES unity driver esp_hw_support
                        WHOLE_ARCHIVE)
diff --git a/components/esp_driver_gptimer/test_apps/gptimer/CMakeLists.txt b/components/esp_driver_gptimer/test_apps/gptimer/CMakeLists.txt
--- a/components/esp_driver_gptimer/test_apps/gptimer/CMakeLists.txt
+++ b/components/esp_driver_gptimer/test_apps/gptimer/CMakeLists.txt
@@ -9,9 +9,19 @@ project(gptimer_test)
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    # Collect RTL directories in a variable for readability. Join them
+    # with commas so they are passed as a single --rtl-dirs argument to the script.
+    set(GPTIMER_RTL_DIRS
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_gptimer
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_timg
+    )
+    string(JOIN "," GPTIMER_RTL_DIRS_JOINED ${GPTIMER_RTL_DIRS})
+
     add_custom_target(check_test_app_sections ALL
-                      COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                      --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_gptimer/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+                      COMMAND ${PYTHON}
+                      $ENV{IDF_PATH}/tools/ci/check_callgraph.py
+                      --rtl-dirs ${GPTIMER_RTL_DIRS_JOINED}
                       --elf-file ${CMAKE_BINARY_DIR}/gptimer_test.elf
                       find-refs
                       --from-sections=.iram0.text
diff --git a/components/esp_driver_i2c/test_apps/i2c_test_apps/CMakeLists.txt b/components/esp_driver_i2c/test_apps/i2c_test_apps/CMakeLists.txt
--- a/components/esp_driver_i2c/test_apps/i2c_test_apps/CMakeLists.txt
+++ b/components/esp_driver_i2c/test_apps/i2c_test_apps/CMakeLists.txt
@@ -13,9 +13,18 @@ project(i2c_test)
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    # Collect RTL directories in a variable for readability. Join them
+    # with commas so they are passed as a single --rtl-dirs argument to the script.
+    set(I2C_RTL_DIRS
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_i2c
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_i2c
+    )
+    string(JOIN "," I2C_RTL_DIRS_JOINED ${I2C_RTL_DIRS})
+
     add_custom_target(check_test_app_sections ALL
                         COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                        --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_driver_i2c/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+                        --rtl-dirs ${I2C_RTL_DIRS_JOINED}
                         --elf-file ${CMAKE_BINARY_DIR}/i2c_test.elf
                         find-refs
                         --from-sections=.iram0.text
diff --git a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/CMakeLists.txt b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/CMakeLists.txt
--- a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/CMakeLists.txt
+++ b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/CMakeLists.txt
@@ -4,10 +4,5 @@ cmake_minimum_required(VERSION 3.22)
 # "Trim" the build. Include the minimal set of components, main, and anything it depends on.
 set(COMPONENTS main)
 
-set(EXTRA_COMPONENT_DIRS
-    "$ENV{IDF_PATH}/tools/test_apps/components"
-    "$ENV{IDF_PATH}/components/driver/test_apps/components"
-)
-
 include($ENV{IDF_PATH}/tools/cmake/project.cmake)
 project(host_sdmmc)
diff --git a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml
--- a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml
+++ b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml
@@ -3,3 +3,5 @@ dependencies:
   espressif/esp_serial_slave_link: "^1.1.0"
   test_driver_utils:
     path: ${IDF_PATH}/components/driver/test_apps/components/test_driver_utils
+  test_utils:
+    path: ${IDF_PATH}/tools/test_apps/components/test_utils
diff --git a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/CMakeLists.txt b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/CMakeLists.txt
--- a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/CMakeLists.txt
+++ b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/CMakeLists.txt
@@ -4,11 +4,6 @@ cmake_minimum_required(VERSION 3.22)
 # "Trim" the build. Include the minimal set of components, main, and anything it depends on.
 set(COMPONENTS main)
 
-set(EXTRA_COMPONENT_DIRS
-    "$ENV{IDF_PATH}/tools/test_apps/components"
-    "$ENV{IDF_PATH}/components/driver/test_apps/components"
-)
-
 include($ENV{IDF_PATH}/tools/cmake/project.cmake)
 project(sdio)
 
diff --git a/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/main/idf_component.yml b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/main/idf_component.yml
new file mode 100644
--- /dev/null
+++ b/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/main/idf_component.yml
@@ -0,0 +1,5 @@
+dependencies:
+  test_driver_utils:
+    path: ${IDF_PATH}/components/driver/test_apps/components/test_driver_utils
+  test_utils:
+    path: ${IDF_PATH}/tools/test_apps/components/test_utils
diff --git a/components/spi_flash/test_apps/mspi_test/CMakeLists.txt b/components/spi_flash/test_apps/mspi_test/CMakeLists.txt
--- a/components/spi_flash/test_apps/mspi_test/CMakeLists.txt
+++ b/components/spi_flash/test_apps/mspi_test/CMakeLists.txt
@@ -10,9 +10,17 @@ project(mspi_test)
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    # Collect RTL directories in a variable for readability. Join them
+    # with commas so they are passed as a single --rtl-dirs argument to the script.
+    set(MSPI_RTL_DIRS
+        # ${CMAKE_BINARY_DIR}/esp-idf/spi_flash # IDF-14271
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_mspi
+    )
+    string(JOIN "," MSPI_RTL_DIRS_JOINED ${MSPI_RTL_DIRS})
     add_custom_target(check_test_app_sections ALL
                       COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                      --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/driver/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+                      --rtl-dirs ${MSPI_RTL_DIRS_JOINED}
                       --elf-file ${CMAKE_BINARY_DIR}/mspi_test.elf
                       find-refs
                       --from-sections=.iram0.text
diff --git a/components/vfs/test_apps/.build-test-rules.yml b/components/vfs/test_apps/.build-test-rules.yml
--- a/components/vfs/test_apps/.build-test-rules.yml
+++ b/components/vfs/test_apps/.build-test-rules.yml
@@ -14,4 +14,3 @@ components/vfs/test_apps:
     - fatfs
     - spiffs
     - console
-    - driver
diff --git a/examples/bluetooth/.build-test-rules.yml b/examples/bluetooth/.build-test-rules.yml
--- a/examples/bluetooth/.build-test-rules.yml
+++ b/examples/bluetooth/.build-test-rules.yml
@@ -67,10 +67,10 @@ examples/bluetooth/bluedroid/classic_bt:
     - esp_driver_gpio
     - esp_driver_i2s
     - esp_driver_uart
+    - esp_driver_dac
   depends_components-:
     - mbedtls
   depends_filepatterns:
-    - components/driver/dac/**/*
     - examples/bluetooth/bluedroid/esp_hid_host/**/*
     - examples/bluetooth/bluedroid/classic_bt/pytest_classic_bt_test.py
     - examples/bluetooth/bluedroid/classic_bt/bt_discovery/pytest_classic_bt_discovery_test.py
@@ -83,8 +83,7 @@ examples/bluetooth/bluedroid/coex/a2dp_gatts_coex:
       reason: the other targets are not tested yet
   depends_components+:
     - esp_driver_i2s
-  depends_filepatterns:
-    - components/driver/dac/**/*
+    - esp_driver_dac
 
 examples/bluetooth/blufi:
   <<: *bt_default_depends
diff --git a/examples/storage/.build-test-rules.yml b/examples/storage/.build-test-rules.yml
--- a/examples/storage/.build-test-rules.yml
+++ b/examples/storage/.build-test-rules.yml
@@ -3,7 +3,6 @@
 examples/storage/custom_flash_driver:
   depends_components:
     - spi_flash
-    - driver
 
 examples/storage/emmc:
   depends_components:
diff --git a/examples/storage/fatfs/.build-test-rules.yml b/examples/storage/fatfs/.build-test-rules.yml
--- a/examples/storage/fatfs/.build-test-rules.yml
+++ b/examples/storage/fatfs/.build-test-rules.yml
@@ -13,7 +13,7 @@ examples/storage/fatfs/ext_flash:
     - fatfs
     - vfs
     - spi_flash
-    - driver
+    - esp_driver_spi
   disable:
     - if: IDF_TARGET in ["esp32p4", "esp32c5", "esp32c61", "esp32h21", "esp32h4"]
       temporary: true
diff --git a/examples/storage/nvs/.build-test-rules.yml b/examples/storage/nvs/.build-test-rules.yml
--- a/examples/storage/nvs/.build-test-rules.yml
+++ b/examples/storage/nvs/.build-test-rules.yml
@@ -20,7 +20,6 @@ examples/storage/nvs/nvs_console:
 examples/storage/nvs/nvs_rw_blob:
   depends_components:
     - nvs_flash
-    - driver
   disable_test:
     - if: IDF_TARGET not in ["esp32", "esp32c3"]
       reason: only one target per arch needed
diff --git a/tools/test_apps/phy/.build-test-rules.yml b/tools/test_apps/phy/.build-test-rules.yml
--- a/tools/test_apps/phy/.build-test-rules.yml
+++ b/tools/test_apps/phy/.build-test-rules.yml
@@ -12,7 +12,7 @@ tools/test_apps/phy/phy_tsens:
     - if: (SOC_WIFI_SUPPORTED != 1 or SOC_TEMP_SENSOR_SUPPORTED != 1) or SOC_LIGHT_SLEEP_SUPPORTED != 1
   depends_components:
     - hal
-    - driver
     - esp_phy
     - esp_hw_support
     - esp_wifi
+    - esp_driver_tsens
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/root/.espressif
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export LC_ALL=C.UTF-8
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== ESP-IDF Configuration Files Validation ==="
echo "NOTE: These are configuration files (CMakeLists.txt, YAML), not executable tests"
echo "This script will validate configurations by building the affected test applications"

# Test 1: Build legacy_twai test application
echo "=== Test 1: Building legacy_twai test application ==="
cd /testbed/components/driver/test_apps/legacy_twai
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
legacy_twai_rc=$?
if [ $legacy_twai_rc -ne 0 ]; then
    echo "ERROR: legacy_twai test app build failed"
    rc=1
else
    echo "SUCCESS: legacy_twai test app built successfully"
fi

# Test 2: Build gptimer test application
echo "=== Test 2: Building gptimer test application ==="
cd /testbed/components/esp_driver_gptimer/test_apps/gptimer
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
gptimer_rc=$?
if [ $gptimer_rc -ne 0 ]; then
    echo "ERROR: gptimer test app build failed"
    rc=1
else
    echo "SUCCESS: gptimer test app built successfully"
fi

# Test 3: Build i2c_test_apps
echo "=== Test 3: Building i2c_test_apps ==="
cd /testbed/components/esp_driver_i2c/test_apps/i2c_test_apps
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
i2c_rc=$?
if [ $i2c_rc -ne 0 ]; then
    echo "ERROR: i2c_test_apps build failed"
    rc=1
else
    echo "SUCCESS: i2c_test_apps built successfully"
fi

# Test 4: Build sdio host_sdmmc test application
echo "=== Test 4: Building sdio host_sdmmc test application ==="
cd /testbed/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
host_sdmmc_rc=$?
if [ $host_sdmmc_rc -ne 0 ]; then
    echo "ERROR: host_sdmmc test app build failed"
    rc=1
else
    echo "SUCCESS: host_sdmmc test app built successfully"
fi

# Test 5: Build sdio test application
echo "=== Test 5: Building sdio test application ==="
cd /testbed/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
sdio_rc=$?
if [ $sdio_rc -ne 0 ]; then
    echo "ERROR: sdio test app build failed"
    rc=1
else
    echo "SUCCESS: sdio test app built successfully"
fi

# Test 6: Build mspi_test application
echo "=== Test 6: Building mspi_test application ==="
cd /testbed/components/spi_flash/test_apps/mspi_test
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32
idf.py build
mspi_rc=$?
if [ $mspi_rc -ne 0 ]; then
    echo "ERROR: mspi_test app build failed"
    rc=1
else
    echo "SUCCESS: mspi_test app built successfully"
fi

# Test 7: Validate YAML configuration files
echo "=== Test 7: Validating YAML configuration files ==="
yaml_files=(
    "/testbed/components/app_trace/test_apps/.build-test-rules.yml"
    "/testbed/components/vfs/test_apps/.build-test-rules.yml"
    "/testbed/examples/bluetooth/.build-test-rules.yml"
    "/testbed/examples/storage/.build-test-rules.yml"
    "/testbed/examples/storage/fatfs/.build-test-rules.yml"
    "/testbed/examples/storage/nvs/.build-test-rules.yml"
    "/testbed/tools/test_apps/phy/.build-test-rules.yml"
)

for yaml_file in "${yaml_files[@]}"; do
    if [ -f "$yaml_file" ]; then
        echo "Validating $yaml_file..."
        # Basic YAML syntax validation using python
        python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>&1
        yaml_check=$?
        if [ $yaml_check -ne 0 ]; then
            echo "ERROR: YAML validation failed for $yaml_file"
            rc=1
        else
            echo "SUCCESS: YAML file $yaml_file is valid"
        fi
    else
        echo "WARNING: $yaml_file not found"
    fi
done

# Test 8: Validate idf_component.yml
echo "=== Test 8: Validating idf_component.yml ==="
component_yml="/testbed/components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml"
if [ -f "$component_yml" ]; then
    echo "Validating $component_yml..."
    python3 -c "import yaml; yaml.safe_load(open('$component_yml'))" 2>&1
    yml_check=$?
    if [ $yml_check -ne 0 ]; then
        echo "ERROR: Component YAML validation failed"
        rc=1
    else
        echo "SUCCESS: Component YAML file is valid"
    fi
else
    echo "WARNING: $component_yml not found"
fi

# Summary
echo "=== Configuration Validation Summary ==="
if [ $rc -eq 0 ]; then
    echo "SUCCESS: All configuration files validated successfully"
    echo "All test applications built without errors"
    echo "Build validation confirms patches are valid and configurations are correct"
else
    echo "FAILURE: One or more configuration validations failed"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 3a0eba4c4635800c42773c3c5ff84067e401d06d "components/app_trace/test_apps/.build-test-rules.yml" "components/driver/test_apps/legacy_twai/main/CMakeLists.txt" "components/esp_driver_gptimer/test_apps/gptimer/CMakeLists.txt" "components/esp_driver_i2c/test_apps/i2c_test_apps/CMakeLists.txt" "components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/CMakeLists.txt" "components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/host_sdmmc/main/idf_component.yml" "components/esp_driver_sdio/test_apps/sdio/sdio_common_tests/sdio/CMakeLists.txt" "components/spi_flash/test_apps/mspi_test/CMakeLists.txt" "components/vfs/test_apps/.build-test-rules.yml" "examples/bluetooth/.build-test-rules.yml" "examples/storage/.build-test-rules.yml" "examples/storage/fatfs/.build-test-rules.yml" "examples/storage/nvs/.build-test-rules.yml" "tools/test_apps/phy/.build-test-rules.yml"