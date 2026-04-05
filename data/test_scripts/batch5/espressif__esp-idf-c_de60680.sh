#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test file to ensure clean state
git checkout 13fcd60e139b0054b8599fd89525de82cfd9883d "tools/test_apps/system/g1_components/CMakeLists.txt"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/tools/test_apps/system/g1_components/CMakeLists.txt b/tools/test_apps/system/g1_components/CMakeLists.txt
--- a/tools/test_apps/system/g1_components/CMakeLists.txt
+++ b/tools/test_apps/system/g1_components/CMakeLists.txt
@@ -20,6 +20,7 @@ set(esp_hal_components
     esp_hal_touch_sens
     esp_hal_usb
     esp_hal_wdt
+    esp_hal_pmu
 )
 set(COMPONENTS ${g0_components} ${g1_components} ${esp_hal_components} main)
 
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

# Test: Build g1_components test application
# This is a build test that validates ESP-IDF component integration
echo "=== Building g1_components test application ==="
cd /testbed/tools/test_apps/system/g1_components

# Clean any previous build artifacts
rm -rf build sdkconfig sdkconfig.old

# Set target (default to esp32 if not specified)
idf.py set-target esp32
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: Failed to set target to esp32"
else
    # Build the test application
    idf.py build
    test_rc=$?
    if [ $test_rc -ne 0 ]; then
        rc=1
        echo "ERROR: g1_components test application build failed"
    else
        echo "SUCCESS: g1_components test application built successfully"
        
        # Verify that build artifacts exist
        if [ ! -d "build" ]; then
            rc=1
            echo "ERROR: Build directory not found"
        fi
    fi
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout 13fcd60e139b0054b8599fd89525de82cfd9883d "tools/test_apps/system/g1_components/CMakeLists.txt"