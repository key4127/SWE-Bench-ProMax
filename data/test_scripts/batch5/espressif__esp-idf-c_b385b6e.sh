#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout cb98f7b5ef0e2e2c1b8a92a7f92e98e0283bd18c "components/esp_lcd/test_apps/mipi_dsi_lcd/main/CMakeLists.txt" "components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_iram.c" "components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/CMakeLists.txt b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/CMakeLists.txt
--- a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/CMakeLists.txt
+++ b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/CMakeLists.txt
@@ -9,5 +9,5 @@ endif()
 # In order for the cases defined by `TEST_CASE` to be linked into the final elf,
 # the component can be registered as WHOLE_ARCHIVE
 idf_component_register(SRCS ${srcs}
-                       PRIV_REQUIRES esp_lcd unity
+                       PRIV_REQUIRES esp_lcd unity esp_driver_ppa
                        WHOLE_ARCHIVE)
diff --git a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_iram.c b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_iram.c
--- a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_iram.c
+++ b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_iram.c
@@ -18,7 +18,7 @@
 #include "test_mipi_dsi_board.h"
 #include "esp_lcd_ek79007.h"
 
-IRAM_ATTR static bool test_rgb_panel_count_in_callback(esp_lcd_panel_handle_t panel, esp_lcd_dpi_panel_event_data_t *edata, void *user_ctx)
+IRAM_ATTR static bool test_dpi_panel_count_in_callback(esp_lcd_panel_handle_t panel, esp_lcd_dpi_panel_event_data_t *edata, void *user_ctx)
 {
     uint32_t *count = (uint32_t *)user_ctx;
     *count = *count + 1;
@@ -91,7 +91,7 @@ TEST_CASE("MIPI DSI draw bitmap (EK79007) IRAM Safe", "[mipi_dsi]")
 
     uint32_t callback_calls = 0;
     esp_lcd_dpi_panel_event_callbacks_t cbs = {
-        .on_refresh_done = test_rgb_panel_count_in_callback,
+        .on_refresh_done = test_dpi_panel_count_in_callback,
     };
     TEST_ESP_OK(esp_lcd_dpi_panel_register_event_callbacks(mipi_dpi_panel, &cbs, &callback_calls));
 
diff --git a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c
--- a/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c
+++ b/components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c
@@ -1,5 +1,5 @@
 /*
- * SPDX-FileCopyrightText: 2023-2024 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2023-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
@@ -16,6 +16,7 @@
 #include "esp_attr.h"
 #include "test_mipi_dsi_board.h"
 #include "esp_lcd_ek79007.h"
+#include "driver/ppa.h"
 
 TEST_CASE("MIPI DSI Pattern Generator (EK79007)", "[mipi_dsi]")
 {
@@ -86,7 +87,7 @@ TEST_CASE("MIPI DSI Pattern Generator (EK79007)", "[mipi_dsi]")
     test_bsp_disable_dsi_phy_power();
 }
 
-#define TEST_IMG_SIZE (100 * 100 * sizeof(uint16_t))
+#define TEST_IMG_SIZE (200 * 200 * sizeof(uint16_t))
 
 TEST_CASE("MIPI DSI draw RGB bitmap (EK79007)", "[mipi_dsi]")
 {
@@ -162,6 +163,294 @@ TEST_CASE("MIPI DSI draw RGB bitmap (EK79007)", "[mipi_dsi]")
     test_bsp_disable_dsi_phy_power();
 }
 
+#if SOC_HAS(DMA2D)
+TEST_CASE("MIPI DSI use DMA2D (EK79007)", "[mipi_dsi]")
+{
+    esp_lcd_dsi_bus_handle_t mipi_dsi_bus;
+    esp_lcd_panel_io_handle_t mipi_dbi_io;
+    esp_lcd_panel_handle_t mipi_dpi_panel;
+
+    test_bsp_enable_dsi_phy_power();
+
+    uint8_t *img = malloc(TEST_IMG_SIZE);
+    TEST_ASSERT_NOT_NULL(img);
+
+    esp_lcd_dsi_bus_config_t bus_config = {
+        .bus_id = 0,
+        .num_data_lanes = 2,
+        .lane_bit_rate_mbps = 1000, // 1000 Mbps
+    };
+    TEST_ESP_OK(esp_lcd_new_dsi_bus(&bus_config, &mipi_dsi_bus));
+
+    esp_lcd_dbi_io_config_t dbi_config = {
+        .virtual_channel = 0,
+        .lcd_cmd_bits = 8,
+        .lcd_param_bits = 8,
+    };
+    TEST_ESP_OK(esp_lcd_new_panel_io_dbi(mipi_dsi_bus, &dbi_config, &mipi_dbi_io));
+
+    esp_lcd_dpi_panel_config_t dpi_config = {
+        .dpi_clk_src = MIPI_DSI_DPI_CLK_SRC_DEFAULT,
+        .dpi_clock_freq_mhz = MIPI_DSI_DPI_CLK_MHZ,
+        .virtual_channel = 0,
+        .in_color_format = LCD_COLOR_FMT_RGB565,
+        .video_timing = {
+            .h_size = MIPI_DSI_LCD_H_RES,
+            .v_size = MIPI_DSI_LCD_V_RES,
+            .hsync_back_porch = MIPI_DSI_LCD_HBP,
+            .hsync_pulse_width = MIPI_DSI_LCD_HSYNC,
+            .hsync_front_porch = MIPI_DSI_LCD_HFP,
+            .vsync_back_porch = MIPI_DSI_LCD_VBP,
+            .vsync_pulse_width = MIPI_DSI_LCD_VSYNC,
+            .vsync_front_porch = MIPI_DSI_LCD_VFP,
+        },
+    };
+    ek79007_vendor_config_t vendor_config = {
+        .mipi_config = {
+            .dsi_bus = mipi_dsi_bus,
+            .dpi_config = &dpi_config,
+        },
+    };
+    esp_lcd_panel_dev_config_t lcd_dev_config = {
+        .reset_gpio_num = -1,
+        .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_RGB,
+        .bits_per_pixel = 16,
+        .vendor_config = &vendor_config,
+    };
+    TEST_ESP_OK(esp_lcd_new_panel_ek79007(mipi_dbi_io, &lcd_dev_config, &mipi_dpi_panel));
+    TEST_ESP_OK(esp_lcd_panel_reset(mipi_dpi_panel));
+    TEST_ESP_OK(esp_lcd_panel_init(mipi_dpi_panel));
+
+    printf("Draw bitmap 2D by CPU\r\n");
+    for (int i = 0; i < 100; i++) {
+        int x_start = rand() % (MIPI_DSI_LCD_H_RES - 100);
+        int y_start = rand() % (MIPI_DSI_LCD_V_RES - 100);
+        uint8_t color_byte = rand() & 0xFF;
+        memset(img, color_byte, TEST_IMG_SIZE / 2);
+        color_byte = rand() & 0xFF;
+        memset(img + TEST_IMG_SIZE / 2, color_byte, TEST_IMG_SIZE / 2);
+        esp_lcd_panel_draw_bitmap_2d(mipi_dpi_panel, x_start, y_start, x_start + 100, y_start + 100, img, 200, 200, 50, 50, 150, 150);
+        vTaskDelay(pdMS_TO_TICKS(10));
+    }
+    vTaskDelay(pdMS_TO_TICKS(1000));
+
+    printf("Add Built-in DMA2D draw bitmap hook\r\n");
+    TEST_ESP_OK(esp_lcd_dpi_panel_enable_dma2d(mipi_dpi_panel));
+    for (int i = 0; i < 100; i++) {
+        int x_start = rand() % (MIPI_DSI_LCD_H_RES - 100);
+        int y_start = rand() % (MIPI_DSI_LCD_V_RES - 100);
+        uint8_t color_byte = rand() & 0xFF;
+        memset(img, color_byte, TEST_IMG_SIZE / 2);
+        color_byte = rand() & 0xFF;
+        memset(img + TEST_IMG_SIZE / 2, color_byte, TEST_IMG_SIZE / 2);
+        esp_lcd_panel_draw_bitmap_2d(mipi_dpi_panel, x_start, y_start, x_start + 100, y_start + 100, img, 200, 200, 50, 50, 150, 150);
+        vTaskDelay(pdMS_TO_TICKS(10));
+    }
+    TEST_ESP_OK(esp_lcd_dpi_panel_disable_dma2d(mipi_dpi_panel));
+    vTaskDelay(pdMS_TO_TICKS(1000));
+
+    TEST_ESP_OK(esp_lcd_panel_del(mipi_dpi_panel));
+    TEST_ESP_OK(esp_lcd_panel_io_del(mipi_dbi_io));
+    TEST_ESP_OK(esp_lcd_del_dsi_bus(mipi_dsi_bus));
+    free(img);
+
+    test_bsp_disable_dsi_phy_power();
+}
+#endif // SOC_HAS(DMA2D)
+
+#if SOC_HAS(PPA)
+typedef struct {
+    ppa_client_handle_t ppa_srm_handle;
+    esp_lcd_draw_bitmap_hook_data_t hook_data;
+    SemaphoreHandle_t draw_sem;
+    esp_lcd_panel_handle_t panel;
+} test_dpi_panel_draw_bitmap_hook_ctx_t;
+
+typedef struct {
+    uint32_t count;
+    SemaphoreHandle_t draw_sem;
+} test_dpi_panel_color_trans_done_callback_ctx_t;
+
+IRAM_ATTR static bool test_ppa_srm_trans_done_callback(ppa_client_handle_t ppa_client, ppa_event_data_t *edata, void *user_ctx)
+{
+    bool need_yield = false;
+    test_dpi_panel_draw_bitmap_hook_ctx_t *hook_ctx = (test_dpi_panel_draw_bitmap_hook_ctx_t *)user_ctx;
+    esp_lcd_draw_bitmap_hook_data_t *hook_data = &hook_ctx->hook_data;
+
+    if (hook_data->on_hook_end) {
+        if (hook_data->on_hook_end(hook_ctx->panel)) {
+            need_yield = true;
+        }
+    }
+
+    return need_yield;
+}
+
+static esp_err_t test_draw_bitmap_hook_ppa(esp_lcd_panel_handle_t panel, const esp_lcd_draw_bitmap_hook_data_t *hook_data, void *user_ctx)
+{
+    test_dpi_panel_draw_bitmap_hook_ctx_t *hook_ctx = (test_dpi_panel_draw_bitmap_hook_ctx_t *)user_ctx;
+    ppa_client_handle_t ppa_srm_handle = hook_ctx->ppa_srm_handle;
+    memcpy(&hook_ctx->hook_data, hook_data, sizeof(esp_lcd_draw_bitmap_hook_data_t));
+    xSemaphoreTake(hook_ctx->draw_sem, portMAX_DELAY);
+    ppa_srm_oper_config_t srm_config = {
+        .in.buffer = hook_data->src_data,
+        .in.pic_w = hook_data->src_x_size,
+        .in.pic_h = hook_data->src_y_size,
+        .in.block_w = hook_data->src_x_end - hook_data->src_x_start,
+        .in.block_h = hook_data->src_y_end - hook_data->src_y_start,
+        .in.block_offset_x = hook_data->src_x_start,
+        .in.block_offset_y = hook_data->src_y_start,
+        .in.srm_cm = PPA_SRM_COLOR_MODE_RGB565,
+        .out.buffer = hook_data->dst_data,
+        .out.buffer_size = hook_data->dst_x_size * hook_data->dst_y_size * hook_data->bits_per_pixel / 8,
+        .out.pic_w = hook_data->dst_x_size,
+        .out.pic_h = hook_data->dst_y_size,
+        .out.block_offset_x = hook_data->dst_x_start,
+        .out.block_offset_y = hook_data->dst_y_start,
+        .out.srm_cm = PPA_SRM_COLOR_MODE_RGB565,
+        .rotation_angle = PPA_SRM_ROTATION_ANGLE_90,
+        .scale_x = 0.5,
+        .scale_y = 0.5,
+        .rgb_swap = 0,
+        .byte_swap = 0,
+        .mode = PPA_TRANS_MODE_NON_BLOCKING,
+        .user_data = hook_ctx,
+    };
+
+    ppa_event_callbacks_t ppa_srm_event_callbacks = {
+        .on_trans_done = test_ppa_srm_trans_done_callback,
+    };
+    TEST_ESP_OK(ppa_client_register_event_callbacks(ppa_srm_handle, &ppa_srm_event_callbacks));
+
+    TEST_ESP_OK(ppa_do_scale_rotate_mirror(ppa_srm_handle, &srm_config));
+
+    return ESP_OK;
+}
+
+IRAM_ATTR static bool test_dpi_panel_color_trans_done_count_callback(esp_lcd_panel_handle_t panel, esp_lcd_dpi_panel_event_data_t *edata, void *user_ctx)
+{
+    BaseType_t task_woken = pdFALSE;
+    test_dpi_panel_color_trans_done_callback_ctx_t *color_trans_done_ctx = (test_dpi_panel_color_trans_done_callback_ctx_t *)user_ctx;
+    color_trans_done_ctx->count++;
+    xSemaphoreGiveFromISR(color_trans_done_ctx->draw_sem, &task_woken);
+    return task_woken == pdTRUE;
+}
+
+TEST_CASE("MIPI DSI use PPA (EK79007)", "[mipi_dsi]")
+{
+    esp_lcd_dsi_bus_handle_t mipi_dsi_bus;
+    esp_lcd_panel_io_handle_t mipi_dbi_io;
+    esp_lcd_panel_handle_t mipi_dpi_panel;
+
+    test_bsp_enable_dsi_phy_power();
+
+    uint8_t *img = malloc(TEST_IMG_SIZE);
+    TEST_ASSERT_NOT_NULL(img);
+
+    esp_lcd_dsi_bus_config_t bus_config = {
+        .bus_id = 0,
+        .num_data_lanes = 2,
+        .lane_bit_rate_mbps = 1000, // 1000 Mbps
+    };
+    TEST_ESP_OK(esp_lcd_new_dsi_bus(&bus_config, &mipi_dsi_bus));
+
+    esp_lcd_dbi_io_config_t dbi_config = {
+        .virtual_channel = 0,
+        .lcd_cmd_bits = 8,
+        .lcd_param_bits = 8,
+    };
+    TEST_ESP_OK(esp_lcd_new_panel_io_dbi(mipi_dsi_bus, &dbi_config, &mipi_dbi_io));
+
+    esp_lcd_dpi_panel_config_t dpi_config = {
+        .dpi_clk_src = MIPI_DSI_DPI_CLK_SRC_DEFAULT,
+        .dpi_clock_freq_mhz = MIPI_DSI_DPI_CLK_MHZ,
+        .virtual_channel = 0,
+        .in_color_format = LCD_COLOR_FMT_RGB565,
+        .video_timing = {
+            .h_size = MIPI_DSI_LCD_H_RES,
+            .v_size = MIPI_DSI_LCD_V_RES,
+            .hsync_back_porch = MIPI_DSI_LCD_HBP,
+            .hsync_pulse_width = MIPI_DSI_LCD_HSYNC,
+            .hsync_front_porch = MIPI_DSI_LCD_HFP,
+            .vsync_back_porch = MIPI_DSI_LCD_VBP,
+            .vsync_pulse_width = MIPI_DSI_LCD_VSYNC,
+            .vsync_front_porch = MIPI_DSI_LCD_VFP,
+        },
+    };
+    ek79007_vendor_config_t vendor_config = {
+        .mipi_config = {
+            .dsi_bus = mipi_dsi_bus,
+            .dpi_config = &dpi_config,
+        },
+    };
+    esp_lcd_panel_dev_config_t lcd_dev_config = {
+        .reset_gpio_num = -1,
+        .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_RGB,
+        .bits_per_pixel = 16,
+        .vendor_config = &vendor_config,
+    };
+    TEST_ESP_OK(esp_lcd_new_panel_ek79007(mipi_dbi_io, &lcd_dev_config, &mipi_dpi_panel));
+    TEST_ESP_OK(esp_lcd_panel_reset(mipi_dpi_panel));
+    TEST_ESP_OK(esp_lcd_panel_init(mipi_dpi_panel));
+
+    SemaphoreHandle_t draw_sem = xSemaphoreCreateBinaryWithCaps(MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
+    assert(draw_sem);
+    xSemaphoreGive(draw_sem);
+    // use PPA to scale and rotate the image in draw bitmap hook
+    ppa_client_handle_t ppa_srm_handle = NULL;
+    ppa_client_config_t ppa_srm_config = {
+        .oper_type = PPA_OPERATION_SRM,
+        .max_pending_trans_num = 1,
+    };
+    TEST_ESP_OK(ppa_register_client(&ppa_srm_config, &ppa_srm_handle));
+
+    esp_lcd_dpi_panel_event_callbacks_t cbs = {
+        .on_color_trans_done = test_dpi_panel_color_trans_done_count_callback,
+    };
+
+    test_dpi_panel_color_trans_done_callback_ctx_t color_trans_done_ctx = {
+        .draw_sem = draw_sem,
+        .count = 0,
+    };
+    TEST_ESP_OK(esp_lcd_dpi_panel_register_event_callbacks(mipi_dpi_panel, &cbs, &color_trans_done_ctx));
+
+    printf("Add PPA draw bitmap hook\r\n");
+    esp_lcd_panel_hooks_t hooks = {
+        .draw_bitmap_hook = test_draw_bitmap_hook_ppa,
+    };
+    test_dpi_panel_draw_bitmap_hook_ctx_t hook_ctx = {
+        .draw_sem = draw_sem,
+        .ppa_srm_handle = ppa_srm_handle,
+        .panel = mipi_dpi_panel,
+    };
+    TEST_ESP_OK(esp_lcd_dpi_panel_register_hooks(mipi_dpi_panel, &hooks, &hook_ctx));
+    for (int i = 0; i < 100; i++) {
+        int x_start = rand() % (MIPI_DSI_LCD_H_RES - 100);
+        int y_start = rand() % (MIPI_DSI_LCD_V_RES - 100);
+        uint8_t color_byte = rand() & 0xFF;
+        memset(img, color_byte, TEST_IMG_SIZE / 2);
+        color_byte = rand() & 0xFF;
+        memset(img + TEST_IMG_SIZE / 2, color_byte, TEST_IMG_SIZE / 2);
+        esp_lcd_panel_draw_bitmap_2d(mipi_dpi_panel, x_start, y_start, x_start + 50, y_start + 50,
+                                     img, 200, 200, 0, 0, 200, 200);
+        vTaskDelay(pdMS_TO_TICKS(10));
+    }
+    TEST_ASSERT_EQUAL_INT(100, color_trans_done_ctx.count);
+
+    hooks.draw_bitmap_hook = NULL;
+    TEST_ESP_OK(esp_lcd_dpi_panel_register_hooks(mipi_dpi_panel, &hooks, NULL));
+    TEST_ESP_OK(ppa_unregister_client(ppa_srm_handle));
+
+    TEST_ESP_OK(esp_lcd_panel_del(mipi_dpi_panel));
+    TEST_ESP_OK(esp_lcd_panel_io_del(mipi_dbi_io));
+    TEST_ESP_OK(esp_lcd_del_dsi_bus(mipi_dsi_bus));
+    vSemaphoreDelete(draw_sem);
+    free(img);
+
+    test_bsp_disable_dsi_phy_power();
+}
+#endif // SOC_HAS(PPA)
+
 TEST_CASE("MIPI DSI use multiple frame buffers (EK79007)", "[mipi_dsi]")
 {
     esp_lcd_dsi_bus_handle_t mipi_dsi_bus;
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

# Note: The pytest tests in pytest_mipi_dsi_lcd.py are hardware-in-the-loop (HIL) tests
# that require actual ESP32-P4 hardware with MIPI DSI LCD connected via physical pins.
# These cannot run in a Docker container without physical devices. Instead, we validate
# the build process for the target (esp32p4) to ensure the code compiles correctly,
# dependencies are properly configured, and the modified test files are syntactically valid.

# Test: Build mipi_dsi_lcd test application for esp32p4
echo "=== Building mipi_dsi_lcd test application for esp32p4 ==="
cd /testbed/components/esp_lcd/test_apps/mipi_dsi_lcd
rm -rf build sdkconfig

# Set target to esp32p4
idf.py set-target esp32p4
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: Failed to set target to esp32p4"
else
    # Build the test application
    idf.py build
    test_rc=$?
    if [ $test_rc -ne 0 ]; then
        rc=1
        echo "ERROR: mipi_dsi_lcd test application build failed for esp32p4"
    else
        echo "SUCCESS: mipi_dsi_lcd test application built successfully for esp32p4"
        
        # Verify that the build artifacts exist
        if [ ! -f "build/mipi_dsi_lcd_panel_test.elf" ]; then
            rc=1
            echo "ERROR: Expected build artifact mipi_dsi_lcd_panel_test.elf not found"
        fi
    fi
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout cb98f7b5ef0e2e2c1b8a92a7f92e98e0283bd18c "components/esp_lcd/test_apps/mipi_dsi_lcd/main/CMakeLists.txt" "components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_iram.c" "components/esp_lcd/test_apps/mipi_dsi_lcd/main/test_mipi_dsi_panel.c"