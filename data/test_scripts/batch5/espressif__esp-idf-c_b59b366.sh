#!/bin/bash
set -uxo pipefail

# Navigate to testbed
cd /testbed

# Checkout the specific commit and test files
git checkout f4c40f7e699c9a2830f58524f10f222bb3b93f56 "components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core_i2c.c"

# Apply the test patch
git apply -v - <<'EOF_114329324912'
diff --git a/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core_i2c.c b/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core_i2c.c
--- a/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core_i2c.c
+++ b/components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core_i2c.c
@@ -1,5 +1,5 @@
 /*
- * SPDX-FileCopyrightText: 2023-2024 Espressif Systems (Shanghai) CO LTD
+ * SPDX-FileCopyrightText: 2023-2025 Espressif Systems (Shanghai) CO LTD
  *
  * SPDX-License-Identifier: Apache-2.0
  */
@@ -31,11 +31,11 @@ static void load_and_start_lp_core_firmware(ulp_lp_core_cfg_t* cfg, const uint8_
 
 }
 
-#define I2C_SCL_IO     7                        /*!<gpio number for i2c clock, for C6 only GPIO7 is valid  */
-#define I2C_SDA_IO     6                        /*!<gpio number for i2c data, for C6 only GPIO6 is valid */
-#define I2C_SLAVE_NUM I2C_NUM_0                 /*!<I2C port number for slave dev */
-#define I2C_SLAVE_TX_BUF_LEN  (2*DATA_LENGTH)   /*!<I2C slave tx buffer size */
-#define I2C_SLAVE_RX_BUF_LEN  (2*DATA_LENGTH)   /*!<I2C slave rx buffer size */
+#define I2C_SCL_IO           LP_I2C_SCL_IO   /*!<gpio number for i2c clock */
+#define I2C_SDA_IO           LP_I2C_SDA_IO   /*!<gpio number for i2c data */
+#define I2C_SLAVE_NUM        I2C_NUM_0       /*!<I2C port number for slave dev */
+#define I2C_SLAVE_TX_BUF_LEN (2*DATA_LENGTH) /*!<I2C slave tx buffer size */
+#define I2C_SLAVE_RX_BUF_LEN (2*DATA_LENGTH) /*!<I2C slave rx buffer size */
 
 static uint8_t expected_master_write_data[DATA_LENGTH];
 static uint8_t expected_master_read_data[DATA_LENGTH];
EOF_114329324912

# Source ESP-IDF environment
export IDF_PATH=/testbed
export IDF_TOOLS_PATH=/opt/esp
export IDF_PYTHON_CHECK_CONSTRAINTS=no
export IDF_CCACHE_ENABLE=1
export IDF_CI_BUILD=1
source /testbed/export.sh

# Initialize return code
rc=0

echo "=== Building LP Core I2C Test Application for ESP32-C6 ==="

# Navigate to LP Core basic tests directory
cd /testbed/components/ulp/test_apps/lp_core/lp_core_basic_tests

# Clean any previous build artifacts
rm -rf build sdkconfig sdkconfig.old

# Set target to ESP32-C6 (required for LP Core support)
echo "=== Setting target to ESP32-C6 ==="
idf.py set-target esp32c6
set_target_rc=$?

if [ $set_target_rc -ne 0 ]; then
    echo "ERROR: Failed to set target to esp32c6"
    rc=1
else
    echo "SUCCESS: Target set to esp32c6"
    
    # Build the test application
    echo "=== Building LP Core I2C test application ==="
    idf.py build
    build_rc=$?
    
    if [ $build_rc -ne 0 ]; then
        echo "ERROR: LP Core I2C test application build failed"
        rc=1
    else
        echo "SUCCESS: LP Core I2C test application built successfully"
        
        # Verify that the test file was compiled
        if [ -f build/esp-idf/main/libmain.a ]; then
            echo "SUCCESS: Test binary artifacts generated"
        else
            echo "WARNING: Expected build artifacts not found"
        fi
        
        # Check if the LP Core binary was generated
        if [ -f build/lp_core/main_lp_core.bin ]; then
            echo "SUCCESS: LP Core binary generated"
        else
            echo "INFO: LP Core binary location may vary"
        fi
        
        rc=0
    fi
fi

# Note about hardware requirement
echo ""
echo "=== Build Verification Complete ==="
echo "NOTE: This test requires physical hardware (2x ESP32-C6 boards with I2C connections)"
echo "NOTE: Actual test execution cannot be performed in a containerized environment"
echo "NOTE: Build success indicates that the patched code compiles correctly"

# Required: echo test status
echo "OMNIGRIL_EXIT_CODE=$rc"

# Restore original files
cd /testbed
git checkout f4c40f7e699c9a2830f58524f10f222bb3b93f56 "components/ulp/test_apps/lp_core/lp_core_basic_tests/main/test_lp_core_i2c.c"