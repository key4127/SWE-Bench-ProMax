#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 5e8f251b7150e4d8aef37b5b9a7c6b0e741c7dcc "components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt" "components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c" "components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt" "components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c" "components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt b/components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt
--- a/components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt
+++ b/components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt
@@ -14,9 +14,18 @@ target_add_binary_data(mipi_dsi_lcd_panel_test.elf "resources/pictures/world.gra
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    # Collect RTL directories in a variable for readability. Join them
+    # with commas so they are passed as a single --rtl-dirs argument to the script.
+    set(LCD_RTL_DIRS
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_lcd
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_lcd
+    )
+    string(JOIN "," LCD_RTL_DIRS_JOINED ${LCD_RTL_DIRS})
+
     add_custom_target(check_test_app_sections ALL
                       COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                      --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_lcd/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+                      --rtl-dirs ${LCD_RTL_DIRS_JOINED}
                       --elf-file ${CMAKE_BINARY_DIR}/mipi_dsi_lcd_panel_test.elf
                       find-refs
                       --from-sections=.iram0.text
diff --git a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c
--- a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c
+++ b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c
@@ -269,7 +269,7 @@ TEST_CASE("MIPI DSI draw YUV422 image (EK79007)", "[mipi_dsi]")
         .virtual_channel = 0,
 
         // YUV422 -> RGB888
-        .in_color_format = LCD_COLOR_FMT_YUV422,
+        .in_color_format = LCD_COLOR_FMT_YUV422_YUYV,
         .out_color_format = LCD_COLOR_FMT_RGB888,
 
         .video_timing = {
@@ -298,15 +298,12 @@ TEST_CASE("MIPI DSI draw YUV422 image (EK79007)", "[mipi_dsi]")
     TEST_ESP_OK(esp_lcd_new_panel_ek79007(mipi_dbi_io, &lcd_dev_config, &mipi_dpi_panel));
 
     // Set color conversion configuration
-    esp_lcd_color_conv_config_t convert_config = {
+    esp_lcd_color_conv_yuv_config_t convert_config = {
         .in_color_range = LCD_COLOR_RANGE_FULL,
         .out_color_range = LCD_COLOR_RANGE_FULL,
-        .spec.yuv = {
-            .conv_std = LCD_YUV_CONV_STD_BT601,
-            .yuv422.in_pack_order = LCD_YUV422_PACK_ORDER_YUYV,
-        }
+        .conv_std = LCD_YUV_CONV_STD_BT601,
     };
-    TEST_ESP_OK(esp_lcd_dpi_panel_set_color_conversion(mipi_dpi_panel, &convert_config));
+    TEST_ESP_OK(esp_lcd_dpi_panel_set_yuv_conversion(mipi_dpi_panel, &convert_config));
 
     TEST_ESP_OK(esp_lcd_panel_reset(mipi_dpi_panel));
     TEST_ESP_OK(esp_lcd_panel_init(mipi_dpi_panel));
diff --git a/components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt b/components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt
--- a/components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt
+++ b/components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt
@@ -12,9 +12,18 @@ target_add_binary_data(rgb_lcd_panel_test.elf "resources/pictures/world.yuv" BIN
 
 idf_build_get_property(elf EXECUTABLE)
 if(CONFIG_COMPILER_DUMP_RTL_FILES)
+    # Collect RTL directories in a variable for readability. Join them
+    # with commas so they are passed as a single --rtl-dirs argument to the script.
+    set(LCD_RTL_DIRS
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_lcd
+        ${CMAKE_BINARY_DIR}/esp-idf/hal
+        ${CMAKE_BINARY_DIR}/esp-idf/esp_hal_lcd
+    )
+    string(JOIN "," LCD_RTL_DIRS_JOINED ${LCD_RTL_DIRS})
+
     add_custom_target(check_test_app_sections ALL
                       COMMAND ${PYTHON} $ENV{IDF_PATH}/tools/ci/check_callgraph.py
-                      --rtl-dirs ${CMAKE_BINARY_DIR}/esp-idf/esp_lcd/,${CMAKE_BINARY_DIR}/esp-idf/hal/
+                      --rtl-dirs ${LCD_RTL_DIRS_JOINED}
                       --elf-file ${CMAKE_BINARY_DIR}/rgb_lcd_panel_test.elf
                       find-refs
                       --from-sections=.iram0.text
diff --git a/components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c b/components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c
--- a/components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c
+++ b/components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c
@@ -25,15 +25,15 @@
 
 #define TEST_IMG_SIZE (100 * 100 * sizeof(uint16_t))
 
-static esp_lcd_panel_handle_t test_rgb_panel_initialization(size_t data_width, size_t bpp, size_t bb_pixels, bool refresh_on_demand, bool user_fb,
+static esp_lcd_panel_handle_t test_rgb_panel_initialization(size_t data_width, lcd_color_format_t in_color_format, size_t bb_pixels, bool refresh_on_demand, bool user_fb,
                                                             esp_lcd_rgb_panel_vsync_cb_t vsync_cb, void *user_data)
 {
     esp_lcd_panel_handle_t panel_handle = NULL;
     esp_lcd_rgb_panel_config_t panel_config = {
         .data_width = data_width,
+        .in_color_format = in_color_format,
         .dma_burst_size = 64,
         .bounce_buffer_size_px = bb_pixels,
-        .bits_per_pixel = bpp,
         .clk_src = LCD_CLK_SRC_DEFAULT,
         .disp_gpio_num = TEST_LCD_DISP_EN_GPIO,
         .pclk_gpio_num = TEST_LCD_PCLK_GPIO,
@@ -97,7 +97,7 @@ TEST_CASE("lcd_rgb_panel_stream_mode", "[lcd]")
     TEST_ASSERT_NOT_NULL(img);
 
     printf("initialize RGB panel with stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, false, false, NULL, NULL);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, false, false, NULL, NULL);
     printf("flush random color block\r\n");
     for (int i = 0; i < 200; i++) {
         uint8_t color_byte = esp_random() & 0xFF;
@@ -119,7 +119,7 @@ TEST_CASE("lcd_rgb_panel_8bit_interface", "[lcd]")
 
     printf("initialize RGB panel with stream mode\r\n");
     // bpp for RGB888 is 24
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(8, 24, 0, false, false, NULL, NULL);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(8, LCD_COLOR_FMT_RGB888, 0, false, false, NULL, NULL);
     uint8_t color_byte = esp_random() & 0xFF;
     printf("flush random color block 0x%x\r\n", color_byte);
     int x_start = esp_random() % (TEST_LCD_H_RES - 100);
@@ -147,7 +147,7 @@ TEST_CASE("lcd_rgb_panel_refresh_on_demand", "[lcd]")
     TaskHandle_t cur_task = xTaskGetCurrentTaskHandle();
 
     printf("initialize RGB panel with non-stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, true, false, test_rgb_panel_trans_done, cur_task);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, true, false, test_rgb_panel_trans_done, cur_task);
     printf("flush random color block\r\n");
     for (int i = 0; i < 200; i++) {
         uint8_t color_byte = esp_random() & 0xFF;
@@ -172,7 +172,7 @@ TEST_CASE("lcd_rgb_panel_bounce_buffer", "[lcd]")
     TaskHandle_t cur_task = xTaskGetCurrentTaskHandle();
 
     printf("initialize RGB panel with non-stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 20 * TEST_LCD_H_RES, false, false, test_rgb_panel_trans_done, cur_task);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 20 * TEST_LCD_H_RES, false, false, test_rgb_panel_trans_done, cur_task);
     printf("flush random color block\r\n");
     for (int i = 0; i < 200; i++) {
         uint8_t color_byte = esp_random() & 0xFF;
@@ -195,7 +195,7 @@ TEST_CASE("lcd_rgb_panel_update_pclk", "[lcd]")
     TEST_ASSERT_NOT_NULL(img);
 
     printf("initialize RGB panel with stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, false, false, NULL, NULL);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, false, false, NULL, NULL);
     printf("flush one clock block to the LCD\r\n");
     uint8_t color_byte = esp_random() & 0xFF;
     int x_start = esp_random() % (TEST_LCD_H_RES - 100);
@@ -223,7 +223,7 @@ TEST_CASE("lcd_rgb_panel_restart", "[lcd]")
     TEST_ASSERT_NOT_NULL(img);
 
     printf("initialize RGB panel with stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, false, false, NULL, NULL);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, false, false, NULL, NULL);
     printf("flush one clock block to the LCD\r\n");
     uint8_t color_byte = esp_random() & 0xFF;
     int x_start = esp_random() % (TEST_LCD_H_RES - 100);
@@ -253,7 +253,7 @@ TEST_CASE("lcd_rgb_panel_rotate", "[lcd]")
     memset(img, color_byte, w * h * sizeof(uint16_t));
 
     printf("initialize RGB panel with stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, false, false, NULL, NULL);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, false, false, NULL, NULL);
 
     printf("Update the rotation of panel\r\n");
     for (size_t i = 0; i < 8; i++) {
@@ -278,7 +278,7 @@ TEST_CASE("lcd_rgb_panel_user_frame_buffer", "[lcd]")
     TEST_ASSERT_NOT_NULL(img);
 
     printf("initialize RGB panel with stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, false, true, NULL, NULL);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, false, true, NULL, NULL);
 
     printf("flush one clock block to the LCD\r\n");
     uint8_t color_byte = esp_random() & 0xFF;
@@ -325,7 +325,7 @@ TEST_CASE("lcd_rgb_panel_iram_safe", "[lcd]")
     uint32_t callback_calls = 0;
 
     printf("initialize RGB panel with stream mode\r\n");
-    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, 16, 0, false, false, test_rgb_panel_count_in_callback, &callback_calls);
+    esp_lcd_panel_handle_t panel_handle = test_rgb_panel_initialization(16, LCD_COLOR_FMT_RGB565, 0, false, false, test_rgb_panel_count_in_callback, &callback_calls);
     printf("flush one clock block to the LCD\r\n");
     uint8_t color_byte = esp_random() & 0xFF;
     int x_start = esp_random() % (TEST_LCD_H_RES - 100);
diff --git a/components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c b/components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c
--- a/components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c
+++ b/components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c
@@ -28,7 +28,8 @@ TEST_CASE("lcd_rgb_panel_yuv422_conversion", "[lcd]")
     esp_lcd_rgb_panel_config_t panel_config = {
         .data_width = 16,
         .dma_burst_size = 64,
-        .bits_per_pixel = 16, // YUV422: 16bits per pixel
+        .in_color_format = LCD_COLOR_FMT_YUV422_UYVY,
+        .out_color_format = LCD_COLOR_FMT_RGB565,
         .clk_src = LCD_CLK_SRC_DEFAULT,
         .disp_gpio_num = TEST_LCD_DISP_EN_GPIO,
         .pclk_gpio_num = TEST_LCD_PCLK_GPIO,
@@ -72,21 +73,11 @@ TEST_CASE("lcd_rgb_panel_yuv422_conversion", "[lcd]")
     TEST_ESP_OK(esp_lcd_panel_reset(panel_handle));
 
     printf("Set YUV-RGB conversion profile\r\n");
-    esp_lcd_yuv_conv_config_t conv_config = {
-        .std = LCD_YUV_CONV_STD_BT601,
-        .src = {
-            .color_range = LCD_COLOR_RANGE_FULL,
-            .color_space = LCD_COLOR_SPACE_RGB,
-        },
-        .dst = {
-            .color_range = LCD_COLOR_RANGE_FULL,
-            .color_space = LCD_COLOR_SPACE_RGB,
-        },
+    esp_lcd_color_conv_yuv_config_t conv_config = {
+        .conv_std = LCD_YUV_CONV_STD_BT601,
+        .in_color_range = LCD_COLOR_RANGE_FULL,
+        .out_color_range = LCD_COLOR_RANGE_FULL,
     };
-    TEST_ESP_ERR(ESP_ERR_INVALID_ARG, esp_lcd_rgb_panel_set_yuv_conversion(panel_handle, &conv_config));
-
-    conv_config.src.color_space = LCD_COLOR_SPACE_YUV;
-    conv_config.src.yuv_sample = LCD_YUV_SAMPLE_422;
     TEST_ESP_OK(esp_lcd_rgb_panel_set_yuv_conversion(panel_handle, &conv_config));
 
     TEST_ESP_OK(esp_lcd_panel_init(panel_handle));
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export CI_PIPELINE_ID=test-pipeline
export PYTHONPATH=${IDF_PATH}/tools:${IDF_PATH}/tools/ci:${IDF_PATH}/tools/esp_app_trace:${IDF_PATH}/components/partition_table:${IDF_PATH}/tools/ci/python_packages

# Verify Python dependencies are installed
python3 -m pip install --break-system-packages --upgrade pip setuptools wheel

# Initialize overall return code
overall_rc=0

# Test 1: Build rgb_lcd test app for esp32s3 (iram_safe config)
echo "=========================================="
echo "Building rgb_lcd test app for esp32s3..."
echo "=========================================="
cd /testbed/components/esp_lcd/test_apps/rgb_lcd
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32s3
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: rgb_lcd test app build for esp32s3 failed with exit code $rc"
    overall_rc=$rc
else
    echo "SUCCESS: rgb_lcd test app for esp32s3 built successfully"
fi

# Test 2: Build rgb_lcd test app for esp32p4 (release config)
echo "=========================================="
echo "Building rgb_lcd test app for esp32p4..."
echo "=========================================="
cd /testbed/components/esp_lcd/test_apps/rgb_lcd
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32p4
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: rgb_lcd test app build for esp32p4 failed with exit code $rc"
    overall_rc=$rc
else
    echo "SUCCESS: rgb_lcd test app for esp32p4 built successfully"
fi

# Test 3: Build mipi_dsi_lcd test app for esp32p4 (cache_safe config)
echo "=========================================="
echo "Building mipi_dsi_lcd test app for esp32p4..."
echo "=========================================="
cd /testbed/components/esp_lcd/test_apps/mipi_dsi_lcd
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32p4
idf.py build
rc=$?
if [ $rc -ne 0 ]; then
    echo "ERROR: mipi_dsi_lcd test app build for esp32p4 failed with exit code $rc"
    overall_rc=$rc
else
    echo "SUCCESS: mipi_dsi_lcd test app for esp32p4 built successfully"
fi

# Validate C source files syntax (basic check)
echo "=========================================="
echo "Validating C source files..."
echo "=========================================="
cd /testbed

# Check rgb_lcd test files
for file in "components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c" "components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c"; do
    if [ -f "$file" ]; then
        echo "Checking syntax of $file..."
        python3 -c "
import sys
try:
    with open('$file', 'r') as f:
        content = f.read()
    # Basic syntax validation - check for common C patterns
    if '#include' in content or 'void' in content or 'int' in content:
        print('File $file appears to be valid C source')
        sys.exit(0)
    else:
        print('WARNING: File $file may not be valid C source')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: Failed to validate $file: {e}')
    sys.exit(1)
"
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "ERROR: Validation failed for $file"
            overall_rc=$rc
        fi
    else
        echo "ERROR: File $file not found"
        overall_rc=1
    fi
done

# Check mipi_dsi_lcd test file
file="components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c"
if [ -f "$file" ]; then
    echo "Checking syntax of $file..."
    python3 -c "
import sys
try:
    with open('$file', 'r') as f:
        content = f.read()
    if '#include' in content or 'void' in content or 'int' in content:
        print('File $file appears to be valid C source')
        sys.exit(0)
    else:
        print('WARNING: File $file may not be valid C source')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: Failed to validate $file: {e}')
    sys.exit(1)
"
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: Validation failed for $file"
        overall_rc=$rc
    fi
else
    echo "ERROR: File $file not found"
    overall_rc=1
fi

# Validate CMakeLists.txt files
echo "=========================================="
echo "Validating CMakeLists.txt files..."
echo "=========================================="
for cmake_file in "components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt" "components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt"; do
    if [ -f "$cmake_file" ]; then
        echo "Checking $cmake_file..."
        python3 -c "
import sys
try:
    with open('$cmake_file', 'r') as f:
        content = f.read()
    # Basic validation - check for CMake patterns
    if 'cmake_minimum_required' in content or 'project' in content or 'idf_component_register' in content:
        print('File $cmake_file appears to be valid CMake')
        sys.exit(0)
    else:
        print('WARNING: File $cmake_file may not be valid CMake')
        sys.exit(1)
except Exception as e:
    print(f'ERROR: Failed to validate $cmake_file: {e}')
    sys.exit(1)
"
        rc=$?
        if [ $rc -ne 0 ]; then
            echo "ERROR: Validation failed for $cmake_file"
            overall_rc=$rc
        fi
    else
        echo "ERROR: File $cmake_file not found"
        overall_rc=1
    fi
done

# Summary
echo "=========================================="
echo "Build Validation Summary"
echo "=========================================="
if [ $overall_rc -eq 0 ]; then
    echo "SUCCESS: All builds and validations passed"
    echo "NOTE: Runtime tests require physical ESP32-S3/ESP32-P4 hardware with LCD panels"
else
    echo "FAILURE: Some builds or validations failed"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$overall_rc"

# Cleanup: restore original files
cd /testbed
git checkout 5e8f251b7150e4d8aef37b5b9a7c6b0e741c7dcc "components/esp_lcd/test_apps/mipi_dsi_lcd/CMakeLists.txt" "components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c" "components/esp_lcd/test_apps/rgb_lcd/CMakeLists.txt" "components/esp_lcd/test_apps/rgb_lcd/main/test_rgb_panel.c" "components/esp_lcd/test_apps/rgb_lcd/main/test_yuv_rgb_conv.c"