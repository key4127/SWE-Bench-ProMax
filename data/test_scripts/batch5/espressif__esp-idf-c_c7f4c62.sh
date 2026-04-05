#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the target test files to ensure clean state
git checkout c6f14a5663c8f39ed7e93a98b560a8c6ccbe13a6 "components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml" "components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml" "components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c"

# Apply test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml b/components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml
--- a/components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml
+++ b/components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml
@@ -3,3 +3,4 @@ components/esp_driver_bitscrambler/test_apps/bitscrambler:
     - if: SOC_BITSCRAMBLER_SUPPORTED != 1
   depends_components:
     - esp_driver_bitscrambler
+    - esp_hal_dma
diff --git a/components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml b/components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml
--- a/components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml
+++ b/components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml
@@ -14,6 +14,7 @@ components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag:
     - vfs
     - esp_driver_gpio
     - esp_driver_usb_serial_jtag
+    - esp_hal_usb
 
 components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag_vfs:
   disable:
@@ -28,3 +29,4 @@ components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag_vfs:
   depends_components:
     - vfs
     - esp_driver_usb_serial_jtag
+    - esp_hal_usb
diff --git a/components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c b/components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c
--- a/components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c
+++ b/components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c
@@ -11,7 +11,7 @@
 #include "soc/soc_caps.h"
 
 #include "hal/gdma_ll.h"
-#include "soc/gdma_channel.h"
+#include "hal/gdma_types.h"
 #if SOC_AHB_GDMA_VERSION == 2
 #include "soc/ahb_dma_struct.h"
 #elif SOC_AHB_GDMA_VERSION == 1
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

# Test 1: Validate YAML syntax for bitscrambler .build-test-rules.yml
echo "=== Validating bitscrambler .build-test-rules.yml YAML syntax ==="
python3 -c "import yaml; yaml.safe_load(open('components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml'))"
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: bitscrambler .build-test-rules.yml YAML validation failed"
fi

# Test 2: Validate YAML syntax for usb_serial_jtag .build-test-rules.yml
echo "=== Validating usb_serial_jtag .build-test-rules.yml YAML syntax ==="
python3 -c "import yaml; yaml.safe_load(open('components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml'))"
test_rc=$?
if [ $test_rc -ne 0 ]; then
    rc=1
    echo "ERROR: usb_serial_jtag .build-test-rules.yml YAML validation failed"
fi

# Test 3: Verify C source file exists
echo "=== Verifying test_setup_utils.c exists ==="
if [ ! -f "components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c" ]; then
    rc=1
    echo "ERROR: test_setup_utils.c not found"
else
    echo "SUCCESS: test_setup_utils.c exists"
fi

# Test 4: Build bitscrambler test app for esp32p4
echo "=== Testing bitscrambler test app for esp32p4 ==="
if [ -d "components/esp_driver_bitscrambler/test_apps/bitscrambler" ]; then
    cd /testbed/components/esp_driver_bitscrambler/test_apps/bitscrambler
    rm -rf build sdkconfig sdkconfig.old
    idf.py set-target esp32p4
    idf.py build
    test_rc=$?
    if [ $test_rc -ne 0 ]; then
        rc=1
        echo "ERROR: bitscrambler test app build failed for esp32p4"
    fi
else
    echo "WARNING: bitscrambler test app directory not found, skipping build"
fi

# Test 5: Build usb_serial_jtag test app for esp32c3
echo "=== Testing usb_serial_jtag test app for esp32c3 ==="
if [ -d "components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag" ]; then
    cd /testbed/components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag
    rm -rf build sdkconfig sdkconfig.old
    idf.py set-target esp32c3
    idf.py build
    test_rc=$?
    if [ $test_rc -ne 0 ]; then
        rc=1
        echo "ERROR: usb_serial_jtag test app build failed for esp32c3"
    fi
else
    echo "WARNING: usb_serial_jtag test app directory not found, skipping build"
fi

# Test 6: Build usb_serial_jtag test app for esp32s3
echo "=== Testing usb_serial_jtag test app for esp32s3 ==="
if [ -d "components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag" ]; then
    cd /testbed/components/esp_driver_usb_serial_jtag/test_apps/usb_serial_jtag
    rm -rf build sdkconfig sdkconfig.old
    idf.py set-target esp32s3
    idf.py build
    test_rc=$?
    if [ $test_rc -ne 0 ]; then
        rc=1
        echo "ERROR: usb_serial_jtag test app build failed for esp32s3"
    fi
else
    echo "WARNING: usb_serial_jtag test app directory not found, skipping build"
fi

# Test 7: Build TEE test app for esp32c6
echo "=== Testing TEE test app for esp32c6 ==="
if [ -d "components/hal/test_apps/tee" ]; then
    cd /testbed/components/hal/test_apps/tee
    rm -rf build sdkconfig sdkconfig.old
    idf.py set-target esp32c6
    idf.py build
    test_rc=$?
    if [ $test_rc -ne 0 ]; then
        rc=1
        echo "ERROR: TEE test app build failed for esp32c6"
    fi
else
    echo "WARNING: TEE test app directory not found, skipping build"
fi

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Cleanup: restore original files
cd /testbed
git checkout c6f14a5663c8f39ed7e93a98b560a8c6ccbe13a6 "components/esp_driver_bitscrambler/test_apps/.build-test-rules.yml" "components/esp_driver_usb_serial_jtag/test_apps/.build-test-rules.yml" "components/hal/test_apps/tee/components/pms_and_cpu_intr/src/common/test_setup_utils.c"