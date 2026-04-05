#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout 414dba50090d0e2cd5ce1611fda3cbffcc9ebf13 "components/esp_lcd/test_apps/i2c_lcd/main/CMakeLists.txt" "components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_board.h" "components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.c" "tools/test_apps/system/cxx_build_test/main/CMakeLists.txt" "tools/test_apps/system/cxx_build_test/main/test_i2c_lcd.cpp"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_lcd/test_apps/i2c_lcd/main/CMakeLists.txt b/components/esp_lcd/test_apps/i2c_lcd/main/CMakeLists.txt
--- a/components/esp_lcd/test_apps/i2c_lcd/main/CMakeLists.txt
+++ b/components/esp_lcd/test_apps/i2c_lcd/main/CMakeLists.txt
@@ -1,5 +1,5 @@
 set(srcs "test_app_main.c"
-         "test_i2c_lcd_panel.c")
+         "test_i2c_lcd_panel.cpp")
 
 # In order for the cases defined by `TEST_CASE` to be linked into the final elf,
 # the component can be registered as WHOLE_ARCHIVE
diff --git a/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_board.h b/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_board.h
--- a/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_board.h
+++ b/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_board.h
@@ -12,8 +12,8 @@ extern "C" {
 #define TEST_LCD_H_RES          128
 #define TEST_LCD_V_RES          64
 
-#define TEST_I2C_SDA_GPIO       0
-#define TEST_I2C_SCL_GPIO       2
+#define TEST_I2C_SDA_GPIO       GPIO_NUM_0
+#define TEST_I2C_SCL_GPIO       GPIO_NUM_2
 
 #define TEST_I2C_HOST_ID        0
 
diff --git a/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.c b/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.cpp
rename from components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.c
rename to components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.cpp
--- a/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.c
+++ b/components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.cpp
@@ -27,13 +27,20 @@ TEST_CASE("lcd_panel_with_i2c_interface_(ssd1306)", "[lcd]")
     };
 
     i2c_master_bus_config_t i2c_bus_conf = {
-        .clk_source = I2C_CLK_SRC_DEFAULT,
+        .i2c_port = -1, // automatically select a free I2C port
         .sda_io_num = TEST_I2C_SDA_GPIO,
         .scl_io_num = TEST_I2C_SCL_GPIO,
-        .i2c_port = -1,
+        .clk_source = I2C_CLK_SRC_DEFAULT,
+        .glitch_ignore_cnt = 4,
+        .intr_priority = 0,
+        .trans_queue_depth = 0, // no tx queue, transmit using blocking mode
+        .flags = {
+            .enable_internal_pullup = true,
+            .allow_pd = false,
+        }
     };
 
-    i2c_master_bus_handle_t bus_handle;
+    i2c_master_bus_handle_t bus_handle = NULL;
     TEST_ESP_OK(i2c_new_master_bus(&i2c_bus_conf, &bus_handle));
 
     esp_lcd_panel_io_handle_t io_handle = NULL;
@@ -44,14 +51,26 @@ TEST_CASE("lcd_panel_with_i2c_interface_(ssd1306)", "[lcd]")
         .dc_bit_offset = 6,       // According to SSD1306 datasheet
         .lcd_cmd_bits = 8,        // According to SSD1306 datasheet
         .lcd_param_bits = 8,      // According to SSD1306 datasheet
+        .on_color_trans_done = NULL,
+        .user_ctx = NULL,
+        .flags = {
+            .dc_low_on_data = false, // According to SSD1306 datasheet, DC=0 means command, DC=1 means data
+            .disable_control_phase = false, // Control phase is used
+        }
     };
 
     TEST_ESP_OK(esp_lcd_new_panel_io_i2c(bus_handle, &io_config, &io_handle));
 
     esp_lcd_panel_handle_t panel_handle = NULL;
     esp_lcd_panel_dev_config_t panel_config = {
-        .bits_per_pixel = 1,
-        .reset_gpio_num = -1,
+        .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_BGR, // SSD1306 is monochrome, so RGB order doesn't matter
+        .data_endian = LCD_RGB_DATA_ENDIAN_LITTLE,
+        .bits_per_pixel = 1, // SSD1306 is monochrome, so 1 bit per pixel
+        .reset_gpio_num = GPIO_NUM_NC,
+        .vendor_config = NULL,
+        .flags = {
+            .reset_active_high = false, // SSD1306 reset is active low
+        }
     };
     TEST_ESP_OK(esp_lcd_new_panel_ssd1306(io_handle, &panel_config, &panel_handle));
     TEST_ESP_OK(esp_lcd_panel_reset(panel_handle));
diff --git a/tools/test_apps/system/cxx_build_test/main/CMakeLists.txt b/tools/test_apps/system/cxx_build_test/main/CMakeLists.txt
--- a/tools/test_apps/system/cxx_build_test/main/CMakeLists.txt
+++ b/tools/test_apps/system/cxx_build_test/main/CMakeLists.txt
@@ -3,10 +3,6 @@ set(srcs cxx_build_test_main.cpp
          test_cxx_standard.cpp
          test_sdmmc_sdspi_init.cpp)
 
-if(CONFIG_SOC_I2C_SUPPORTED)
-    list(APPEND srcs test_i2c_lcd.cpp)
-endif()
-
 if(CONFIG_SOC_I2S_SUPPORTED)
     list(APPEND srcs test_i2s.cpp)
 endif()
@@ -17,5 +13,4 @@ endif()
 
 idf_component_register(SRCS "${srcs}"
                        INCLUDE_DIRS "."
-                       PRIV_REQUIRES driver esp_lcd esp_driver_i2s
-                       REQUIRES soc)
+                       PRIV_REQUIRES driver esp_driver_i2s)
diff --git a/tools/test_apps/system/cxx_build_test/main/test_i2c_lcd.cpp b/tools/test_apps/system/cxx_build_test/main/test_i2c_lcd.cpp
deleted file mode 100644
--- a/tools/test_apps/system/cxx_build_test/main/test_i2c_lcd.cpp
+++ /dev/null
@@ -1,79 +0,0 @@
-/*
- * SPDX-FileCopyrightText: 2024 Espressif Systems (Shanghai) CO LTD
- *
- * SPDX-License-Identifier: Unlicense OR CC0-1.0
- */
-#include "esp_lcd_panel_vendor.h"
-#include "esp_lcd_panel_io.h"
-#include "driver/i2c_master.h"
-
-const esp_lcd_panel_dev_config_t panel_config0 = {
-    .reset_gpio_num = 0,
-    .color_space = ESP_LCD_COLOR_SPACE_MONOCHROME,
-    .data_endian = LCD_RGB_DATA_ENDIAN_LITTLE,
-    .bits_per_pixel = 16,
-    .flags = {
-        .reset_active_high = false,
-    },
-    .vendor_config = NULL,
-};
-
-const esp_lcd_panel_dev_config_t panel_config1 = {
-    .reset_gpio_num = 0,
-    .color_space = ESP_LCD_COLOR_SPACE_BGR,
-    .data_endian = LCD_RGB_DATA_ENDIAN_LITTLE,
-    .bits_per_pixel = 16,
-    .flags = {
-        .reset_active_high = false,
-    },
-    .vendor_config = NULL,
-};
-
-const esp_lcd_panel_dev_config_t panel_config2 = {
-    .reset_gpio_num = 0,
-    .rgb_endian = LCD_RGB_ENDIAN_BGR,
-    .data_endian = LCD_RGB_DATA_ENDIAN_LITTLE,
-    .bits_per_pixel = 16,
-    .flags = {
-        .reset_active_high = false,
-    },
-    .vendor_config = NULL,
-};
-
-void test_i2c_lcd_apis(void)
-{
-    i2c_master_bus_config_t i2c_bus_conf = {
-        .i2c_port = -1,
-        .sda_io_num = GPIO_NUM_0,
-        .scl_io_num = GPIO_NUM_2,
-        .clk_source = I2C_CLK_SRC_DEFAULT,
-        .glitch_ignore_cnt = 0,
-        .intr_priority = 1,
-        .trans_queue_depth = 4,
-        .flags = {
-            .enable_internal_pullup = true,
-            .allow_pd = false,
-        }
-    };
-
-    i2c_master_bus_handle_t bus_handle;
-    i2c_new_master_bus(&i2c_bus_conf, &bus_handle);
-
-    esp_lcd_panel_io_handle_t io_handle = NULL;
-    esp_lcd_panel_io_i2c_config_t io_config = {
-        .dev_addr = 0x3c,
-        .on_color_trans_done = NULL,
-        .user_ctx = NULL,
-        .control_phase_bytes = 1,
-        .dc_bit_offset = 6,
-        .lcd_cmd_bits = 8,
-        .lcd_param_bits = 8,
-        .flags = {
-            .dc_low_on_data = false,
-            .disable_control_phase = false,
-        },
-        .scl_speed_hz = 10 * 1000,
-    };
-
-    esp_lcd_new_panel_io_i2c(bus_handle, &io_config, &io_handle);
-}
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export LC_ALL=C.UTF-8
export PYTHONPATH="${IDF_PATH}/tools:${IDF_PATH}/tools/ci:${IDF_PATH}/tools/ci/python_packages:${IDF_PATH}/tools/esp_app_trace:${IDF_PATH}/components/partition_table:${PYTHONPATH}"
source /testbed/export.sh

# Initialize return code
rc=0

# Test 1: Build I2C LCD Panel Test Application
echo "=== Building I2C LCD Panel Test Application ==="
cd /testbed/components/esp_lcd/test_apps/i2c_lcd

# Clean any previous builds
rm -rf build sdkconfig

echo "=== Setting target to esp32 ==="
idf.py set-target esp32
set_target_rc=$?

if [ $set_target_rc -ne 0 ]; then
    echo "ERROR: idf.py set-target failed for i2c_lcd test with exit code $set_target_rc"
    rc=1
else
    echo "SUCCESS: Target set to esp32 for i2c_lcd test"
    
    echo "=== Building I2C LCD test application ==="
    idf.py build
    build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: idf.py build failed for i2c_lcd test with exit code $build_rc"
        rc=1
    else
        echo "SUCCESS: I2C LCD test build completed successfully"
    fi
fi

# Test 2: Build C++ Build Test Application (only if first test passed)
if [ $rc -eq 0 ]; then
    echo "=== Building C++ Build Test Application ==="
    cd /testbed/tools/test_apps/system/cxx_build_test
    
    # Clean any previous builds
    rm -rf build sdkconfig
    
    echo "=== Setting target to esp32 ==="
    idf.py set-target esp32
    set_target_rc=$?
    
    if [ $set_target_rc -ne 0 ]; then
        echo "ERROR: idf.py set-target failed for cxx_build_test with exit code $set_target_rc"
        rc=1
    else
        echo "SUCCESS: Target set to esp32 for cxx_build_test"
        
        echo "=== Building C++ test application ==="
        idf.py build
        build_rc=$?
        
        if [ $build_rc -ne 0 ]; then
            echo "ERROR: idf.py build failed for cxx_build_test with exit code $build_rc"
            rc=1
        else
            echo "SUCCESS: C++ build test completed successfully"
        fi
    fi
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout 414dba50090d0e2cd5ce1611fda3cbffcc9ebf13 "components/esp_lcd/test_apps/i2c_lcd/main/CMakeLists.txt" "components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_board.h" "components/esp_lcd/test_apps/i2c_lcd/main/test_i2c_lcd_panel.c" "tools/test_apps/system/cxx_build_test/main/CMakeLists.txt" "tools/test_apps/system/cxx_build_test/main/test_i2c_lcd.cpp"