#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout b33c9cd7ce051ce572935acf1c04a43bcc94e5c3 "tools/test_apps/system/g1_components/CMakeLists.txt" "tools/test_apps/system/g1_components/main/CMakeLists.txt"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tools/test_apps/system/g1_components/CMakeLists.txt b/tools/test_apps/system/g1_components/CMakeLists.txt
--- a/tools/test_apps/system/g1_components/CMakeLists.txt
+++ b/tools/test_apps/system/g1_components/CMakeLists.txt
@@ -12,23 +12,14 @@ set(esp_hal_components
     esp_hal_ana_conv
     esp_hal_cam
     esp_hal_dma
-    esp_hal_emac
     esp_hal_gpio
-    esp_hal_i2c
     esp_hal_i2s
-    esp_hal_jpeg
-    esp_hal_lcd
-    esp_hal_mcpwm
     esp_hal_mspi
-    esp_hal_parlio
-    esp_hal_pcnt
-    esp_hal_rmt
+    esp_hal_gpspi
     esp_hal_timg
     esp_hal_touch_sens
     esp_hal_usb
     esp_hal_wdt
-    esp_hal_twai
-    esp_hal_gpspi
 )
 set(COMPONENTS ${g0_components} ${g1_components} ${esp_hal_components} main)
 
diff --git a/tools/test_apps/system/g1_components/main/CMakeLists.txt b/tools/test_apps/system/g1_components/main/CMakeLists.txt
--- a/tools/test_apps/system/g1_components/main/CMakeLists.txt
+++ b/tools/test_apps/system/g1_components/main/CMakeLists.txt
@@ -1,2 +1,2 @@
 idf_component_register(SRCS "g1_components.c"
-                    INCLUDE_DIRS ".")
+                       INCLUDE_DIRS ".")
EOF_114329324912

# Source ESP-IDF environment (activates virtualenv and sets up toolchain paths)
source /testbed/export.sh

# Ensure environment variables are set
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export CI_PIPELINE_ID=test-pipeline
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
export IDF_SKIP_CHECK_SUBMODULES=1

# Verify Python dependencies are installed
python3 -m pip install --break-system-packages --upgrade pip setuptools

# Initialize return code
rc=0

# Note: These are embedded firmware tests that compile to ESP32 binaries, NOT native x86 executables.
# They cannot be executed on x86 host - they require ESP32 hardware or QEMU emulator.
# Validation approach: Build verification (successful compilation = valid test code).
# This is the standard CI approach for ESP-IDF projects.

# Test: Build g1_components test app for esp32
echo "=========================================="
echo "Building g1_components test app for esp32..."
echo "=========================================="
cd /testbed/tools/test_apps/system/g1_components
rm -rf build sdkconfig sdkconfig.old

if [ -f "CMakeLists.txt" ]; then
    idf.py set-target esp32
    idf.py build
    rc=$?
    
    if [ $rc -ne 0 ]; then
        echo "ERROR: g1_components test app build failed with exit code $rc"
    else
        echo "SUCCESS: g1_components test app build passed"
        
        # Run the dependency check script with the generated component_deps.dot file
        echo "=========================================="
        echo "Running check_dependencies.py..."
        echo "=========================================="
        if [ -f "check_dependencies.py" ] && [ -f "build/component_deps.dot" ]; then
            python3 check_dependencies.py --component_deps_file build/component_deps.dot --target esp32
            check_rc=$?
            if [ $check_rc -ne 0 ]; then
                echo "ERROR: check_dependencies.py failed with exit code $check_rc"
                rc=$check_rc
            else
                echo "SUCCESS: check_dependencies.py passed"
            fi
        else
            echo "INFO: Skipping check_dependencies.py (script or component_deps.dot not found)"
        fi
    fi
else
    echo "ERROR: No CMakeLists.txt found in g1_components directory"
    rc=1
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout b33c9cd7ce051ce572935acf1c04a43bcc94e5c3 "tools/test_apps/system/g1_components/CMakeLists.txt" "tools/test_apps/system/g1_components/main/CMakeLists.txt"