#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout 7b33befeaf6e4d918612bf5a8b5f58bd719c967f "components/esp_driver_cam/test_apps/csi/main/test_csi_driver.c" "components/esp_driver_cam/test_apps/csi/main/test_csi_ov5647.c" "components/esp_driver_cam/test_apps/dvp/main/test_dvp_driver.c" "components/esp_driver_cam/test_apps/dvp/main/test_dvp_s3eye.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_cam/test_apps/csi/main/test_csi_driver.c b/components/esp_driver_cam/test_apps/csi/main/test_csi_driver.c
--- a/components/esp_driver_cam/test_apps/csi/main/test_csi_driver.c
+++ b/components/esp_driver_cam/test_apps/csi/main/test_csi_driver.c
@@ -16,7 +16,7 @@ TEST_CASE("TEST CSI driver allocation", "[csi]")
         .h_res = 800,
         .v_res = 640,
         .lane_bit_rate_mbps = 200,
-        .input_data_color_type = CAM_CTLR_COLOR_RAW8,
+        .input_data_color_type = CAM_CTLR_COLOR_RGB565,
         .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .data_lane_num = 2,
         .byte_swap_en = false,
@@ -42,7 +42,7 @@ TEST_CASE("TEST CSI driver no backup buffer usage", "[csi]")
         .h_res = 800,
         .v_res = 640,
         .lane_bit_rate_mbps = 200,
-        .input_data_color_type = CAM_CTLR_COLOR_RAW8,
+        .input_data_color_type = CAM_CTLR_COLOR_RGB565,
         .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .data_lane_num = 2,
         .byte_swap_en = false,
diff --git a/components/esp_driver_cam/test_apps/csi/main/test_csi_ov5647.c b/components/esp_driver_cam/test_apps/csi/main/test_csi_ov5647.c
--- a/components/esp_driver_cam/test_apps/csi/main/test_csi_ov5647.c
+++ b/components/esp_driver_cam/test_apps/csi/main/test_csi_ov5647.c
@@ -1,5 +1,5 @@
 /*
- * SPDX-FileCopyrightText: 2025 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2025-2026 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
@@ -97,7 +97,7 @@ TEST_CASE("TEST esp_cam on ov5647", "[csi][camera][ov5647]")
         .v_res                  = TEST_MIPI_CSI_DISP_VRES,
         .lane_bit_rate_mbps     = TEST_MIPI_CSI_LANE_BITRATE_MBPS,
         .input_data_color_type  = CAM_CTLR_COLOR_RAW8,
-        .output_data_color_type = CAM_CTLR_COLOR_RGB565,
+        .output_data_color_type = CAM_CTLR_COLOR_RAW8,
         .data_lane_num          = 2,
         .byte_swap_en           = false,
         .queue_items            = 1,
diff --git a/components/esp_driver_cam/test_apps/dvp/main/test_dvp_driver.c b/components/esp_driver_cam/test_apps/dvp/main/test_dvp_driver.c
--- a/components/esp_driver_cam/test_apps/dvp/main/test_dvp_driver.c
+++ b/components/esp_driver_cam/test_apps/dvp/main/test_dvp_driver.c
@@ -18,6 +18,7 @@ TEST_CASE("TEST DVP driver allocation", "[DVP]")
         .h_res = 800,
         .v_res = 640,
         .input_data_color_type = CAM_CTLR_COLOR_RGB565,
+        .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .dma_burst_size = 64,
         .byte_swap_en = false,
         .pin_dont_init = true,
@@ -70,6 +71,7 @@ TEST_CASE("TEST DVP driver no backup buffer usage", "[DVP]")
         .h_res = 800,
         .v_res = 640,
         .input_data_color_type = CAM_CTLR_COLOR_RGB565,
+        .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .dma_burst_size = 64,
         .byte_swap_en = false,
         .bk_buffer_dis = true,
@@ -97,6 +99,7 @@ TEST_CASE("TEST DVP driver intern/extern init", "[DVP]")
         .h_res = 800,
         .v_res = 640,
         .input_data_color_type = CAM_CTLR_COLOR_RGB565,
+        .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .dma_burst_size = 64,
         .byte_swap_en = false,
         .external_xtal = true,
@@ -129,6 +132,7 @@ TEST_CASE("TEST DVP driver intern/extern generate xclk", "[DVP]")
         .h_res = 800,
         .v_res = 640,
         .input_data_color_type = CAM_CTLR_COLOR_RGB565,
+        .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .dma_burst_size = 64,
         .byte_swap_en = false,
         .external_xtal = true,
diff --git a/components/esp_driver_cam/test_apps/dvp/main/test_dvp_s3eye.c b/components/esp_driver_cam/test_apps/dvp/main/test_dvp_s3eye.c
--- a/components/esp_driver_cam/test_apps/dvp/main/test_dvp_s3eye.c
+++ b/components/esp_driver_cam/test_apps/dvp/main/test_dvp_s3eye.c
@@ -88,6 +88,7 @@ TEST_CASE("TEST DVP camera on esp32s3_eye", "[dvp][camera][esp32s3_eye]")
         .h_res = TEST_DVP_CAM_H_RES,
         .v_res = TEST_DVP_CAM_V_RES,
         .input_data_color_type = CAM_CTLR_COLOR_RGB565,
+        .output_data_color_type = CAM_CTLR_COLOR_RGB565,
         .dma_burst_size = 64,
         .pin = &pin_cfg,
         .bk_buffer_dis = 1,
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_CCACHE_ENABLE=1
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export CI_PIPELINE_ID=test-pipeline
export IDF_CI_BUILD=1

# Verify Python dependencies are installed
python3 -m pip install --break-system-packages --user -r ${IDF_PATH}/tools/requirements/requirements.core.txt

# Install pytest-embedded suite if not already installed
python3 -m pip install --break-system-packages --user pytest>=7.0 pytest-embedded>=1.10.3 pytest-embedded-idf pytest-embedded-serial pexpect

# Initialize return code
rc=0

# Build and validate CSI test application for ESP32-P4
echo "=========================================="
echo "Building CSI test application for ESP32-P4"
echo "=========================================="
cd /testbed/components/esp_driver_cam/test_apps/csi
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32p4
idf.py build
csi_build_rc=$?

if [ $csi_build_rc -ne 0 ]; then
    echo "ERROR: CSI test application build failed"
    rc=1
fi

# Check for pytest runner in CSI test app
if [ -f pytest_csi.py ]; then
    echo "Running pytest collection for CSI tests..."
    pytest --no-header -rA --tb=short -p no:cacheprovider --collect-only pytest_csi.py
    csi_pytest_rc=$?
    if [ $csi_pytest_rc -ne 0 ]; then
        echo "WARNING: CSI pytest collection failed"
        # Don't fail overall if collection fails, as it might require hardware markers
    fi
fi

# Build and validate DVP test application for ESP32-S3
echo "=========================================="
echo "Building DVP test application for ESP32-S3"
echo "=========================================="
cd /testbed/components/esp_driver_cam/test_apps/dvp
rm -rf build sdkconfig sdkconfig.old
idf.py set-target esp32s3
idf.py build
dvp_build_rc=$?

if [ $dvp_build_rc -ne 0 ]; then
    echo "ERROR: DVP test application build failed"
    rc=1
fi

# Check for pytest runner in DVP test app
if [ -f pytest_dvp.py ]; then
    echo "Running pytest collection for DVP tests..."
    pytest --no-header -rA --tb=short -p no:cacheprovider --collect-only pytest_dvp.py
    dvp_pytest_rc=$?
    if [ $dvp_pytest_rc -ne 0 ]; then
        echo "WARNING: DVP pytest collection failed"
        # Don't fail overall if collection fails, as it might require hardware markers
    fi
fi

# Verify build artifacts exist
echo "=========================================="
echo "Verifying build artifacts"
echo "=========================================="

# Check CSI artifacts
if [ -f /testbed/components/esp_driver_cam/test_apps/csi/build/*.elf ]; then
    echo "✓ CSI build artifacts found"
else
    echo "✗ CSI build artifacts missing"
    rc=1
fi

# Check DVP artifacts
if [ -f /testbed/components/esp_driver_cam/test_apps/dvp/build/*.elf ]; then
    echo "✓ DVP build artifacts found"
else
    echo "✗ DVP build artifacts missing"
    rc=1
fi

# Validate that test source files compile correctly by checking build logs
echo "=========================================="
echo "Validating test source compilation"
echo "=========================================="

# Check if test files were compiled in CSI build
if grep -q "test_csi_driver.c" /testbed/components/esp_driver_cam/test_apps/csi/build/compile_commands.json 2>/dev/null; then
    echo "✓ test_csi_driver.c compiled"
else
    echo "⚠ test_csi_driver.c not found in build"
fi

if grep -q "test_csi_ov5647.c" /testbed/components/esp_driver_cam/test_apps/csi/build/compile_commands.json 2>/dev/null; then
    echo "✓ test_csi_ov5647.c compiled"
else
    echo "⚠ test_csi_ov5647.c not found in build"
fi

# Check if test files were compiled in DVP build
if grep -q "test_dvp_driver.c" /testbed/components/esp_driver_cam/test_apps/dvp/build/compile_commands.json 2>/dev/null; then
    echo "✓ test_dvp_driver.c compiled"
else
    echo "⚠ test_dvp_driver.c not found in build"
fi

if grep -q "test_dvp_s3eye.c" /testbed/components/esp_driver_cam/test_apps/dvp/build/compile_commands.json 2>/dev/null; then
    echo "✓ test_dvp_s3eye.c compiled"
else
    echo "⚠ test_dvp_s3eye.c not found in build"
fi

# Summary
echo "=========================================="
echo "Test Validation Summary"
echo "=========================================="
echo "CSI test app build: $([ $csi_build_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
echo "DVP test app build: $([ $dvp_build_rc -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
echo "Overall result: $([ $rc -eq 0 ] && echo 'SUCCESS - Tests validated through successful compilation' || echo 'FAILED')"
echo ""
echo "Note: These are embedded hardware tests for ESP32-P4 and ESP32-S3 chips."
echo "Actual test execution requires physical hardware, which is not available in Docker."
echo "This evaluation validates that the test code compiles correctly and is ready for hardware testing."

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 7b33befeaf6e4d918612bf5a8b5f58bd719c967f "components/esp_driver_cam/test_apps/csi/main/test_csi_driver.c" "components/esp_driver_cam/test_apps/csi/main/test_csi_ov5647.c" "components/esp_driver_cam/test_apps/dvp/main/test_dvp_driver.c" "components/esp_driver_cam/test_apps/dvp/main/test_dvp_s3eye.c"